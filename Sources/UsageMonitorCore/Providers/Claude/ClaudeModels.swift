import Foundation

struct ClaudeUsageResponse: Codable, Sendable {
    let five_hour: UsageWindow
    let seven_day: UsageWindow
    let seven_day_sonnet: UsageWindow?
}

struct UsageWindow: Codable, Sendable {
    let utilization: Double
    let resets_at: String
}

struct ClaudeCredentials: Codable, Sendable {
    let claudeAiOauth: ClaudeOAuthCredentials
    
    enum CodingKeys: String, CodingKey {
        case claudeAiOauth = "claudeAiOauth"
    }
}

struct ClaudeOAuthCredentials: Codable, Sendable {
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
    }
}

struct ClaudeOAuthResult: Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Double?

    var isExpired: Bool {
        guard let expiresAt else {
            return false
        }
        // Claude credential payloads can use either seconds or milliseconds epoch.
        let epochSeconds = expiresAt > 10_000_000_000 ? expiresAt / 1000 : expiresAt
        // Consider token stale slightly before hard expiry to avoid race.
        return Date().timeIntervalSince1970 >= (epochSeconds - 60)
    }
}

struct ClaudeTokenRefreshResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Double?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

enum ClaudeTokenExtractor {
    static func extract(from data: Data) -> ClaudeOAuthResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return extract(from: json)
    }

    private static func extract(from value: Any) -> ClaudeOAuthResult? {
        if let dict = value as? [String: Any] {
            if let direct = extractFromDictionary(dict) {
                return direct
            }

            for child in dict.values {
                if let found = extract(from: child) {
                    return found
                }
            }
            return nil
        }

        if let array = value as? [Any] {
            for item in array {
                if let found = extract(from: item) {
                    return found
                }
            }
        }

        return nil
    }

    private static func extractFromDictionary(_ dict: [String: Any]) -> ClaudeOAuthResult? {
        let accessTokenKeys = ["accessToken", "access_token", "token"]
        let refreshTokenKeys = ["refreshToken", "refresh_token"]
        let expiresAtKeys = ["expiresAt", "expires_at", "expires", "expiresIn", "expires_in"]

        guard let accessToken = firstString(in: dict, keys: accessTokenKeys),
              !accessToken.isEmpty else {
            return nil
        }

        let refreshToken = firstString(in: dict, keys: refreshTokenKeys)
        let expiresAtRaw = firstNumber(in: dict, keys: expiresAtKeys)
        let normalizedExpiresAt = normalizeExpires(expiresAtRaw, in: dict)

        return ClaudeOAuthResult(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: normalizedExpiresAt
        )
    }

    private static func normalizeExpires(_ raw: Double?, in dict: [String: Any]) -> Double? {
        guard let raw else {
            return nil
        }

        // expires_in is a relative duration; convert to epoch-ms for consistency.
        if dict.keys.contains("expiresIn") || dict.keys.contains("expires_in") {
            return Date().timeIntervalSince1970 * 1000 + raw * 1000
        }
        return raw
    }

    private static func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func firstNumber(in dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let v = dict[key] as? Double { return v }
            if let v = dict[key] as? Int { return Double(v) }
            if let v = dict[key] as? NSNumber { return v.doubleValue }
            if let v = dict[key] as? String, let number = Double(v) { return number }
        }
        return nil
    }
}
