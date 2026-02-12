import Foundation

/// Codex OAuth 인증 파일의 구조를 나타냅니다.
/// ~/.codex/auth.json 파일에서 읽어옵니다.
struct CodexAuthData: Codable, Sendable {
    /// OAuth 액세스 토큰
    let accessToken: String
    
    /// 토큰을 마지막으로 리프레시한 시간
    let lastRefresh: Date
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case lastRefresh = "last_refresh"
    }
}

/// ChatGPT 백엔드 API의 사용량 응답 구조를 나타냅니다.
/// GET https://chatgpt.com/backend-api/wham/usage 응답
struct CodexUsageResponse: Codable, Sendable {
    /// 사용량 윈도우 배열
    /// 각 윈도우는 특정 기간의 사용량 정보를 포함합니다.
    let usageWindows: [CodexUsageWindow]?
    
    enum CodingKeys: String, CodingKey {
        case usageWindows = "usage_windows"
    }
}

/// 사용량 윈도우는 특정 기간의 사용량 정보를 나타냅니다.
struct CodexUsageWindow: Codable, Sendable {
    /// 윈도우 시작 날짜
    let startDate: Date?
    
    /// 윈도우 종료 날짜
    let endDate: Date?
    
    /// 이 기간의 사용량 (0.0-1.0 범위)
    let usage: Double?
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case usage
    }
}
