import Foundation

/// Codex Provider는 ChatGPT의 OAuth API를 통해 사용량 정보를 가져옵니다.
/// ~/.codex/auth.json 파일에서 OAuth 토큰을 읽고, 토큰 신선도를 확인한 후
/// ChatGPT 백엔드 API를 호출하여 사용량 데이터를 파싱합니다.
public struct CodexProvider: Provider {
    public let name = "Codex"
    
    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: authFilePath)
    }
    
    private let authFilePath: String
    private let apiEndpoint = "https://chatgpt.com/backend-api/wham/usage"
    private let userAgent = "UsageMonitor/1.0"
    
    /// CodexProvider를 초기화합니다.
    /// - Parameter authFilePath: OAuth 토큰 파일 경로 (기본값: ~/.codex/auth.json)
    public init(authFilePath: String = "~/.codex/auth.json") {
        self.authFilePath = (authFilePath as NSString).expandingTildeInPath
    }
    
    /// 사용량 정보를 비동기로 가져옵니다.
    /// 1. ~/.codex/auth.json에서 OAuth 토큰 읽기
    /// 2. 토큰 신선도 확인 (last_refresh > 8일 = 경고)
    /// 3. GET https://chatgpt.com/backend-api/wham/usage 호출
    /// 4. 응답 파싱 및 UsageData 반환
    public func fetchUsage() async throws -> UsageData {
        let auth = try readAuthFile()
        if let lastRefresh = auth.lastRefresh {
            checkTokenFreshness(lastRefresh: lastRefresh)
        }
        return try await fetchUsageFromAPI(token: auth.accessToken)
    }
    
    // MARK: - Private Methods

    private struct CodexAuthSnapshot: Sendable {
        let accessToken: String
        let lastRefresh: Date?
    }

    private struct CodexUsageSnapshot: Sendable {
        let sessionUsage: Double?
        let weeklyUsage: Double?
        let resetDate: Date?
    }

    private struct UsageCandidate: Sendable {
        let path: String
        let percent: Double
        let resetDate: Date?
    }
    
    /// ~/.codex/auth.json 파일을 읽고 파싱합니다.
    private func readAuthFile() throws -> CodexAuthSnapshot {
        guard FileManager.default.fileExists(atPath: authFilePath) else {
            throw ProviderError.notConfigured
        }
        
        let fileURL = URL(fileURLWithPath: authFilePath)
        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let legacy = try? decoder.decode(CodexAuthData.self, from: data),
           !legacy.accessToken.isEmpty {
            return CodexAuthSnapshot(accessToken: legacy.accessToken, lastRefresh: legacy.lastRefresh)
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            throw ProviderError.invalidResponse
        }

        guard let accessToken = findString(
            in: root,
            for: ["access_token", "accessToken", "token", "id_token", "auth_token"]
        ), !accessToken.isEmpty else {
            throw ProviderError.invalidResponse
        }

        let lastRefresh = findDate(
            in: root,
            for: ["last_refresh", "lastRefresh", "updated_at", "updatedAt", "created_at", "createdAt"]
        )

        return CodexAuthSnapshot(accessToken: accessToken, lastRefresh: lastRefresh)
    }
    
    /// 토큰의 신선도를 확인합니다.
    /// last_refresh가 8일 이상 지난 경우 경고를 출력합니다.
    private func checkTokenFreshness(lastRefresh: Date) {
        let daysSinceRefresh = Calendar.current.dateComponents([.day], from: lastRefresh, to: Date()).day ?? 0
        
        if daysSinceRefresh > 8 {
            print("⚠️  Codex token is stale (last refreshed \(daysSinceRefresh) days ago)")
        }
    }
    
    /// ChatGPT 백엔드 API에서 사용량 정보를 가져옵니다.
    private func fetchUsageFromAPI(token: String) async throws -> UsageData {
        guard let url = URL(string: apiEndpoint) else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.networkError(
                    NSError(
                        domain: "CodexProvider",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Codex API response is not HTTP."]
                    )
                )
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                guard let parsed = parseUsageResponse(data) else {
                    let headerParsed = parseUsageFromHeaders(httpResponse.allHeaderFields)
                    if headerParsed.sessionUsage != nil || headerParsed.weeklyUsage != nil {
                        return UsageData(
                            provider: name,
                            sessionUsage: headerParsed.sessionUsage,
                            weeklyUsage: headerParsed.weeklyUsage,
                            remainingCredits: nil,
                            resetDate: headerParsed.resetDate,
                            lastUpdated: Date()
                        )
                    }

                    let message = "Codex API usage format is unsupported.\(responseSnippet(from: data))"
                    throw ProviderError.networkError(
                        NSError(
                            domain: "CodexProvider",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: message]
                        )
                    )
                }

                return UsageData(
                    provider: name,
                    sessionUsage: parsed.sessionUsage,
                    weeklyUsage: parsed.weeklyUsage,
                    remainingCredits: nil,
                    resetDate: parsed.resetDate,
                    lastUpdated: Date()
                )
            case 401, 403:
                throw ProviderError.authenticationFailed
            default:
                throw ProviderError.networkError(makeHTTPError(status: httpResponse.statusCode, data: data))
            }
        } catch let error as ProviderError {
            throw error
        } catch let error as URLError {
            throw ProviderError.networkError(
                NSError(
                    domain: "CodexProvider",
                    code: error.errorCode,
                    userInfo: [NSLocalizedDescriptionKey: "Codex request failed: \(error.localizedDescription)"]
                )
            )
        } catch {
            let nsError = error as NSError
            throw ProviderError.networkError(
                NSError(
                    domain: "CodexProvider",
                    code: nsError.code,
                    userInfo: [NSLocalizedDescriptionKey: "Codex unexpected error: \(nsError.localizedDescription)"]
                )
            )
        }
    }
    
    private func parseUsageResponse(_ data: Data) -> CodexUsageSnapshot? {
        if let root = try? JSONSerialization.jsonObject(with: data) {
            if let parsed = parseUsageFromFlexibleJSON(root), parsed.sessionUsage != nil || parsed.weeklyUsage != nil {
                return parsed
            }
        }

        // Keep the legacy decoder path as a final fallback.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let legacy = try? decoder.decode(CodexUsageResponse.self, from: data) {
            var weekly: Double?
            var resetDate: Date?
            if let latestWindow = legacy.usageWindows?.last {
                if let usage = latestWindow.usage {
                    weekly = normalizeUsage(usage)
                }
                resetDate = latestWindow.endDate
            }

            if weekly == nil {
                return nil
            }
            return CodexUsageSnapshot(sessionUsage: nil, weeklyUsage: weekly, resetDate: resetDate)
        }

        return nil
    }

    private func parseUsageFromFlexibleJSON(_ root: Any) -> CodexUsageSnapshot? {
        var sessionUsage: Double?
        var weeklyUsage: Double?
        var resetDate: Date?

        if let dict = root as? [String: Any] {
            if let sessionBucket = value(for: ["five_hour", "fiveHour", "rolling_5h", "five_hour_window"], in: dict) {
                sessionUsage = usagePercent(in: sessionBucket)
                resetDate = date(
                    for: ["resets_at", "reset_at", "resetDate", "end_date", "endDate"],
                    in: sessionBucket
                )
            }
            if let weeklyBucket = value(for: ["seven_day", "sevenDay", "rolling_7d", "seven_day_window"], in: dict) {
                weeklyUsage = usagePercent(in: weeklyBucket)
                if resetDate == nil {
                    resetDate = date(
                        for: ["resets_at", "reset_at", "resetDate", "end_date", "endDate"],
                        in: weeklyBucket
                    )
                }
            }

            if sessionUsage == nil {
                sessionUsage = number(
                    for: [
                        "five_hour_usage", "five_hour_utilization", "5h_usage",
                        "usage_5h", "utilization_5h", "session_usage"
                    ],
                    in: dict
                ).map(normalizeUsage)
            }
            if weeklyUsage == nil {
                weeklyUsage = number(
                    for: [
                        "seven_day_usage", "seven_day_utilization", "7d_usage",
                        "usage_7d", "utilization_7d", "weekly_usage"
                    ],
                    in: dict
                ).map(normalizeUsage)
            }

            if let windows = findArray(in: root, for: ["usage_windows", "windows", "usageWindows", "buckets"]) {
                let parsed = parseWindowList(windows)
                if sessionUsage == nil {
                    sessionUsage = parsed.sessionUsage
                }
                if weeklyUsage == nil {
                    weeklyUsage = parsed.weeklyUsage
                }
                if resetDate == nil {
                    resetDate = parsed.resetDate
                }
            }

            if sessionUsage == nil {
                let matched = findWindowData(in: root, tokens: ["five", "5h", "5_hour", "session"])
                sessionUsage = matched.usage
                if resetDate == nil {
                    resetDate = matched.reset
                }
            }
            if weeklyUsage == nil {
                let matched = findWindowData(in: root, tokens: ["seven", "7d", "week", "weekly"])
                weeklyUsage = matched.usage
                if resetDate == nil {
                    resetDate = matched.reset
                }
            }
        } else if let windows = root as? [Any] {
            let parsed = parseWindowList(windows)
            sessionUsage = parsed.sessionUsage
            weeklyUsage = parsed.weeklyUsage
            resetDate = parsed.resetDate
        }

        if sessionUsage == nil && weeklyUsage == nil {
            var candidates: [UsageCandidate] = []
            collectUsageCandidates(in: root, path: "", candidates: &candidates)
            if !candidates.isEmpty {
                let session = pickCandidate(
                    from: candidates,
                    preferredTokens: ["five", "5h", "hour", "session", "short", "current", "rolling_5"]
                )
                let weekly = pickCandidate(
                    from: candidates,
                    preferredTokens: ["seven", "7d", "week", "weekly", "long", "rolling_7"]
                )

                if let session {
                    sessionUsage = session.percent
                    if resetDate == nil {
                        resetDate = session.resetDate
                    }
                }
                if let weekly {
                    weeklyUsage = weekly.percent
                    if resetDate == nil {
                        resetDate = weekly.resetDate
                    }
                }

                if sessionUsage == nil || weeklyUsage == nil {
                    let sorted = candidates.sorted { $0.percent < $1.percent }
                    if sessionUsage == nil, let minCandidate = sorted.first {
                        sessionUsage = minCandidate.percent
                    }
                    if weeklyUsage == nil, let maxCandidate = sorted.last {
                        weeklyUsage = maxCandidate.percent
                        if resetDate == nil {
                            resetDate = maxCandidate.resetDate
                        }
                    }
                }
            }
        }

        if sessionUsage == nil && weeklyUsage == nil {
            return nil
        }

        return CodexUsageSnapshot(sessionUsage: sessionUsage, weeklyUsage: weeklyUsage, resetDate: resetDate)
    }

    private func findWindowData(in value: Any, tokens: [String]) -> (usage: Double?, reset: Date?) {
        if let dict = value as? [String: Any] {
            let labelInFields = firstString(
                in: dict,
                keys: ["window", "period", "name", "bucket", "type", "id", "key"]
            )?.lowercased() ?? ""

            let labelMatched = tokens.contains { token in
                labelInFields.contains(token)
            }
            if labelMatched, let usage = usagePercent(in: dict) {
                let reset = date(for: ["end_date", "endDate", "resets_at", "reset_at", "resetDate"], in: dict)
                return (usage, reset)
            }

            for (key, child) in dict {
                let keyLower = key.lowercased()
                if tokens.contains(where: { keyLower.contains($0) }),
                   let usage = usagePercent(in: child) {
                    let reset = date(for: ["end_date", "endDate", "resets_at", "reset_at", "resetDate"], in: child)
                    return (usage, reset)
                }
            }

            for child in dict.values {
                let nested = findWindowData(in: child, tokens: tokens)
                if nested.usage != nil {
                    return nested
                }
            }
        }

        if let array = value as? [Any] {
            for child in array {
                let nested = findWindowData(in: child, tokens: tokens)
                if nested.usage != nil {
                    return nested
                }
            }
        }

        return (nil, nil)
    }

    private func parseWindowList(_ windows: [Any]) -> CodexUsageSnapshot {
        var sessionUsage: Double?
        var weeklyUsage: Double?
        var resetDate: Date?
        var fallbackWindows: [(usage: Double, endDate: Date?, durationHours: Double?)] = []

        for item in windows {
            guard let window = item as? [String: Any],
                  let usage = usagePercent(in: window) else { continue }

            let label = firstString(
                in: window,
                keys: ["window", "period", "name", "bucket", "type", "id", "key"]
            )?.lowercased() ?? ""

            let durationHours = number(
                for: ["duration_hours", "window_hours", "hours", "period_hours", "rolling_hours"],
                in: window
            )

            let durationDays = number(
                for: ["duration_days", "window_days", "days", "period_days"],
                in: window
            )

            let normalizedDuration = durationHours ?? durationDays.map { $0 * 24.0 }

            let endDate = date(
                for: ["end_date", "endDate", "resets_at", "reset_at", "resetDate", "expires_at"],
                in: window
            )

            let isSessionWindow =
                label.contains("five") ||
                label.contains("5h") ||
                label.contains("5_hour") ||
                (normalizedDuration ?? 999_999) <= 6

            let isWeeklyWindow =
                label.contains("seven") ||
                label.contains("7d") ||
                label.contains("week") ||
                (normalizedDuration ?? 0) >= 24 * 6

            if isSessionWindow {
                sessionUsage = usage
            } else if isWeeklyWindow {
                weeklyUsage = usage
                if resetDate == nil {
                    resetDate = endDate
                }
            } else {
                fallbackWindows.append((usage: usage, endDate: endDate, durationHours: normalizedDuration))
            }
        }

        if (sessionUsage == nil || weeklyUsage == nil), !fallbackWindows.isEmpty {
            let sorted = fallbackWindows.sorted {
                ($0.durationHours ?? 999_999) < ($1.durationHours ?? 999_999)
            }

            if sessionUsage == nil, let first = sorted.first {
                sessionUsage = first.usage
            }
            if weeklyUsage == nil {
                let source = sorted.count > 1 ? sorted.last : sorted.first
                if let source {
                    weeklyUsage = source.usage
                    if resetDate == nil {
                        resetDate = source.endDate
                    }
                }
            }
        }

        return CodexUsageSnapshot(sessionUsage: sessionUsage, weeklyUsage: weeklyUsage, resetDate: resetDate)
    }

    private func normalizeUsage(_ value: Double) -> Double {
        value <= 1 ? value * 100.0 : value
    }

    private func makeHTTPError(status: Int, data: Data) -> NSError {
        let message = "Codex API returned status \(status).\(responseSnippet(from: data))"
        return NSError(
            domain: "CodexProvider",
            code: status,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func responseSnippet(from data: Data) -> String {
        let body = String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return body.isEmpty ? "" : " Response: \(String(body.prefix(220)))"
    }

    private func usagePercent(in object: Any?) -> Double? {
        guard let object else {
            return nil
        }

        if let value = number(
            for: [
                "utilization", "usage", "value", "ratio", "percent", "percentage",
                "used_percent", "percent_used", "usage_ratio", "usagePercent"
            ],
            in: object
        ) {
            return normalizeUsage(value)
        }

        guard let dict = object as? [String: Any] else {
            return nil
        }

        if let used = number(
            for: ["used", "consumed", "current", "usage_count", "used_count", "count"],
            in: dict
        ),
        let limit = number(
            for: ["limit", "max", "total", "allowed", "quota", "cap"],
            in: dict
        ),
        limit > 0 {
            return normalizeUsage(used / limit)
        }

        if let remaining = number(
            for: ["remaining", "remaining_count", "left", "available"],
            in: dict
        ),
        let limit = number(
            for: ["limit", "max", "total", "allowed", "quota", "cap"],
            in: dict
        ),
        limit > 0 {
            return normalizeUsage((limit - remaining) / limit)
        }

        return nil
    }

    private func collectUsageCandidates(in value: Any, path: String, candidates: inout [UsageCandidate]) {
        if let dict = value as? [String: Any] {
            if let percent = usagePercent(in: dict) {
                let reset = date(
                    for: ["end_date", "endDate", "resets_at", "reset_at", "resetDate", "expires_at"],
                    in: dict
                )
                candidates.append(UsageCandidate(path: path, percent: percent, resetDate: reset))
            }

            for (key, child) in dict {
                let childPath = path.isEmpty ? key : "\(path).\(key)"
                collectUsageCandidates(in: child, path: childPath, candidates: &candidates)
            }
            return
        }

        if let array = value as? [Any] {
            for (idx, child) in array.enumerated() {
                collectUsageCandidates(in: child, path: "\(path)[\(idx)]", candidates: &candidates)
            }
        }
    }

    private func pickCandidate(from candidates: [UsageCandidate], preferredTokens: [String]) -> UsageCandidate? {
        let scored = candidates.map { candidate -> (UsageCandidate, Int) in
            let lower = candidate.path.lowercased()
            let score = preferredTokens.reduce(0) { partial, token in
                partial + (lower.contains(token) ? 1 : 0)
            }
            return (candidate, score)
        }

        let best = scored.max { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 < rhs.1
            }
            return lhs.0.percent < rhs.0.percent
        }

        guard let best, best.1 > 0 else {
            return nil
        }
        return best.0
    }

    private func parseUsageFromHeaders(_ headers: [AnyHashable: Any]) -> CodexUsageSnapshot {
        let sessionLimit = headerNumber(
            names: ["x-ratelimit-limit-requests", "x-ratelimit-limit", "x-ratelimit-limit-tokens"],
            headers: headers
        )
        let sessionRemaining = headerNumber(
            names: ["x-ratelimit-remaining-requests", "x-ratelimit-remaining", "x-ratelimit-remaining-tokens"],
            headers: headers
        )

        let weeklyLimit = headerNumber(
            names: ["x-weekly-ratelimit-limit", "x-ratelimit-limit-weekly", "x-usage-week-limit"],
            headers: headers
        )
        let weeklyRemaining = headerNumber(
            names: ["x-weekly-ratelimit-remaining", "x-ratelimit-remaining-weekly", "x-usage-week-remaining"],
            headers: headers
        )

        let sessionPercent: Double?
        if let sessionLimit, let sessionRemaining, sessionLimit > 0 {
            sessionPercent = normalizeUsage((sessionLimit - sessionRemaining) / sessionLimit)
        } else {
            sessionPercent = nil
        }

        let weeklyPercent: Double?
        if let weeklyLimit, let weeklyRemaining, weeklyLimit > 0 {
            weeklyPercent = normalizeUsage((weeklyLimit - weeklyRemaining) / weeklyLimit)
        } else if sessionPercent != nil {
            weeklyPercent = sessionPercent
        } else {
            weeklyPercent = nil
        }

        return CodexUsageSnapshot(
            sessionUsage: sessionPercent,
            weeklyUsage: weeklyPercent,
            resetDate: extractResetDate(from: headers)
        )
    }

    private func headerNumber(names: [String], headers: [AnyHashable: Any]) -> Double? {
        let normalized = headers.reduce(into: [String: String]()) { partial, item in
            partial[String(describing: item.key).lowercased()] = String(describing: item.value)
        }

        for name in names {
            if let raw = normalized[name.lowercased()],
               let number = parseLooseDouble(raw) {
                return number
            }
        }

        return nil
    }

    private func extractResetDate(from headers: [AnyHashable: Any]) -> Date? {
        let normalized = headers.reduce(into: [String: String]()) { partial, item in
            partial[String(describing: item.key).lowercased()] = String(describing: item.value)
        }

        if let raw = normalized["x-ratelimit-reset"], let epoch = parseLooseDouble(raw) {
            return epoch > 10_000_000_000
                ? Date(timeIntervalSince1970: epoch / 1000.0)
                : Date(timeIntervalSince1970: epoch)
        }

        if let raw = normalized["retry-after"], let sec = parseLooseDouble(raw) {
            return Date().addingTimeInterval(sec)
        }

        return nil
    }

    private func findString(in value: Any, for keys: [String]) -> String? {
        if let dict = value as? [String: Any] {
            if let string = firstString(in: dict, keys: keys), !string.isEmpty {
                return string
            }
            for child in dict.values {
                if let found = findString(in: child, for: keys) {
                    return found
                }
            }
            return nil
        }

        if let array = value as? [Any] {
            for child in array {
                if let found = findString(in: child, for: keys) {
                    return found
                }
            }
        }

        return nil
    }

    private func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private func value(for keys: [String], in dict: [String: Any]) -> Any? {
        for key in keys {
            if let value = dict[key] {
                return value
            }
        }
        return nil
    }

    private func findDate(in value: Any, for keys: [String]) -> Date? {
        if let dict = value as? [String: Any] {
            if let parsed = date(for: keys, in: dict) {
                return parsed
            }
            for child in dict.values {
                if let found = findDate(in: child, for: keys) {
                    return found
                }
            }
            return nil
        }

        if let array = value as? [Any] {
            for child in array {
                if let found = findDate(in: child, for: keys) {
                    return found
                }
            }
        }

        return nil
    }

    private func date(for keys: [String], in object: Any?) -> Date? {
        guard let dict = object as? [String: Any] else {
            return nil
        }

        for key in keys {
            guard let raw = dict[key] else { continue }

            if let date = raw as? Date {
                return date
            }
            if let time = raw as? Double {
                return time > 10_000_000_000
                    ? Date(timeIntervalSince1970: time / 1000)
                    : Date(timeIntervalSince1970: time)
            }
            if let time = raw as? Int {
                let t = Double(time)
                return t > 10_000_000_000
                    ? Date(timeIntervalSince1970: t / 1000)
                    : Date(timeIntervalSince1970: t)
            }
            if let string = raw as? String {
                if let date = ISO8601DateFormatter().date(from: string) {
                    return date
                }
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "en_US_POSIX")
                fmt.dateFormat = "yyyy-MM-dd"
                if let date = fmt.date(from: string) {
                    return date
                }
            }
        }

        return nil
    }

    private func number(for keys: [String], in object: Any?) -> Double? {
        guard let dict = object as? [String: Any] else {
            return nil
        }

        for key in keys {
            if let value = dict[key] as? Double { return value }
            if let value = dict[key] as? Int { return Double(value) }
            if let value = dict[key] as? NSNumber { return value.doubleValue }
            if let value = dict[key] as? String, let d = parseLooseDouble(value) { return d }
        }
        return nil
    }

    private func parseLooseDouble(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        let cleaned = trimmed
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")

        if let value = Double(cleaned) {
            return value
        }

        let pattern = #"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let range = Range(match.range, in: cleaned) {
            return Double(String(cleaned[range]))
        }

        return nil
    }

    private func findArray(in value: Any, for keys: [String]) -> [Any]? {
        if let dict = value as? [String: Any] {
            for key in keys {
                if let arr = dict[key] as? [Any] {
                    return arr
                }
            }
            for child in dict.values {
                if let found = findArray(in: child, for: keys) {
                    return found
                }
            }
        }
        return nil
    }
}
