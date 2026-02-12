import Foundation

/// 프로바이더로부터 가져온 사용량 정보를 나타내는 구조체입니다.
/// Swift 6 strict concurrency를 준수하기 위해 Sendable을 채택합니다.
/// 모든 필드는 optional이므로 프로바이더가 제공하지 않는 정보는 nil로 설정할 수 있습니다.
public struct UsageData: Sendable {
    /// 사용량 정보를 제공한 프로바이더의 이름
    public let provider: String
    
    /// 현재 세션의 사용량 (0-100%)
    /// nil인 경우 프로바이더가 이 정보를 제공하지 않음
    public let sessionUsage: Double?
    
    /// 주간 사용량 (0-100%)
    /// nil인 경우 프로바이더가 이 정보를 제공하지 않음
    public let weeklyUsage: Double?

    public let sonnetUsage: Double?
    
    /// 남은 크레딧 또는 토큰 수
    /// nil인 경우 프로바이더가 이 정보를 제공하지 않음
    public let remainingCredits: Double?
    
    /// 사용량이 리셋되는 날짜
    /// nil인 경우 프로바이더가 이 정보를 제공하지 않음
    public let resetDate: Date?

    public let sessionResetDate: Date?

    public let weeklyResetDate: Date?

    public let sonnetResetDate: Date?

    public let isSonnetOnly: Bool?
    
    /// 사용량 정보를 마지막으로 업데이트한 시간
    public let lastUpdated: Date
    
    /// UsageData를 초기화합니다.
    /// - Parameters:
    ///   - provider: 프로바이더 이름
    ///   - sessionUsage: 세션 사용량 (기본값: nil)
    ///   - weeklyUsage: 주간 사용량 (기본값: nil)
    ///   - remainingCredits: 남은 크레딧 (기본값: nil)
    ///   - resetDate: 리셋 날짜 (기본값: nil)
    ///   - lastUpdated: 마지막 업데이트 시간 (기본값: 현재 시간)
    public init(
        provider: String,
        sessionUsage: Double? = nil,
        weeklyUsage: Double? = nil,
        sonnetUsage: Double? = nil,
        remainingCredits: Double? = nil,
        resetDate: Date? = nil,
        sessionResetDate: Date? = nil,
        weeklyResetDate: Date? = nil,
        sonnetResetDate: Date? = nil,
        isSonnetOnly: Bool? = nil,
        lastUpdated: Date = Date()
    ) {
        self.provider = provider
        self.sessionUsage = sessionUsage
        self.weeklyUsage = weeklyUsage
        self.sonnetUsage = sonnetUsage
        self.remainingCredits = remainingCredits
        self.resetDate = resetDate
        self.sessionResetDate = sessionResetDate
        self.weeklyResetDate = weeklyResetDate
        self.sonnetResetDate = sonnetResetDate
        self.isSonnetOnly = isSonnetOnly
        self.lastUpdated = lastUpdated
    }
}
