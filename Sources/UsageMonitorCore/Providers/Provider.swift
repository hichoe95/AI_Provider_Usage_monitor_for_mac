import Foundation

/// Provider 프로토콜은 다양한 AI 서비스의 사용량 정보를 가져오는 인터페이스를 정의합니다.
/// Swift 6 strict concurrency를 준수하기 위해 Sendable을 채택합니다.
public protocol Provider: Sendable {
    /// 프로바이더의 이름 (예: "Claude", "ChatGPT")
    var name: String { get }
    
    /// 프로바이더가 현재 사용 가능한지 여부
    /// 인증 정보가 설정되어 있고 네트워크 연결이 가능한 경우 true
    var isAvailable: Bool { get }
    
    /// 현재 사용량 정보를 비동기로 가져옵니다.
    /// - Returns: UsageData 구조체로 반환된 사용량 정보
    /// - Throws: ProviderError 타입의 에러 발생 가능
    func fetchUsage() async throws -> UsageData

    /// Provider가 내부적으로 캐시한 인증/사용량 상태를 무효화합니다.
    /// 대부분 provider는 캐시가 없으므로 기본 구현은 no-op 입니다.
    func invalidateCache() async
}

public extension Provider {
    func invalidateCache() async {}
}
