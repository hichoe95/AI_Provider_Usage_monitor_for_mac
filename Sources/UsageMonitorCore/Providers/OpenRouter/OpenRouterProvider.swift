import Foundation
import Security

public struct OpenRouterProvider: Provider {
    public var name: String { "OpenRouter" }
    
    private let apiEndpoint = "https://openrouter.ai/api/v1/credits"
    private let keychainKey = "openrouter-api-key"
    
    public var isAvailable: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainKey,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: false
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess
    }
    
    public init() {}
    
    /// 현재 사용량 정보를 비동기로 가져옵니다.
    /// - Returns: UsageData 구조체로 반환된 사용량 정보
    /// - Throws: ProviderError 타입의 에러 발생 가능
    public func fetchUsage() async throws -> UsageData {
        // Keychain에서 API 키 읽기
        guard let apiKey = try await KeychainHelper.read(key: keychainKey),
              !apiKey.isEmpty else {
            throw ProviderError.notConfigured
        }
        
        // API 요청 생성
        guard let url = URL(string: apiEndpoint) else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // API 호출
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // HTTP 상태 코드 확인
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.networkError(NSError(domain: "OpenRouter", code: -1, userInfo: nil))
        }
        
        switch httpResponse.statusCode {
        case 200:
            break // 성공
        case 401:
            throw ProviderError.authenticationFailed
        default:
            throw ProviderError.networkError(NSError(domain: "OpenRouter", code: httpResponse.statusCode, userInfo: nil))
        }
        
        // JSON 파싱
        let decoder = JSONDecoder()
        let creditsResponse: OpenRouterCreditsResponse
        do {
            creditsResponse = try decoder.decode(OpenRouterCreditsResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse
        }
        
        // 남은 크레딧 계산
        let remainingCredits = creditsResponse.data.total_credits - creditsResponse.data.total_usage
        
        // UsageData 반환
        return UsageData(
            provider: name,
            remainingCredits: remainingCredits,
            lastUpdated: Date()
        )
    }
}
