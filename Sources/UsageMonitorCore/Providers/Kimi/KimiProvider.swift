import Foundation

public struct KimiProvider: Provider {
    public var name: String { "Kimi" }

    private let kimiUsageEndpoint = "https://api.kimi.com/coding/v1/usages"
    private let oauthTokenEndpoint = "https://auth.kimi.com/api/oauth/token"
    private let oauthClientID = "17e5f671-d194-4dfb-9706-5516cb48c098"
    private let oauthCredentialPath = ("~/.kimi/credentials/kimi-code.json" as NSString).expandingTildeInPath

    public init() {}

    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: oauthCredentialPath)
    }

    public func fetchUsage() async throws -> UsageData {
        var credentials = try readOAuthCredentials()

        if credentials.expires_at <= Date().timeIntervalSince1970 + 300 {
            credentials = try await refreshOAuthCredentials(refreshToken: credentials.refresh_token)
            try persistOAuthCredentials(credentials)
        }

        do {
            return try await requestKimiCodeUsage(accessToken: credentials.access_token)
        } catch let error as ProviderError {
            if case .authenticationFailed = error {
                credentials = try await refreshOAuthCredentials(refreshToken: credentials.refresh_token)
                try persistOAuthCredentials(credentials)
                return try await requestKimiCodeUsage(accessToken: credentials.access_token)
            }
            throw error
        }
    }

    private func requestKimiCodeUsage(accessToken: String) async throws -> UsageData {
        guard let url = URL(string: kimiUsageEndpoint) else {
            throw ProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.networkError(NSError(domain: "Kimi", code: -1, userInfo: nil))
        }

        switch httpResponse.statusCode {
        case 200:
            let (sessionUsage, weeklyUsage, resetDate) = try parseKimiCodeUsagePayload(data)
            return UsageData(
                provider: name,
                sessionUsage: sessionUsage,
                weeklyUsage: weeklyUsage,
                remainingCredits: nil,
                resetDate: resetDate,
                lastUpdated: Date()
            )
        case 401:
            throw ProviderError.authenticationFailed
        default:
            throw ProviderError.networkError(NSError(domain: "Kimi", code: httpResponse.statusCode, userInfo: nil))
        }
    }

    private func parseKimiCodeUsagePayload(_ data: Data) throws -> (Double?, Double?, Date?) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.invalidResponse
        }

        var sessionUsage: Double?
        var weeklyUsage: Double?
        var resetDate: Date?

        if let usage = root["usage"] as? [String: Any] {
            weeklyUsage = usedPercent(from: usage)
            if let resetRaw = usage["resetTime"] as? String {
                resetDate = parseISO8601(resetRaw)
            }
        }

        if let limits = root["limits"] as? [[String: Any]] {
            for item in limits {
                let window = item["window"] as? [String: Any] ?? [:]
                let detail = item["detail"] as? [String: Any] ?? item
                guard let used = usedPercent(from: detail) else { continue }

                let duration = toDouble(window["duration"]) ?? toDouble(item["duration"]) ?? toDouble(detail["duration"])
                let timeUnit = (window["timeUnit"] as? String) ?? (item["timeUnit"] as? String) ?? (detail["timeUnit"] as? String) ?? ""
                let isSession = isShortWindow(duration: duration, timeUnit: timeUnit)

                if isSession {
                    if sessionUsage == nil {
                        sessionUsage = used
                    }
                    if resetDate == nil, let resetRaw = detail["resetTime"] as? String {
                        resetDate = parseISO8601(resetRaw)
                    }
                } else if weeklyUsage == nil {
                    weeklyUsage = used
                }
            }
        }

        if sessionUsage == nil && weeklyUsage == nil {
            throw ProviderError.invalidResponse
        }

        return (sessionUsage, weeklyUsage, resetDate)
    }

    private func isShortWindow(duration: Double?, timeUnit: String) -> Bool {
        guard let duration else { return false }
        let unit = timeUnit.uppercased()
        if unit.contains("MINUTE") {
            return duration <= 360
        }
        if unit.contains("HOUR") {
            return duration <= 6
        }
        if unit.contains("SECOND") {
            return duration <= 21_600
        }
        return false
    }

    private func usedPercent(from map: [String: Any]) -> Double? {
        let limit = toDouble(map["limit"])
        let used = toDouble(map["used"])
        let remaining = toDouble(map["remaining"])

        guard let limit, limit > 0 else { return nil }

        if let used {
            return clampPercent((used / limit) * 100)
        }
        if let remaining {
            return clampPercent(((limit - remaining) / limit) * 100)
        }
        return nil
    }

    private func clampPercent(_ value: Double) -> Double {
        max(0, min(100, value))
    }

    private func toDouble(_ any: Any?) -> Double? {
        switch any {
        case let v as Double:
            return v
        case let v as Int:
            return Double(v)
        case let v as NSNumber:
            return v.doubleValue
        case let v as String:
            return Double(v)
        default:
            return nil
        }
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        return fallback.date(from: string)
    }

    private func readOAuthCredentials() throws -> KimiOAuthCredentials {
        let url = URL(fileURLWithPath: oauthCredentialPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProviderError.notConfigured
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let credentials = try decoder.decode(KimiOAuthCredentials.self, from: data)
        if credentials.access_token.isEmpty || credentials.refresh_token.isEmpty {
            throw ProviderError.invalidResponse
        }
        return credentials
    }

    private func persistOAuthCredentials(_ credentials: KimiOAuthCredentials) throws {
        let url = URL(fileURLWithPath: oauthCredentialPath)
        let encoder = JSONEncoder()
        let data = try encoder.encode(credentials)
        try data.write(to: url, options: .atomic)
    }

    private func refreshOAuthCredentials(refreshToken: String) async throws -> KimiOAuthCredentials {
        guard let url = URL(string: oauthTokenEndpoint) else {
            throw ProviderError.invalidResponse
        }

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: oauthClientID),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.networkError(NSError(domain: "Kimi", code: -1, userInfo: nil))
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderError.authenticationFailed
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = root["access_token"] as? String,
              let refreshedToken = root["refresh_token"] as? String,
              let tokenType = root["token_type"] as? String,
              let scope = root["scope"] as? String,
              let expiresIn = toDouble(root["expires_in"]) else {
            throw ProviderError.invalidResponse
        }

        return KimiOAuthCredentials(
            access_token: accessToken,
            refresh_token: refreshedToken,
            expires_at: Date().timeIntervalSince1970 + expiresIn,
            scope: scope,
            token_type: tokenType
        )
    }
}

private struct KimiOAuthCredentials: Codable, Sendable {
    let access_token: String
    let refresh_token: String
    let expires_at: Double
    let scope: String
    let token_type: String
}
