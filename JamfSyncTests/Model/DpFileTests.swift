//
//  Copyright 2026, Jamf
//

@testable import Jamf_Sync
import XCTest

final class DpFileTests: XCTestCase {

    // MARK: - init tests

    func test_init_setsAllProperties() {
        let url = URL(fileURLWithPath: "/tmp/test.pkg")
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "abc123"))

        let file = DpFile(name: "test.pkg", fileUrl: url, size: 1024, checksums: checksums)

        XCTAssertEqual(file.name, "test.pkg")
        XCTAssertEqual(file.fileUrl, url)
        XCTAssertEqual(file.size, 1024)
        XCTAssertEqual(file.checksums.findChecksum(type: .MD5)?.value, "abc123")
    }

    func test_init_withNilOptionals() {
        let file = DpFile(name: "test.pkg", size: nil)

        XCTAssertNil(file.fileUrl)
        XCTAssertNil(file.size)
        XCTAssertTrue(file.checksums.checksums.isEmpty)
    }

    func test_copyInit_copiesAllProperties() {
        let original = DpFile(name: "file.pkg", fileUrl: URL(fileURLWithPath: "/tmp/file.pkg"), size: 512)
        original.checksums.updateChecksum(Checksum(type: .SHA_512, value: "sha512val"))

        let copy = DpFile(dpFile: original)

        XCTAssertEqual(copy.id, original.id)
        XCTAssertEqual(copy.name, original.name)
        XCTAssertEqual(copy.fileUrl, original.fileUrl)
        XCTAssertEqual(copy.size, original.size)
        XCTAssertEqual(copy.checksums.findChecksum(type: .SHA_512)?.value, "sha512val")
    }

    // MARK: - sizeString tests

    func test_sizeString_returnsFormattedSize() {
        let file = DpFile(name: "test.pkg", size: 2048)
        XCTAssertEqual(file.sizeString, "2048")
    }

    func test_sizeString_returnsDoubleDashWhenNil() {
        let file = DpFile(name: "test.pkg", size: nil)
        XCTAssertEqual(file.sizeString, "--")
    }

    // MARK: - equality operator tests

    func test_equality_usesChecksumWhenBothHaveMatchingType() {
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "sameHash"))
        let file1 = DpFile(name: "a.pkg", size: 100, checksums: checksums1)

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .MD5, value: "sameHash"))
        let file2 = DpFile(name: "b.pkg", size: 200, checksums: checksums2)

        XCTAssertTrue(DpFile == (file1, file2), "Files with matching checksums should be equal regardless of size or name")
    }

    func test_equality_checksumMismatchMeansNotEqual() {
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "hash1"))
        let file1 = DpFile(name: "a.pkg", size: 100, checksums: checksums1)

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .MD5, value: "hash2"))
        let file2 = DpFile(name: "a.pkg", size: 100, checksums: checksums2)

        XCTAssertFalse(DpFile == (file1, file2), "Files with differing checksums should not be equal")
    }

    func test_equality_fallsBackToSizeWhenNoMatchingChecksumType() {
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "md5Hash"))
        let file1 = DpFile(name: "a.pkg", size: 500, checksums: checksums1)

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "sha512Hash"))
        let file2 = DpFile(name: "a.pkg", size: 500, checksums: checksums2)

        XCTAssertTrue(DpFile == (file1, file2), "When checksum types don't match, equal sizes should mean equal files")
    }

    func test_equality_sizeNotEqualWhenNoMatchingChecksumType() {
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .MD5, value: "md5Hash"))
        let file1 = DpFile(name: "a.pkg", size: 100, checksums: checksums1)

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "sha512Hash"))
        let file2 = DpFile(name: "a.pkg", size: 200, checksums: checksums2)

        XCTAssertFalse(DpFile == (file1, file2), "When checksum types don't match, differing sizes should mean not equal")
    }

    func test_equality_noChecksumsComparesSize() {
        let file1 = DpFile(name: "a.pkg", size: 1024)
        let file2 = DpFile(name: "b.pkg", size: 1024)

        XCTAssertTrue(DpFile == (file1, file2), "Files with no checksums and equal sizes should be equal")
    }

    func test_equality_noChecksumsNilSizesAreEqual() {
        let file1 = DpFile(name: "a.pkg", size: nil)
        let file2 = DpFile(name: "b.pkg", size: nil)

        XCTAssertTrue(DpFile == (file1, file2), "Files with no checksums and both nil sizes should be equal")
    }

    func test_equality_sha512TakesPrecedenceOverSize() {
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .SHA_512, value: "matchingSha512"))
        let file1 = DpFile(name: "a.pkg", size: 100, checksums: checksums1)

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "matchingSha512"))
        let file2 = DpFile(name: "b.pkg", size: 999, checksums: checksums2)

        XCTAssertTrue(DpFile == (file1, file2), "Matching SHA_512 should make files equal regardless of size")
    }
}
