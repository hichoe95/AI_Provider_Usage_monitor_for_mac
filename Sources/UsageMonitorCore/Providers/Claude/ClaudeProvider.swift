import Foundation
import LocalAuthentication
import Security

public actor ClaudeProvider: Provider {
    /// OAuth 자격증명을 어디서 읽을지 지정합니다.
    /// - `default`: 환경변수 + `~/.claude/.credentials.json` + `~/.claude/auth.json` + Keychain
    ///   (기본 Claude Code 계정 — 단일 사용자 케이스 그대로)
    /// - `file(URL)`: 지정된 파일 한 곳에서만 토큰을 읽고 갱신 시 같은 파일에 다시 씁니다.
    ///   (`~/.claude/auth.<label>.json` 패턴으로 멀티 계정 지원)
    public enum CredentialSource: Sendable {
        case `default`
        case file(URL)
    }

    public nonisolated let name: String
    private let credentialSource: CredentialSource
    private let primaryKeychainAccount = "claudeAiOauth"
    private var cachedOAuth: ClaudeOAuthResult?
    private var didAttemptInteractiveKeychainLookup = false
    private let oauthTokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")
    private let oauthUsageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")
    private let oauthClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let oauthScopes = "user:profile user:inference user:sessions:claude_code"

    public init(name: String = "Claude Code", credentialSource: CredentialSource = .default) {
        self.name = name
        self.credentialSource = credentialSource
    }

    public nonisolated var isAvailable: Bool {
        switch credentialSource {
        case .default:
            if environmentOAuthToken() != nil {
                return true
            }

            let home = FileManager.default.homeDirectoryForCurrentUser
            for filename in [".claude/.credentials.json", ".claude/auth.json"] {
                let path = home.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: path.path) {
                    return true
                }
            }
            return hasKeychainCredential()
        case .file(let url):
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    nonisolated private func hasKeychainCredential() -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: false,
            kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    public func fetchUsage() async throws -> UsageData {
        let oauth = try getCachedOrFreshOAuth()
        return try await fetchUsage(using: oauth, allowRetry: true)
    }

    public func invalidateCache() async {
        resetCachedState()
    }

    private func fetchUsage(using oauth: ClaudeOAuthResult, allowRetry: Bool) async throws -> UsageData {
        if oauth.isExpired {
            guard allowRetry else {
                throw ProviderError.tokenExpired
            }
            let recovered = try await recoverExpiredToken(from: oauth)
            return try await fetchUsage(using: recovered, allowRetry: false)
        }

        do {
            return try await callUsageAPI(token: oauth.accessToken)
        } catch ProviderError.tokenExpired where allowRetry {
            let recovered = try await recoverExpiredToken(from: oauth)
            return try await fetchUsage(using: recovered, allowRetry: false)
        }
    }

    /// Attempt to recover from an expired or server-rejected token.
    ///
    /// Recovery order is critical to avoid a race condition with Claude Code CLI:
    ///   1. Re-read credential files & keychain **non-interactively** — the CLI may
    ///      have already refreshed and written a fresh token in the background.
    ///   2. Attempt our own token refresh only if step 1 found nothing fresh.
    ///      Anthropic's refresh tokens are **single-use**: consuming one immediately
    ///      revokes the previous value. Refreshing before checking files risks
    ///      invalidating a token the CLI is still relying on.
    ///   3. Full interactive keychain lookup as a last resort (may prompt the user).
    private func recoverExpiredToken(from oauth: ClaudeOAuthResult) async throws -> ClaudeOAuthResult {
        // Step 1: Non-interactive re-read (files + keychain, no UI prompt).
        // Claude Code CLI writes refreshed tokens to ~/.claude/.credentials.json.
        if let fresh = readOAuth(interactiveKeychain: false), !fresh.isExpired {
            cachedOAuth = fresh
            return fresh
        }

        // Step 2: All sources still stale — attempt our own token refresh.
        do {
            if let refreshed = try await refreshOAuthIfPossible(from: oauth) {
                cachedOAuth = refreshed
                return refreshed
            }
        } catch {
            // Refresh failed (e.g. refresh token already consumed by CLI).
        }

        // Step 3: Full reset + interactive keychain as last resort.
        resetCachedState()
        if let fresh = readOAuth(), !fresh.isExpired {
            cachedOAuth = fresh
            return fresh
        }

        throw ProviderError.tokenExpired
    }

    /// Clear both the cached OAuth token and the Keychain lookup guard so that
    /// the next `readOAuth()` call will re-read credentials from files AND Keychain.
    private func resetCachedState() {
        cachedOAuth = nil
        didAttemptInteractiveKeychainLookup = false
    }

    private func getCachedOrFreshOAuth() throws -> ClaudeOAuthResult {
        if let cached = cachedOAuth {
            if !cached.isExpired {
                return cached
            }

            // Cached token expired. Quick non-interactive re-read from files
            // and keychain — Claude Code CLI may have refreshed in the background.
            if let fresh = readOAuth(interactiveKeychain: false), !fresh.isExpired {
                cachedOAuth = fresh
                return fresh
            }

            // Files also stale — return expired cache and let fetchUsage() handle
            // the full recovery flow (refresh attempt → interactive keychain).
            return cached
        }

        // No cache at all (first call). Full read including interactive keychain.
        guard let oauth = readOAuth() else {
            throw ProviderError.notConfigured
        }

        cachedOAuth = oauth
        return oauth
    }

    private nonisolated func callUsageAPI(token: String) async throws -> UsageData {
        guard let url = oauthUsageURL else {
            throw ProviderError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        // 멀티 계정 격리: URLCache는 URL 기준으로 응답을 보관하므로
        // 같은 endpoint를 여러 토큰으로 호출하면 다른 계정의 응답을 받을 수 있다.
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("UsageMonitor/1.0", forHTTPHeaderField: "User-Agent")

        let (data, rawResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = rawResponse as? HTTPURLResponse else {
            throw ProviderError.networkError(NSError(domain: "ClaudeProvider", code: -1, userInfo: nil))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw ProviderError.tokenExpired
        default:
            throw ProviderError.networkError(NSError(domain: "ClaudeProvider", code: httpResponse.statusCode, userInfo: nil))
        }

        let response = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        let isSonnetOnly = response.five_hour.utilization >= 80
        let sessionResetDate = response.five_hour.resets_at.flatMap { parseResetDate($0) }
        let weeklyResetDate = response.seven_day.resets_at.flatMap { parseResetDate($0) }
        let sonnetResetDate = response.seven_day_sonnet.flatMap { window in
            window.resets_at.flatMap { parseResetDate($0) }
        }

        return UsageData(
            provider: name,
            sessionUsage: response.five_hour.utilization,
            weeklyUsage: response.seven_day.utilization,
            sonnetUsage: response.seven_day_sonnet?.utilization,
            remainingCredits: nil,
            resetDate: sessionResetDate,
            sessionResetDate: sessionResetDate,
            weeklyResetDate: weeklyResetDate,
            sonnetResetDate: sonnetResetDate,
            isSonnetOnly: isSonnetOnly,
            lastUpdated: Date()
        )
    }

    private nonisolated func parseResetDate(_ rawValue: String) -> Date? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        if let epoch = Double(value) {
            let seconds = epoch > 10_000_000_000 ? epoch / 1000 : epoch
            return Date(timeIntervalSince1970: seconds)
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let fractionalDate = fractionalFormatter.date(from: value) {
            return fractionalDate
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func readOAuth(interactiveKeychain: Bool = true) -> ClaudeOAuthResult? {
        switch credentialSource {
        case .default:
            return readDefaultOAuth(interactiveKeychain: interactiveKeychain)
        case .file(let url):
            guard let data = try? Data(contentsOf: url) else {
                return nil
            }
            return ClaudeTokenExtractor.extract(from: data)
        }
    }

    private func readDefaultOAuth(interactiveKeychain: Bool) -> ClaudeOAuthResult? {
        var candidates: [ClaudeOAuthResult] = []
        if let envToken = environmentOAuthToken() {
            candidates.append(ClaudeOAuthResult(accessToken: envToken, refreshToken: nil, expiresAt: nil))
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        for filename in [".claude/.credentials.json", ".claude/auth.json"] {
            let path = home.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: path),
               let result = ClaudeTokenExtractor.extract(from: data) {
                candidates.append(result)
            }
        }
        let prompt = interactiveKeychain && !didAttemptInteractiveKeychainLookup
        if prompt { didAttemptInteractiveKeychainLookup = true }
        for account in Set([primaryKeychainAccount, NSUserName()]) {
            if let result = extractFromKeychain(account: account, allowPrompt: prompt) {
                candidates.append(result)
            }
        }
        return bestOAuthCandidate(from: candidates)
    }

    private static let envKey = "CLAUDE_CODE_OAUTH_TOKEN"

    nonisolated private func environmentOAuthToken() -> String? {
        if let token = ProcessInfo.processInfo.environment[Self.envKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let shellConfigs = [
            "\(home)/.zshrc",
            "\(home)/.zprofile",
            "\(home)/.bashrc",
            "\(home)/.bash_profile",
        ]

        for configPath in shellConfigs {
            guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
                continue
            }
            if let token = parseExportedValue(Self.envKey, from: content) {
                return token
            }
        }

        return nil
    }

    nonisolated private func parseExportedValue(_ key: String, from content: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#") else { continue }

            let needle = "\(key)="
            guard let range = trimmed.range(of: needle) else { continue }

            var value = String(trimmed[range.upperBound...])
            if let commentRange = findUnquotedComment(in: value) {
                value = String(value[..<commentRange])
            }
            value = value.trimmingCharacters(in: .whitespaces)

            if (value.hasPrefix("\"") && value.hasSuffix("\""))
                || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            let final = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !final.isEmpty {
                return final
            }
        }
        return nil
    }

    nonisolated private func findUnquotedComment(in text: String) -> String.Index? {
        var inSingle = false
        var inDouble = false
        for idx in text.indices {
            switch text[idx] {
            case "'" where !inDouble: inSingle.toggle()
            case "\"" where !inSingle: inDouble.toggle()
            case "#" where !inSingle && !inDouble: return idx
            default: break
            }
        }
        return nil
    }

    nonisolated private func bestOAuthCandidate(from candidates: [ClaudeOAuthResult]) -> ClaudeOAuthResult? {
        guard !candidates.isEmpty else {
            return nil
        }

        func score(_ oauth: ClaudeOAuthResult) -> (Int, Int, Double) {
            let notExpired = oauth.isExpired ? 0 : 1
            let hasRefreshToken = (oauth.refreshToken?.isEmpty == false) ? 1 : 0
            let expiresAt = oauth.expiresAt ?? 0
            return (notExpired, hasRefreshToken, expiresAt)
        }

        return candidates.max { score($0) < score($1) }
    }

    nonisolated private func extractFromKeychain(account: String, allowPrompt: Bool) -> ClaudeOAuthResult? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]

        return extractOAuthFromQuery(query, allowPrompt: allowPrompt)
    }


    nonisolated private func extractOAuthFromQuery(
        _ baseQuery: [String: Any],
        allowPrompt: Bool
    ) -> ClaudeOAuthResult? {
        var query = baseQuery
        if !allowPrompt {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return ClaudeTokenExtractor.extract(from: data)
    }

    private func refreshOAuthIfPossible(from oauth: ClaudeOAuthResult) async throws -> ClaudeOAuthResult? {
        guard let refreshToken = oauth.refreshToken,
              !refreshToken.isEmpty,
              let tokenURL = oauthTokenURL else {
            return nil
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: oauthClientID),
            URLQueryItem(name: "scope", value: oauthScopes),
        ]
        request.httpBody = (components.percentEncodedQuery ?? "").data(using: .utf8)

        let (data, rawResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = rawResponse as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw ProviderError.tokenExpired
            }
            throw ProviderError.networkError(NSError(domain: "ClaudeProvider", code: httpResponse.statusCode, userInfo: nil))
        }

        let response = try JSONDecoder().decode(ClaudeTokenRefreshResponse.self, from: data)
        guard !response.accessToken.isEmpty else {
            throw ProviderError.invalidResponse
        }

        let refreshed = ClaudeOAuthResult(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: response.expiresIn.map { Date().timeIntervalSince1970 * 1000 + Double($0) * 1000 }
        )

        persistRefreshedOAuth(refreshed)
        return refreshed
    }

    nonisolated private func persistRefreshedOAuth(_ oauth: ClaudeOAuthResult) {
        switch credentialSource {
        case .default:
            saveOAuthToKeychain(oauth)
        case .file(let url):
            saveOAuthToFile(oauth, at: url)
        }
    }

    nonisolated private func saveOAuthToKeychain(_ oauth: ClaudeOAuthResult) {
        guard let data = oauthPayloadData(oauth) else {
            return
        }
        upsertOAuthKeychainData(data, account: primaryKeychainAccount)
    }

    nonisolated private func saveOAuthToFile(_ oauth: ClaudeOAuthResult, at url: URL) {
        guard let data = oauthPayloadData(oauth, pretty: true) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    nonisolated private func oauthPayloadData(_ oauth: ClaudeOAuthResult, pretty: Bool = false) -> Data? {
        var payload: [String: Any] = [
            "accessToken": oauth.accessToken
        ]
        if let refreshToken = oauth.refreshToken {
            payload["refreshToken"] = refreshToken
        }
        if let expiresAt = oauth.expiresAt {
            payload["expiresAt"] = expiresAt
        }

        let wrapper: [String: Any] = ["claudeAiOauth": payload]
        let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted] : []
        return try? JSONSerialization.data(withJSONObject: wrapper, options: options)
    }

    nonisolated private func upsertOAuthKeychainData(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
