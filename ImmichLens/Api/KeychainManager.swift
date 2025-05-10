//
//  KeychainManager.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import Foundation
import Security

final class KeychainManager {
  static let shared = KeychainManager()

  private init() {}

  enum KeychainError: Error {
    case unknown(OSStatus)
  }

  func save(_ token: String, forKey key: String) throws {
    let data = token.data(using: .utf8)!
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)

    guard status == errSecSuccess else {
      throw KeychainError.unknown(status)
    }
  }

  func get(forKey key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    if status == errSecSuccess, let data = item as? Data {
      return String(data: data, encoding: .utf8)
    }

    return nil
  }

  func delete(forKey key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]

    let status = SecItemDelete(query as CFDictionary)

    guard status == errSecSuccess else {
      print("Error deleting item: \(status)")
      return
    }
  }
}
