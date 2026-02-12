import Foundation

public struct CopilotProvider: Provider {
    public let name = "Copilot"

    private let usageEndpointPrefix = "https://api.github.com/users/"
    private let apiUserEndpoint = URL(string: "https://api.github.com/user")
    private let userAgent = "UsageMonitor/1.0"

    public init() {}

    public var isAvailable: Bool {
        if environmentToken() != nil {
            return true
        }

        let fm = FileManager.default
        return authFilePaths.contains { fm.fileExists(atPath: $0) } || fm.fileExists(atPath: ghHostsPath)
    }

    public func fetchUsage() async throws -> UsageData {
        guard let token = await resolveAccessToken(), !token.isEmpty else {
            throw ProviderError.notConfigured
        }

        let username = try await fetchUsername(token: token)
        let payload = try await fetchUsagePayload(username: username, token: token)

        let now = Date()
        let usage = buildUsageData(from: payload, at: now)

        return UsageData(
            provider: name,
            sessionUsage: usage.sessionPercent,
            weeklyUsage: usage.weeklyPercent,
            remainingCredits: usage.remainingRequests,
            resetDate: usage.resetDate,
            lastUpdated: now
        )
    }

    private func fetchUsername(token: String) async throws -> String {
        guard let apiUserEndpoint else {
            throw ProviderError.invalidResponse
        }

        let request = buildRequest(url: apiUserEndpoint, token: token)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.networkError(NSError(domain: "CopilotProvider", code: -1))
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw ProviderError.authenticationFailed
        default:
            throw ProviderError.networkError(NSError(domain: "CopilotProvider", code: http.statusCode))
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let login = object["login"] as? String,
            !login.isEmpty
        else {
            throw ProviderError.invalidResponse
        }

        return login
    }

    private func fetchUsagePayload(username: String, token: String) async throws -> Any {
        guard let url = URL(string: "\(usageEndpointPrefix)\(username)/settings/billing/premium_request/usage") else {
            throw ProviderError.invalidResponse
        }

        let request = buildRequest(url: url, token: token)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.networkError(NSError(domain: "CopilotProvider", code: -1))
        }

