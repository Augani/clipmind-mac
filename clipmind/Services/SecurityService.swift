//
//  SecurityService.swift
//  clipmind
//
//  Security service for detecting and encrypting sensitive clipboard content
//

import Foundation
import SwiftUI
import Combine
import Security
import CryptoKit

/// Service for handling security and privacy features
class SecurityService: ObservableObject {
    static let shared = SecurityService()

    @Published var isAutoDetectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoDetectionEnabled, forKey: "autoDetectSensitive")
        }
    }

    @Published var encryptSensitiveItems: Bool {
        didSet {
            UserDefaults.standard.set(encryptSensitiveItems, forKey: "encryptSensitive")
        }
    }

    @Published var excludedApps = Set<String>() {
        didSet {
            UserDefaults.standard.set(Array(excludedApps), forKey: "excludedApps")
        }
    }

    @Published var autoDeleteSensitiveHours: Int = 24 {
        didSet {
            UserDefaults.standard.set(autoDeleteSensitiveHours, forKey: "autoDeleteHours")
        }
    }

    @Published var isIncognitoMode = false

    // Sensitive content patterns
    private let sensitivePatterns: [(pattern: String, type: String)] = [
        // API Keys
        ("sk-[a-zA-Z0-9]{48}", "API Key"),
        ("pk_[a-zA-Z0-9]{32,}", "API Key"),
        ("AKIA[0-9A-Z]{16}", "AWS Access Key"),
        ("AIza[0-9A-Za-z\\-_]{35}", "Google API Key"),
        ("ghp_[a-zA-Z0-9]{36}", "GitHub Token"),
        ("ghs_[a-zA-Z0-9]{36}", "GitHub Secret"),
        ("Bearer [a-zA-Z0-9\\-._~+/]+=*", "Bearer Token"),

        // Credit Cards (simplified - actual implementation would use Luhn)
        ("\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\\b", "Credit Card"),

        // SSN
        ("\\b\\d{3}-\\d{2}-\\d{4}\\b", "SSN"),
        ("\\b\\d{9}\\b", "SSN"),

        // Passwords (common patterns)
        ("password\\s*[:=]\\s*[\"']?[^\\s\"']+", "Password"),
        ("pwd\\s*[:=]\\s*[\"']?[^\\s\"']+", "Password"),
        ("passwd\\s*[:=]\\s*[\"']?[^\\s\"']+", "Password"),

        // Private Keys
        ("-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----", "Private Key"),
        ("-----BEGIN PGP PRIVATE KEY BLOCK-----", "PGP Private Key"),

        // Database URLs
        ("(mongodb|postgres|postgresql|mysql|redis)://[^\\s]+", "Database URL"),

        // JWT Tokens
        ("eyJ[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+\\.?[A-Za-z0-9-_.+/=]*", "JWT Token")
    ]

    private let encryptionKey: SymmetricKey

    private init() {
        // Load settings
        isAutoDetectionEnabled = UserDefaults.standard.bool(forKey: "autoDetectSensitive")
        encryptSensitiveItems = UserDefaults.standard.bool(forKey: "encryptSensitive")

        if let savedExcludedApps = UserDefaults.standard.array(forKey: "excludedApps") as? [String] {
            excludedApps = Set(savedExcludedApps)
        }

        if UserDefaults.standard.object(forKey: "autoDeleteHours") != nil {
            autoDeleteSensitiveHours = UserDefaults.standard.integer(forKey: "autoDeleteHours")
        }

        // Generate or retrieve encryption key from keychain
        if let key = SecurityService.retrieveEncryptionKey() {
            encryptionKey = key
        } else {
            encryptionKey = SymmetricKey(size: .bits256)
            SecurityService.storeEncryptionKey(encryptionKey)
        }
    }

    /// Detect if content contains sensitive information
    func detectSensitiveContent(_ text: String) -> (isSensitive: Bool, types: Set<String>) {
        guard isAutoDetectionEnabled else { return (false, []) }

        var detectedTypes = Set<String>()

        for (pattern, type) in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    detectedTypes.insert(type)
                }
            }
        }

        // Check for email patterns (less sensitive but worth noting)
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if regex.numberOfMatches(in: text, options: [], range: range) > 2 {
                detectedTypes.insert("Multiple Emails")
            }
        }

        return (!detectedTypes.isEmpty, detectedTypes)
    }

    /// Check if app is excluded from monitoring
    func isAppExcluded(_ bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return excludedApps.contains(bundleId)
    }

    /// Encrypt data using CryptoKit
    func encrypt(_ data: Data) -> Data? {
        guard encryptSensitiveItems else { return data }

        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            return sealedBox.combined
        } catch {
            print("Encryption failed: \(error)")
            return nil
        }
    }

    /// Decrypt data using CryptoKit
    func decrypt(_ data: Data) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return decryptedData
        } catch {
            print("Decryption failed: \(error)")
            return nil
        }
    }

    /// Encrypt string content
    func encryptString(_ string: String) -> Data? {
        guard let data = string.data(using: .utf8) else { return nil }
        return encrypt(data)
    }

    /// Decrypt string content
    func decryptString(_ data: Data) -> String? {
        guard let decryptedData = decrypt(data) else { return nil }
        return String(data: decryptedData, encoding: .utf8)
    }

    /// Store encryption key in keychain
    private static func storeEncryptionKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "ClipMindEncryptionKey",
            kSecAttrService as String: "ClipMind",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete any existing key
        SecItemDelete(query as CFDictionary)

        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to store encryption key: \(status)")
        }
    }

    /// Retrieve encryption key from keychain
    private static func retrieveEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "ClipMindEncryptionKey",
            kSecAttrService as String: "ClipMind",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }

        return nil
    }

    /// Store sensitive item in keychain (for extra security)
    func storeInKeychain(key: String, value: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "ClipMindSensitive",
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve sensitive item from keychain
    func retrieveFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "ClipMindSensitive",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }

        return nil
    }

    /// Validate credit card using Luhn algorithm
    func isValidCreditCard(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        guard digits.count >= 13 && digits.count <= 19 else { return false }

        var sum = 0
        var alternate = false

        for i in stride(from: digits.count - 1, through: 0, by: -1) {
            var digit = digits[i]
            if alternate {
                digit *= 2
                if digit > 9 {
                    digit = (digit % 10) + 1
                }
            }
            sum += digit
            alternate.toggle()
        }

        return sum % 10 == 0
    }

    /// Add custom regex pattern for detection
    func addCustomPattern(_ pattern: String, type: String) {
        // Store in UserDefaults
        var customPatterns = UserDefaults.standard.dictionary(forKey: "customPatterns") ?? [:]
        customPatterns[pattern] = type
        UserDefaults.standard.set(customPatterns, forKey: "customPatterns")
    }

    /// Remove custom pattern
    func removeCustomPattern(_ pattern: String) {
        var customPatterns = UserDefaults.standard.dictionary(forKey: "customPatterns") ?? [:]
        customPatterns.removeValue(forKey: pattern)
        UserDefaults.standard.set(customPatterns, forKey: "customPatterns")
    }
}

/// Extension to ClipboardItem for security features
extension ClipboardItem {
    /// Check if item contains sensitive content
    var isSensitive: Bool {
        switch content {
        case .text(let text):
            return SecurityService.shared.detectSensitiveContent(text).isSensitive
        default:
            return false
        }
    }

    /// Get sensitive content types detected
    var sensitiveTypes: Set<String> {
        switch content {
        case .text(let text):
            return SecurityService.shared.detectSensitiveContent(text).types
        default:
            return []
        }
    }
}