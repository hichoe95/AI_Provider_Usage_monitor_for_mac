import Foundation
import LocalAuthentication
import Security

public actor ClaudeProvider: Provider {
    public nonisolated let name = "Claude Code"
    private let primaryKeychainAccount = "claudeAiOauth"
    private var cachedOAuth: ClaudeOAuthResult?
    private var didAttemptInteractiveKeychainLookup = false
    private let oauthTokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")
    private let oauthUsageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")
    private let oauthClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let oauthScopes = "user:profile user:inference user:sessions:claude_code"

    public init() {}
    
    public nonisolated var isAvailable: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        for filename in [".claude/.credentials.json", ".claude/auth.json"] {
            let path = home.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: path.path) {
                return true
            }
        }
        return hasKeychainCredential()
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
        cachedOAuth = nil
        didAttemptInteractiveKeychainLookup = false
    }

    private func fetchUsage(using oauth: ClaudeOAuthResult, allowRetry: Bool) async throws -> UsageData {
        if oauth.isExpired {
            guard allowRetry else {
                throw ProviderError.tokenExpired
            }
            do {
                if let refreshed = try await refreshOAuthIfPossible(from: oauth) {
                    cachedOAuth = refreshed
                    return try await fetchUsage(using: refreshed, allowRetry: false)
                }
            } catch {
                // Fall back to reloading credentials from keychain/files.
            }
            cachedOAuth = nil
            let freshOAuth = try getFreshOAuth()
            return try await fetchUsage(using: freshOAuth, allowRetry: false)
        }

        do {
            return try await callUsageAPI(token: oauth.accessToken)
        } catch ProviderError.tokenExpired where allowRetry {
            do {
                if let refreshed = try await refreshOAuthIfPossible(from: oauth) {
                    cachedOAuth = refreshed
                    return try await fetchUsage(using: refreshed, allowRetry: false)
                }
            } catch {
                // Fall back to reloading credentials from keychain/files.
            }
            cachedOAuth = nil
            let freshOAuth = try getFreshOAuth()
            return try await fetchUsage(using: freshOAuth, allowRetry: false)
        }
    }

    private func getCachedOrFreshOAuth() throws -> ClaudeOAuthResult {
        if let cachedOAuth {
            return cachedOAuth
        }

        guard let oauth = readOAuth() else {
            throw ProviderError.notConfigured
        }

        cachedOAuth = oauth
        return oauth
    }

    private func getFreshOAuth() throws -> ClaudeOAuthResult {
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
        let iso = ISO8601DateFormatter()
        
        return UsageData(
            provider: name,
            sessionUsage: response.five_hour.utilization,
            weeklyUsage: response.seven_day.utilization,
            sonnetUsage: response.seven_day_sonnet?.utilization,
            remainingCredits: nil,
            resetDate: iso.date(from: response.five_hour.resets_at),
            sessionResetDate: iso.date(from: response.five_hour.resets_at),
            weeklyResetDate: iso.date(from: response.seven_day.resets_at),
            sonnetResetDate: response.seven_day_sonnet.flatMap { iso.date(from: $0.resets_at) },
            isSonnetOnly: isSonnetOnly,
            lastUpdated: Date()
        )
    }

    private func readOAuth() -> ClaudeOAuthResult? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        for filename in [".claude/.credentials.json", ".claude/auth.json"] {
            let path = home.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: path),
               let result = ClaudeTokenExtractor.extract(from: data) {
                return result
            }
        }

        guard !didAttemptInteractiveKeychainLookup else {
            return nil
        }

        didAttemptInteractiveKeychainLookup = true
        return extractFromKeychainAny(allowPrompt: true)
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

    nonisolated private func extractFromKeychainAny(allowPrompt: Bool) -> ClaudeOAuthResult? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
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

        saveOAuthToKeychain(refreshed)
        return refreshed
    }

    nonisolated private func saveOAuthToKeychain(_ oauth: ClaudeOAuthResult) {
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
        guard let data = try? JSONSerialization.data(withJSONObject: wrapper) else {
            return
        }

        upsertOAuthKeychainData(data, account: primaryKeychainAccount)
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