        switch http.statusCode {
        case 200:
            guard let payload = try? JSONSerialization.jsonObject(with: data) else {
                throw ProviderError.invalidResponse
            }
            return payload
        case 401, 403:
            throw ProviderError.authenticationFailed
        case 404:
            throw ProviderError.notConfigured
        default:
            throw ProviderError.networkError(NSError(domain: "CopilotProvider", code: http.statusCode))
        }
    }

    private func buildRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func buildUsageData(from payload: Any, at now: Date) -> CopilotUsageProjection {
        let usagePoints = extractUsagePoints(from: payload)
        let monthlyTotalFromSummary = extractMonthlyTotal(from: payload)

        let calendar = Calendar(identifier: .gregorian)
        let todayStart = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

        let monthWindow = calendar.dateInterval(of: .month, for: now)
        let monthStart = monthWindow?.start ?? now
        let monthEnd = monthWindow?.end ?? now

        let monthlyTotal = monthlyTotalFromSummary ?? usagePoints
            .filter { $0.date >= monthStart && $0.date < monthEnd }
            .reduce(0) { $0 + $1.quantity }

        let todayRequests = usagePoints
            .filter { $0.date >= todayStart }
            .reduce(0) { $0 + $1.quantity }

        let weekRequests = usagePoints
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.quantity }

        let monthlyAllowance = resolvedMonthlyAllowance()
        let daysInMonth = max(28, calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
        let dailyAllowance = monthlyAllowance / Double(daysInMonth)
        let weeklyAllowance = dailyAllowance * 7.0

        var sessionPercent: Double?
        var weeklyPercent: Double?

        if todayRequests > 0 || weekRequests > 0 {
            sessionPercent = dailyAllowance > 0 ? (todayRequests / dailyAllowance) * 100.0 : nil
            weeklyPercent = weeklyAllowance > 0 ? (weekRequests / weeklyAllowance) * 100.0 : nil
        } else if monthlyTotal > 0 {
            weeklyPercent = monthlyAllowance > 0 ? (monthlyTotal / monthlyAllowance) * 100.0 : nil
        }

        let resetDate = monthWindow?.end
        let remaining = max(0, monthlyAllowance - monthlyTotal)

        return CopilotUsageProjection(
            sessionPercent: sessionPercent,
            weeklyPercent: weeklyPercent,
            remainingRequests: remaining,
            resetDate: resetDate
        )
    }

    private func extractUsagePoints(from payload: Any) -> [CopilotDailyUsagePoint] {
        var points: [CopilotDailyUsagePoint] = []
        collectUsagePoints(from: payload, into: &points)

        if points.isEmpty {
            return []
        }

        let grouped = Dictionary(grouping: points, by: { Calendar(identifier: .gregorian).startOfDay(for: $0.date) })
        return grouped.map { CopilotDailyUsagePoint(date: $0.key, quantity: $0.value.reduce(0) { $0 + $1.quantity }) }
    }

    private func collectUsagePoints(from value: Any, into points: inout [CopilotDailyUsagePoint]) {
        if let dict = value as? [String: Any] {
            if let date = extractDate(from: dict), let quantity = extractQuantity(from: dict), quantity >= 0 {
                points.append(CopilotDailyUsagePoint(date: date, quantity: quantity))
            }
            for child in dict.values {
                collectUsagePoints(from: child, into: &points)
            }
            return
        }

        if let array = value as? [Any] {
            for child in array {
                collectUsagePoints(from: child, into: &points)
            }
        }
    }

    private func extractDate(from dict: [String: Any]) -> Date? {
        let keys = ["date", "day", "usageDate", "usage_date", "timestamp", "createdAt", "created_at"]

        for key in keys {
            guard let raw = dict[key] else { continue }

            if let date = raw as? Date {
                return date
            }
            if let seconds = raw as? TimeInterval {
                return seconds > 10_000_000_000 ? Date(timeIntervalSince1970: seconds / 1000) : Date(timeIntervalSince1970: seconds)
            }
            if let string = raw as? String, let parsed = parseDate(string) {
                return parsed
            }
        }

        return nil
    }

    private func parseDate(_ string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) {
            return date
        }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: string)
    }

    private func extractQuantity(from dict: [String: Any]) -> Double? {
        let keys = [
            "quantity", "netQuantity", "net_quantity", "grossQuantity",
            "gross_quantity", "premium_requests", "premiumRequests",
            "requests", "count", "value"
        ]

        for key in keys {
            if let number = asDouble(dict[key]) {
                return number
            }
        }

        return nil
    }

    private func extractMonthlyTotal(from payload: Any) -> Double? {
        guard let dict = payload as? [String: Any] else {
            return nil
        }

        let keys = ["totalQuantity", "total_quantity", "monthlyTotal", "monthly_total", "netQuantity"]
        for key in keys {
            if let number = asDouble(dict[key]) {
                return number
            }
        }

        return nil
    }

    private func asDouble(_ value: Any?) -> Double? {
        switch value {
        case let d as Double:
            return d
        case let i as Int:
            return Double(i)
        case let s as String:
            return Double(s)
        case let n as NSNumber:
            return n.doubleValue
        default:
            return nil
        }
    }

    private func resolvedMonthlyAllowance() -> Double {
        let stored = UserDefaults.standard.double(forKey: "copilotMonthlyRequestLimit")
        return stored > 0 ? stored : 300
    }

    private var authFilePaths: [String] {
        [
            ("~/.copilot/config.json" as NSString).expandingTildeInPath,
            ("~/.config/github-copilot/apps.json" as NSString).expandingTildeInPath,
            ("~/.config/github-copilot/hosts.json" as NSString).expandingTildeInPath,
        ]
    }

    private var ghHostsPath: String {
        ("~/.config/gh/hosts.yml" as NSString).expandingTildeInPath
    }

    private func resolveAccessToken() async -> String? {
        if let token = environmentToken() {
            return token
        }

        if let keychainToken = try? await KeychainHelper.read(key: "copilot-access-token") {
            let token = keychainToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                return token
            }
        }

        for path in authFilePaths {
            if let token = extractTokenFromJSONFile(path) {
                return token
            }
        }

        if let token = extractTokenFromGhConfig() {
            return token
        }

        return nil
    }

    private func environmentToken() -> String? {
        let env = ProcessInfo.processInfo.environment
        let keys = ["GH_TOKEN", "GITHUB_TOKEN", "COPILOT_TOKEN"]
        for key in keys {
            if let token = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
                return token
            }
        }
        return nil
    }

    private func extractTokenFromGhConfig() -> String? {
        guard let text = try? String(contentsOfFile: ghHostsPath, encoding: .utf8) else {
            return nil
        }

        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("oauth_token:") else { continue }
            let token = line.replacingOccurrences(of: "oauth_token:", with: "").trimmingCharacters(in: .whitespaces)
            if looksLikeToken(token) {
                return token
            }
        }

        return nil
    }

    private func extractTokenFromJSONFile(_ path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        return findToken(in: json)
    }

    private func findToken(in object: Any) -> String? {
        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                let normalized = key.lowercased()
                if normalized.contains("token"),
                   let token = value as? String,
                   looksLikeToken(token) {
                    return token
                }
                if let nested = findToken(in: value) {
                    return nested
                }
            }
            return nil
        }

        if let array = object as? [Any] {
            for value in array {
                if let token = findToken(in: value) {
                    return token
                }
            }
        }

        return nil
    }

    private func looksLikeToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 20 || trimmed.contains(" ") {
            return false
        }

        if trimmed.hasPrefix("github_pat_") || trimmed.hasPrefix("ghp_") || trimmed.hasPrefix("ghu_") {
            return true
        }

        return trimmed.range(of: "^[A-Za-z0-9_\\-\\.]{20,}$", options: .regularExpression) != nil
    }
}

private struct CopilotDailyUsagePoint: Sendable {
    let date: Date
    let quantity: Double
}

private struct CopilotUsageProjection: Sendable {
    let sessionPercent: Double?
    let weeklyPercent: Double?
    let remainingRequests: Double?
    let resetDate: Date?
}
