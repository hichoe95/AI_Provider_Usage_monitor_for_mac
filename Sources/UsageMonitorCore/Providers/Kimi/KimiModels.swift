import Foundation

/// Kimi (Moonshot AI) 잔액 API 응답의 데이터 부분
struct KimiBalanceData: Codable, Sendable {
    /// 사용 가능한 총 잔액 (현금 + 바우처)
    let available_balance: Double

    /// 바우처 잔액
    let voucher_balance: Double

    /// 현금 잔액
    let cash_balance: Double
}

struct KimiErrorPayload: Codable, Sendable {
    let message: String?
    let type: String?
}

/// Kimi (Moonshot AI) 잔액 API의 전체 응답
struct KimiBalanceResponse: Codable, Sendable {
    /// 상태 코드 (0 = 성공)
    let code: Int?

    /// 잔액 정보
    let data: KimiBalanceData?

    /// 상태 코드 (hex) — 일부 엔드포인트에서 누락될 수 있음
    let scode: String?

    /// 성공 여부 — 일부 엔드포인트에서 누락될 수 있음
    let status: Bool?

    let message: String?
    let msg: String?
    let error: KimiErrorPayload?
}
