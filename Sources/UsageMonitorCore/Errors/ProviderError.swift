import Foundation

/// Provider에서 발생할 수 있는 에러를 정의합니다.
public enum ProviderError: Error, Sendable {
    /// 프로바이더가 설정되지 않았거나 필요한 인증 정보가 없는 경우
    case notConfigured
    
    /// 인증 실패 (잘못된 API 키, 만료된 토큰 등)
    case authenticationFailed

    /// 토큰 만료
    case tokenExpired
    
    /// 네트워크 요청 실패
    /// - Parameter error: 기저 네트워크 에러
    case networkError(Error)
    
    /// 프로바이더로부터 받은 응답이 예상과 다른 경우
    case invalidResponse
}

// MARK: - CustomStringConvertible
extension ProviderError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notConfigured:
            return "Provider is not configured"
        case .authenticationFailed:
            return "Authentication failed"
        case .tokenExpired:
            return "Token expired"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from provider"
        }
    }
}

extension ProviderError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
