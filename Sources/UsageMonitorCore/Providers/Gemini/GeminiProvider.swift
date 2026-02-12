import Foundation

public struct GeminiProvider: Provider {
    public let name = "Gemini"

    private let modelsEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"
    private let userAgent = "UsageMonitor/1.0"

    public init() {}

    public var isAvailable: Bool {
        if environmentAPIKey() != nil {
            return true
        }

        let fm = FileManager.default
        return oauthFilePaths.contains { fm.fileExists(atPath: $0) }
            || envFilePaths.contains { fm.fileExists(atPath: $0) }
    }

    public func fetchUsage() async throws -> UsageData {
        let auth = try await resolveAuth()
        let (headers, responseDate) = try await probeUsageHeaders(using: auth)

        let limit = headerNumber(
            names: [
                "x-ratelimit-limit-requests",
                "x-ratelimit-limit",
                "x-goog-ratelimit-limit-requests"
            ],
            headers: headers
        )

        let remaining = headerNumber(
            names: [
                "x-ratelimit-remaining-requests",
                "x-ratelimit-remaining",
                "x-goog-ratelimit-remaining-requests"
            ],
            headers: headers
        )

        let sessionPercent: Double?
        let weeklyPercent: Double?

        if let limit, let remaining, limit > 0 {
            let used = max(0, limit - remaining)
            let percent = (used / limit) * 100.0
            sessionPercent = percent
            weeklyPercent = percent
        } else {
            sessionPercent = nil
            weeklyPercent = nil
        }

        let resetDate = extractResetDate(from: headers)

        return UsageData(
            provider: name,
            sessionUsage: sessionPercent,
            weeklyUsage: weeklyPercent,
            remainingCredits: nil,
            resetDate: resetDate,
            lastUpdated: responseDate
        )
    }

    private func resolveAuth() async throws -> GeminiAuth {
        if let oauthToken = readOAuthAccessToken() {
            return .oauth(oauthToken)
        }

        if let apiKey = environmentAPIKey() {
            return .apiKey(apiKey)
        }

        if let keychainValue = try? await KeychainHelper.read(key: "gemini-api-key") {
            let token = keychainValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                return .apiKey(token)
            }
        }

        if let apiKeyFromEnvFile = readAPIKeyFromDotEnv() {
            return .apiKey(apiKeyFromEnvFile)
        }

        throw ProviderError.notConfigured
    }

    private func probeUsageHeaders(using auth: GeminiAuth) async throws -> ([AnyHashable: Any], Date) {
        guard let url = url(for: auth) else {
            throw ProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        if case .oauth(let token) = auth {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.networkError(NSError(domain: "GeminiProvider", code: -1))
        }

        switch http.statusCode {
        case 200...299:
            _ = data
            return (http.allHeaderFields, Date())
        case 401, 403:
            throw ProviderError.authenticationFailed
        default:
            throw ProviderError.networkError(NSError(domain: "GeminiProvider", code: http.statusCode))
        }
    }

    private func url(for auth: GeminiAuth) -> URL? {
        switch auth {
        case .apiKey(let key):
            var components = URLComponents(string: modelsEndpoint)
            components?.queryItems = [URLQueryItem(name: "key", value: key)]
            return components?.url
        case .oauth:
            return URL(string: modelsEndpoint)
        }
    }

    private func environmentAPIKey() -> String? {
        let env = ProcessInfo.processInfo.environment
        for key in ["GEMINI_API_KEY", "GOOGLE_API_KEY"] {
            if let value = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private var oauthFilePaths: [String] {
        [
            ("~/.gemini/oauth_creds.json" as NSString).expandingTildeInPath,
            ("~/.config/gemini/oauth_creds.json" as NSString).expandingTildeInPath,
            ("~/.gemini/credentials.json" as NSString).expandingTildeInPath,
        ]
    }

    private var envFilePaths: [String] {
        [
            ("~/.gemini/.env" as NSString).expandingTildeInPath,
            ("~/.config/gemini/.env" as NSString).expandingTildeInPath,
        ]
    }

    private func readAPIKeyFromDotEnv() -> String? {
        for envFilePath in envFilePaths {
            guard let text = try? String(contentsOfFile: envFilePath, encoding: .utf8) else {
                continue
            }

            for rawLine in text.split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("#") || line.isEmpty {
                    continue
                }

                for key in ["GEMINI_API_KEY", "GOOGLE_API_KEY"] {
                    if line.hasPrefix("\(key)=") {
                        let value = line.replacingOccurrences(of: "\(key)=", with: "")
                            .trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'"))
                        if !value.isEmpty {
                            return value
                        }
                    }
                }
            }
        }
        return nil
    }

    private func readOAuthAccessToken() -> String? {
        for oauthFilePath in oauthFilePaths {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: oauthFilePath)),
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }

            if let token = findAccessToken(in: json) {
                return token
            }
        }
        return nil
    }

    private func findAccessToken(in object: Any) -> String? {
        if let dict = object as? [String: Any] {
            let preferredKeys = ["access_token", "accessToken", "token"]
            for key in preferredKeys {
                if let token = dict[key] as? String, looksLikeToken(token) {
                    return token
                }
            }

            for value in dict.values {
                if let nested = findAccessToken(in: value) {
                    return nested
                }
            }
            return nil
        }

        if let array = object as? [Any] {
            for value in array {
                if let token = findAccessToken(in: value) {
                    return token
                }
            }
        }

        return nil
    }

    private func looksLikeToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 20 && !trimmed.contains(" ")
    }

    private func headerNumber(names: [String], headers: [AnyHashable: Any]) -> Double? {
        let normalizedHeaders = headers.reduce(into: [String: String]()) { partial, item in
            partial[String(describing: item.key).lowercased()] = String(describing: item.value)
        }

        for name in names {
            if let raw = normalizedHeaders[name.lowercased()], let number = Double(raw) {
                return number
            }
        }

        return nil
    }

    private func extractResetDate(from headers: [AnyHashable: Any]) -> Date? {
        let normalizedHeaders = headers.reduce(into: [String: String]()) { partial, item in
            partial[String(describing: item.key).lowercased()] = String(describing: item.value)
        }

        if let epochRaw = normalizedHeaders["x-ratelimit-reset"], let epoch = Double(epochRaw) {
            return epoch > 10_000_000_000
                ? Date(timeIntervalSince1970: epoch / 1000)
                : Date(timeIntervalSince1970: epoch)
        }

        if let retryAfterRaw = normalizedHeaders["retry-after"], let sec = Double(retryAfterRaw) {
            return Date().addingTimeInterval(sec)
        }

        return nil
    }
}

private enum GeminiAuth {
    case apiKey(String)
    case oauth(String)
}
