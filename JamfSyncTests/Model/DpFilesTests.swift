//
//  Copyright 2026, Jamf
//

@testable import Jamf_Sync
import XCTest

final class DpFilesTests: XCTestCase {

    var dpFiles: DpFiles!

    override func setUp() {
        super.setUp()
        dpFiles = DpFiles()
    }

    // MARK: - findDpFile(id:) tests

    func test_findDpFileById_returnsMatchingFile() {
        let file = DpFile(name: "test.pkg", size: 100)
        dpFiles.files.append(file)

        let found = dpFiles.findDpFile(id: file.id)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, file.id)
    }

    func test_findDpFileById_returnsNilWhenNotFound() {
        dpFiles.files.append(DpFile(name: "test.pkg", size: 100))

        let found = dpFiles.findDpFile(id: UUID())

        XCTAssertNil(found)
    }

    func test_findDpFileById_returnsNilWhenEmpty() {
        let found = dpFiles.findDpFile(id: UUID())
        XCTAssertNil(found)
    }

    func test_findDpFileById_returnsCorrectFileAmongMultiple() {
        let file1 = DpFile(name: "a.pkg", size: 100)
        let file2 = DpFile(name: "b.pkg", size: 200)
        let file3 = DpFile(name: "c.pkg", size: 300)
        dpFiles.files = [file1, file2, file3]

        let found = dpFiles.findDpFile(id: file2.id)

        XCTAssertEqual(found?.name, "b.pkg")
    }

    // MARK: - findDpFile(name:) tests

    func test_findDpFileByName_returnsMatchingFile() {
        let file = DpFile(name: "installer.pkg", size: 512)
        dpFiles.files.append(file)

        let found = dpFiles.findDpFile(name: "installer.pkg")

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "installer.pkg")
    }

    func test_findDpFileByName_returnsNilWhenNotFound() {
        dpFiles.files.append(DpFile(name: "installer.pkg", size: 512))

        let found = dpFiles.findDpFile(name: "other.pkg")

        XCTAssertNil(found)
    }

    func test_findDpFileByName_returnsNilWhenEmpty() {
        let found = dpFiles.findDpFile(name: "test.pkg")
        XCTAssertNil(found)
    }

    func test_findDpFileByName_isCaseSensitive() {
        dpFiles.files.append(DpFile(name: "Test.pkg", size: 100))

        let found = dpFiles.findDpFile(name: "test.pkg")

        XCTAssertNil(found, "Name lookup should be case-sensitive")
    }

    func test_findDpFileByName_returnsCorrectFileAmongMultiple() {
        dpFiles.files = [
            DpFile(name: "a.pkg", size: 100),
            DpFile(name: "b.pkg", size: 200),
            DpFile(name: "c.pkg", size: 300)
        ]

        let found = dpFiles.findDpFile(name: "c.pkg")

        XCTAssertEqual(found?.size, 300)
    }

    // MARK: - removeAll tests

    func test_removeAll_clearsAllFiles() {
        dpFiles.files = [
            DpFile(name: "a.pkg", size: 100),
            DpFile(name: "b.pkg", size: 200)
        ]

        dpFiles.removeAll()

        XCTAssertTrue(dpFiles.files.isEmpty)
    }

    func test_removeAll_onEmptyCollectionSucceeds() {
        dpFiles.removeAll()
        XCTAssertTrue(dpFiles.files.isEmpty)
    }
}
