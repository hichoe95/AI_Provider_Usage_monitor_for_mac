import Foundation
import Security

/// Keychain에 민감한 정보(API 키, 토큰 등)를 안전하게 저장하고 읽는 헬퍼 클래스입니다.
/// 모든 메서드는 static이므로 인스턴스 생성이 필요하지 않습니다.
public struct KeychainHelper: Sendable {
    /// Keychain에서 값을 읽습니다.
    /// - Parameter key: 읽을 값의 키 (서비스 이름으로 사용)
    /// - Returns: 저장된 값, 없으면 nil
    /// - Throws: Keychain 접근 중 발생한 에러
    public static func read(key: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.readFailed(status)
        }
    }
    
    /// Keychain에 값을 저장합니다.
    /// - Parameters:
    ///   - value: 저장할 값
    ///   - key: 저장할 값의 키 (서비스 이름으로 사용)
    /// - Throws: Keychain 접근 중 발생한 에러
    public static func save(value: String, for key: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // 먼저 기존 항목이 있는지 확인
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecItemNotFound {
            // 항목이 없으면 새로 생성
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            
            if addStatus != errSecSuccess {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Keychain에서 값을 삭제합니다.
    /// - Parameter key: 삭제할 값의 키 (서비스 이름으로 사용)
    /// - Throws: Keychain 접근 중 발생한 에러
    public static func delete(key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess, errSecItemNotFound:
            break
        default:
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - KeychainError
enum KeychainError: Error, Sendable {
    case readFailed(OSStatus)
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed
}

extension KeychainError: CustomStringConvertible {
    var description: String {
        switch self {
        case .readFailed(let status):
            return "Keychain read failed with status: \(status)"
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed with status: \(status)"
        case .encodingFailed:
            return "Failed to encode value as UTF-8"
        }
    }
}
