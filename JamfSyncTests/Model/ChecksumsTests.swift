//
//  Copyright 2026, Jamf
//

@testable import Jamf_Sync
import XCTest

final class ChecksumsTests: XCTestCase {

    // MARK: - updateChecksum tests

    func test_updateChecksum_addsNewChecksum() throws {
        // Given
        let checksums = Checksums()
        let checksum = Checksum(type: .MD5, value: "abc123")

        // When
        checksums.updateChecksum(checksum)

        // Then
        XCTAssertEqual(checksums.checksums.count, 1)
        XCTAssertEqual(checksums.checksums[0].type, .MD5)
        XCTAssertEqual(checksums.checksums[0].value, "abc123")
    }

    func test_updateChecksum_replacesExistingChecksum() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "oldValue"))
        let newChecksum = Checksum(type: .MD5, value: "newValue")

        // When
        checksums.updateChecksum(newChecksum)

        // Then
        XCTAssertEqual(checksums.checksums.count, 1, "Should still have only one checksum")
        XCTAssertEqual(checksums.checksums[0].type, .MD5)
        XCTAssertEqual(checksums.checksums[0].value, "newValue", "Should have updated value")
    }

    func test_updateChecksum_addsMultipleTypes() throws {
        // Given
        let checksums = Checksums()
        let md5 = Checksum(type: .MD5, value: "md5Value")
        let sha256 = Checksum(type: .SHA_256, value: "sha256Value")
        let sha512 = Checksum(type: .SHA_512, value: "sha512Value")

        // When
        checksums.updateChecksum(md5)
        checksums.updateChecksum(sha256)
        checksums.updateChecksum(sha512)

        // Then
        XCTAssertEqual(checksums.checksums.count, 3)
    }

    // MARK: - hasMatchingChecksumType tests

    func test_hasMatchingChecksumType_withMatchingType() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "value1"))
        checksums1.updateChecksum(Checksum(type: .SHA_256, value: "value2"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_256, value: "differentValue"))

        // When
        let result = checksums1.hasMatchingChecksumType(checksums: checksums2)

        // Then
        XCTAssertTrue(result, "Should find matching SHA_256 type")
    }

    func test_hasMatchingChecksumType_withNoMatchingType() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "value1"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "value2"))

        // When
        let result = checksums1.hasMatchingChecksumType(checksums: checksums2)

        // Then
        XCTAssertFalse(result, "Should not find any matching types")
    }

    func test_hasMatchingChecksumType_withEmptyChecksums() throws {
        // Given
        let checksums1 = Checksums()
        let checksums2 = Checksums()

        // When
        let result = checksums1.hasMatchingChecksumType(checksums: checksums2)

        // Then
        XCTAssertFalse(result, "Empty checksums should return false")
    }

    func test_hasMatchingChecksumType_withMultipleMatchingTypes() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "md5Value"))
        checksums1.updateChecksum(Checksum(type: .SHA_512, value: "sha512Value"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .MD5, value: "differentMd5"))
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "differentSha512"))

        // When
        let result = checksums1.hasMatchingChecksumType(checksums: checksums2)

        // Then
        XCTAssertTrue(result, "Should find at least one matching type")
    }

    // MARK: - removeChecksum tests

    func test_removeChecksum_removesExistingChecksum() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "md5Value"))
        checksums.updateChecksum(Checksum(type: .SHA_256, value: "sha256Value"))

        // When
        let result = checksums.removeChecksum(type: .MD5)

        // Then
        XCTAssertTrue(result, "Should return true when checksum was removed")
        XCTAssertEqual(checksums.checksums.count, 1)
        XCTAssertEqual(checksums.checksums[0].type, .SHA_256)
    }

    func test_removeChecksum_returnsFalseForNonExistentChecksum() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "md5Value"))

        // When
        let result = checksums.removeChecksum(type: .SHA_512)

        // Then
        XCTAssertFalse(result, "Should return false when no checksum was removed")
        XCTAssertEqual(checksums.checksums.count, 1)
    }

    func test_removeChecksum_handlesEmptyChecksums() throws {
        // Given
        let checksums = Checksums()

        // When
        let result = checksums.removeChecksum(type: .MD5)

        // Then
        XCTAssertFalse(result, "Should return false for empty checksums")
        XCTAssertEqual(checksums.checksums.count, 0)
    }

    // MARK: - findChecksum tests

    func test_findChecksum_findsExistingChecksum() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "md5Value"))
        checksums.updateChecksum(Checksum(type: .SHA_256, value: "sha256Value"))

        // When
        let result = checksums.findChecksum(type: .SHA_256)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .SHA_256)
        XCTAssertEqual(result?.value, "sha256Value")
    }

    func test_findChecksum_returnsNilForNonExistentChecksum() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "md5Value"))

        // When
        let result = checksums.findChecksum(type: .SHA_512)

        // Then
        XCTAssertNil(result)
    }

    func test_findChecksum_handlesEmptyChecksums() throws {
        // Given
        let checksums = Checksums()

        // When
        let result = checksums.findChecksum(type: .MD5)

        // Then
        XCTAssertNil(result)
    }

    // MARK: - bestChecksum tests

    func test_bestChecksum_prefersSHA512() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "md5Value"))
        checksums.updateChecksum(Checksum(type: .SHA_256, value: "sha256Value"))
        checksums.updateChecksum(Checksum(type: .SHA_512, value: "sha512Value"))

        // When
        let result = checksums.bestChecksum()

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .SHA_512, "Should prefer SHA_512 over other types")
        XCTAssertEqual(result?.value, "sha512Value")
    }

    func test_bestChecksum_fallsBackToSHA256() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "md5Value"))
        checksums.updateChecksum(Checksum(type: .SHA_256, value: "sha256Value"))

        // When
        let result = checksums.bestChecksum()

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .SHA_256, "Should use SHA_256 when SHA_512 not available")
        XCTAssertEqual(result?.value, "sha256Value")
    }

    func test_bestChecksum_fallsBackToMD5() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "md5Value"))

        // When
        let result = checksums.bestChecksum()

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .MD5, "Should use MD5 when no stronger algorithms available")
        XCTAssertEqual(result?.value, "md5Value")
    }

    func test_bestChecksum_returnsNilForEmpty() throws {
        // Given
        let checksums = Checksums()

        // When
        let result = checksums.bestChecksum()

        // Then
        XCTAssertNil(result, "Should return nil when no checksums available")
    }

    // MARK: - equality operator tests

    func test_equality_matchingSHA512() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .SHA_512, value: "sha512Value"))
        checksums1.updateChecksum(Checksum(type: .MD5, value: "md5Value1"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "sha512Value"))
        checksums2.updateChecksum(Checksum(type: .MD5, value: "md5Value2"))

        // When
        let result = (checksums1 == checksums2)

        // Then
        XCTAssertTrue(result, "Should be equal when SHA_512 values match (regardless of MD5)")
    }

    func test_equality_mismatchedSHA512() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .SHA_512, value: "sha512Value1"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "sha512Value2"))

        // When
        let result = (checksums1 == checksums2)

        // Then
        XCTAssertFalse(result, "Should not be equal when SHA_512 values differ")
    }

    func test_equality_matchingMD5WithoutSHA512() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "md5Value"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .MD5, value: "md5Value"))

        // When
        let result = (checksums1 == checksums2)

        // Then
        XCTAssertTrue(result, "Should be equal when MD5 values match and no SHA_512 present")
    }

    func test_equality_mismatchedMD5WithoutSHA512() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "md5Value1"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .MD5, value: "md5Value2"))

        // When
        let result = (checksums1 == checksums2)

        // Then
        XCTAssertFalse(result, "Should not be equal when MD5 values differ")
    }

    func test_equality_noComparableChecksums() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .SHA_256, value: "sha256Value"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_256, value: "sha256Value"))

        // When
        let result = (checksums1 == checksums2)

        // Then
        XCTAssertFalse(result, "Should return false when neither SHA_512 nor MD5 are present for comparison")
    }

    func test_equality_emptyChecksums() throws {
        // Given
        let checksums1 = Checksums()
        let checksums2 = Checksums()

        // When
        let result = (checksums1 == checksums2)

        // Then
        XCTAssertFalse(result, "Empty checksums should not be equal")
    }

    func test_equality_oneEmptyOnePopulated() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "md5Value"))

        let checksums2 = Checksums()

        // When
        let result = (checksums1 == checksums2)

        // Then
        XCTAssertFalse(result, "Populated and empty checksums should not be equal")
    }

    func test_equality_SHA512TakesPrecedenceOverMD5() throws {
        // Given
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .SHA_512, value: "matchingSha512"))
        checksums1.updateChecksum(Checksum(type: .MD5, value: "differentMd5_1"))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "matchingSha512"))
        checksums2.updateChecksum(Checksum(type: .MD5, value: "differentMd5_2"))

        // When
        let result = (checksums1 == checksums2)

        // Then
        XCTAssertTrue(result, "SHA_512 comparison should take precedence, ignoring MD5 mismatch")
    }
}
