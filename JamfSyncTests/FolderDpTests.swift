//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import XCTest

final class FolderDpTests: XCTestCase {
    let mockFileManager = MockFileManager()
    var folderDp: FolderDp!
    let filePath = "/Test/Path"

    override func setUpWithError() throws {
        folderDp = FolderDp(name: "TestFolderDp", filePath: filePath, fileManager: mockFileManager)
    }

    // MARK: - retrieveFileList tests

    func test_retrieveFileList_happyPath() throws {
        // Given
        let path = "/Path/"
        let happyFunPackage = "HappyFunPackage.pkg"
        let notSoGoodToUploadFile = "NotSoGoodToUpload.file"
        let superSadDmg = "SuperSad.dmg"
        mockFileManager.directoryContents = [URL(fileURLWithPath: path + happyFunPackage), URL(fileURLWithPath: path + notSoGoodToUploadFile), URL(fileURLWithPath: path + superSadDmg)]
        mockFileManager.fileAttributes = [path + happyFunPackage : [.size : Int64(12345678)], path + superSadDmg : [.size : Int64(456)]]

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await folderDp.retrieveFileList()

            // Then
            XCTAssertTrue(folderDp.filesLoaded)
            XCTAssertEqual(folderDp.dpFiles.files.count, 2)
            if folderDp.dpFiles.files.count == 2 {
                XCTAssertEqual(folderDp.dpFiles.files[0].name, happyFunPackage)
                XCTAssertEqual(folderDp.dpFiles.files[0].size, 12345678)
                XCTAssertEqual(folderDp.dpFiles.files[1].name, superSadDmg)
                XCTAssertEqual(folderDp.dpFiles.files[1].size, 456)
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_retrieveFileList_noFiles() throws {
        // Given
        mockFileManager.directoryContents = []

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await folderDp.retrieveFileList()

            // Then
            XCTAssertTrue(folderDp.filesLoaded)
            XCTAssertEqual(folderDp.dpFiles.files.count, 0)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_retrieveFileList_failed() throws {
        // Given
        mockFileManager.contentsOfDirectoryError = TestErrors.SomethingWentHaywire

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await folderDp.retrieveFileList()

                // Then
                XCTFail("This should have thrown an exception, but didn't")
            } catch TestErrors.SomethingWentHaywire {
                // It failed perfectly!
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - deleteFile tests

    func test_deleteFile()  throws {
        // Given
        let fileName = "fileName"
        let fileUrl = URL(fileURLWithPath: "/Source/Path/\(fileName)")
        let dpFile = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(123456), checksums: nil)
        let fileToDelete = URL(fileURLWithPath: "\(folderDp.filePath)/\(fileName)")
        let synchronizationProgress = SynchronizationProgress()
        let expectationCompleted = XCTestExpectation()
        Task {
            // Given
            try await folderDp.deleteFile(file: dpFile, progress: synchronizationProgress)

            expectationCompleted.fulfill()
        }

        // Then
        wait(for: [expectationCompleted], timeout: 5)
        XCTAssertEqual(mockFileManager.itemRemoved, fileToDelete)
    }

    // MARK: - selectionName tests

    func test_selectionName() throws {
        // When
        let result = folderDp.selectionName()

        // Then
        XCTAssertEqual(result, "TestFolderDp (local)")
    }

    // MARK: - transferFile tests

    func test_transferFile() throws {
        // Given
        let localPath = "/dst/path"
        let fileName = "fileName.pkg"
        let srcFile = DpFile(name: fileName, fileUrl: URL(fileURLWithPath: "/src/path/fileName.pkg"), size: 123456789)
        let synchronizationProgress = SynchronizationProgress()
        let dstDp = FolderDp(name: "TestDstDp", filePath: localPath, fileManager: mockFileManager)
        synchronizationProgress.printToConsole = true // So it will update before the test is over
        synchronizationProgress.currentTotalSizeTransferred = 1234

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await dstDp.transferFile(srcFile: srcFile, moveFrom: nil, progress: synchronizationProgress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(mockFileManager.itemRemoved, URL(fileURLWithPath: "/dst/path/fileName.pkg"))
        XCTAssertEqual(mockFileManager.srcItemCopied, URL(fileURLWithPath: "/src/path/fileName.pkg"))
        XCTAssertEqual(mockFileManager.dstItemCopied, URL(fileURLWithPath: "/dst/path/fileName.pkg"))
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 123456789)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 123458023)
    }
}
