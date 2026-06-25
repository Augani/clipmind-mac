//
//  SecurityServiceTests.swift
//  clipmindTests
//
//  Unit tests for SecurityService
//

import XCTest
@testable import clipmind

final class SecurityServiceTests: XCTestCase {
    var securityService: SecurityService!

    override func setUpWithError() throws {
        securityService = SecurityService.shared
    }

    // MARK: - Sensitive Content Detection Tests

    func testDetectPassword() throws {
        // Given
        let passwordTexts = [
            "Password: MySecure123!",
            "pwd: test123",
            "my password is hunter2"
        ]

        // When/Then
        for text in passwordTexts {
            let isSensitive = securityService.isSensitiveContent(text)
            XCTAssertTrue(isSensitive, "Should detect '\(text)' as sensitive")
        }
    }

    func testDetectAPIKey() throws {
        // Given
        let apiKeyTexts = [
            "API_KEY=sk_test_1234567890abcdef",
            "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
            "api-key: AKIA1234567890ABCDEF",
            "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        ]

        // When/Then
        for text in apiKeyTexts {
            let isSensitive = securityService.isSensitiveContent(text)
            XCTAssertTrue(isSensitive, "Should detect '\(text)' as API key")
        }
    }

    func testDetectCreditCard() throws {
        // Given
        let cardNumbers = [
            "4532015112830366",  // Visa
            "5425233430109903",  // Mastercard
            "374245455400126",   // Amex
            "6011111111111117"   // Discover
        ]

        // When/Then
        for card in cardNumbers {
            let isSensitive = securityService.isSensitiveContent(card)
            XCTAssertTrue(isSensitive, "Should detect '\(card)' as credit card")
        }
    }

    func testDetectSSN() throws {
        // Given
        let ssnTexts = [
            "123-45-6789",
            "SSN: 987-65-4321",
            "social security: 111-22-3333"
        ]

        // When/Then
        for text in ssnTexts {
            let isSensitive = securityService.isSensitiveContent(text)
            XCTAssertTrue(isSensitive, "Should detect '\(text)' as SSN")
        }
    }

    func testDetectPrivateKey() throws {
        // Given
        let privateKeyText = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIEpAIBAAKCAQEA1234567890abcdef
        -----END RSA PRIVATE KEY-----
        """

        // When
        let isSensitive = securityService.isSensitiveContent(privateKeyText)

        // Then
        XCTAssertTrue(isSensitive, "Should detect private key")
    }

    func testNonSensitiveContent() throws {
        // Given
        let normalTexts = [
            "Hello, world!",
            "This is a normal email@example.com",
            "Meeting at 3pm tomorrow",
            "https://www.apple.com",
            "The quick brown fox jumps over the lazy dog"
        ]

        // When/Then
        for text in normalTexts {
            let isSensitive = securityService.isSensitiveContent(text)
            XCTAssertFalse(isSensitive, "Should not detect '\(text)' as sensitive")
        }
    }

    // MARK: - Encryption Tests

    func testEncryptDecrypt() throws {
        // Given
        let originalText = "This is a secret message!"
        guard let originalData = originalText.data(using: .utf8) else {
            XCTFail("Failed to create data from text")
            return
        }

        // When
        guard let encryptedData = securityService.encrypt(originalData) else {
            XCTFail("Encryption failed")
            return
        }

        guard let decryptedData = securityService.decrypt(encryptedData) else {
            XCTFail("Decryption failed")
            return
        }

        let decryptedText = String(data: decryptedData, encoding: .utf8)

        // Then
        XCTAssertNotEqual(encryptedData, originalData, "Encrypted data should be different")
        XCTAssertEqual(decryptedText, originalText, "Decrypted text should match original")
    }

    func testEncryptLargeData() throws {
        // Given
        let largeText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000)
        guard let originalData = largeText.data(using: .utf8) else {
            XCTFail("Failed to create data")
            return
        }

        // When
        guard let encryptedData = securityService.encrypt(originalData) else {
            XCTFail("Encryption failed")
            return
        }

        guard let decryptedData = securityService.decrypt(encryptedData) else {
            XCTFail("Decryption failed")
            return
        }

        let decryptedText = String(data: decryptedData, encoding: .utf8)

        // Then
        XCTAssertEqual(decryptedText, largeText, "Should handle large data encryption/decryption")
    }

    func testDecryptInvalidData() throws {
        // Given
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])

        // When
        let result = securityService.decrypt(invalidData)

        // Then
        XCTAssertNil(result, "Should return nil for invalid encrypted data")
    }

    // MARK: - Sensitive Content Type Detection

    func testDetectMultipleSensitiveTypes() throws {
        // Given
        let mixedContent = """
        Username: john.doe@example.com
        Password: MySecret123!
        API Key: sk_live_abcdef1234567890
        Credit Card: 4532015112830366
        """

        // When
        let isSensitive = securityService.isSensitiveContent(mixedContent)
        let contentTypes = securityService.getSensitiveContentTypes(mixedContent)

        // Then
        XCTAssertTrue(isSensitive, "Should detect mixed content as sensitive")
        XCTAssertTrue(contentTypes.contains("password"), "Should detect password")
        XCTAssertTrue(contentTypes.contains("api_key"), "Should detect API key")
        XCTAssertTrue(contentTypes.contains("credit_card"), "Should detect credit card")
    }

    // MARK: - Performance Tests

    func testSensitiveContentDetectionPerformance() throws {
        let testText = """
        This is a long text with some sensitive information.
        Password: test123
        API Key: sk_test_1234567890
        \(String(repeating: "Some normal text. ", count: 100))
        """

        measure {
            for _ in 1...100 {
                _ = securityService.isSensitiveContent(testText)
            }
        }
    }

    func testEncryptionPerformance() throws {
        guard let data = "Test data for encryption performance".data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }

        measure {
            for _ in 1...100 {
                _ = securityService.encrypt(data)
            }
        }
    }
}
