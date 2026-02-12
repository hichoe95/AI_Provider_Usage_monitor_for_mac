import Foundation

/// OpenRouter API 응답 모델들을 정의합니다.

/// OpenRouter 크레딧 API 응답의 데이터 부분
struct OpenRouterCreditsData: Codable, Sendable {
    /// 총 크레딧 수
    let total_credits: Double
    
    /// 총 사용량
    let total_usage: Double
}

/// OpenRouter 크레딧 API의 전체 응답
struct OpenRouterCreditsResponse: Codable, Sendable {
    /// 크레딧 정보
    let data: OpenRouterCreditsData
}
