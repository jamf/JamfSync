//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import XCTest

final class DistributionPointTests: XCTestCase {
    let mockFileManager = MockFileManager()
    var dp: DistributionPoint!
    var observer: NSObjectProtocol?
    var logMessages: [LogMessage] = []

    override func setUpWithError() throws {
        dp = DistributionPoint(name: "--", id: DataModel.noSelection, fileManager: mockFileManager)
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(LogManager.logMessageNotification), object: nil, queue: .main, using: { [weak self] notification in
            if let logMessage = notification.object as? LogMessage {
                self?.logMessages.append(logMessage)
            }
        })
    }

    override func tearDownWithError() throws {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    // MARK: - initialization tests

    func test_initWithId() throws {
        // Given the dp initialization in setUpWithError

        // Then
        XCTAssertEqual(dp.name, "--")
        XCTAssertEqual(dp.id, DataModel.noSelection)
        XCTAssertEqual(dp.fileManager, mockFileManager)
    }

    func test_initWithoutId() throws {
        // Given
        let testDp = DistributionPoint(name: "Lame Dp")

        // Then
        XCTAssertEqual(testDp.name, "Lame Dp")
        XCTAssertNotEqual(testDp.id, DataModel.noSelection)
        XCTAssertEqual(testDp.fileManager, FileManager.default)
    }

    // MARK: - prepareDp tests

    func test_prepareDp() throws {
        // Given
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await dp.prepareDp()

            expectationCompleted.fulfill()
        }
        // Then (For this type of DP, nothing happens, but need to make sure it returns without error.)
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - cleanupDp tests

    func test_cleanupDp() throws {
        // Given
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await dp.cleanupDp()

            expectationCompleted.fulfill()
        }
        // Then (For this type of DP, nothing happens, but need to make sure it returns without error.)
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - retrieveFileList tests

    func test_retrieveFileList_happyPath() throws {
        // Given
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await dp.retrieveFileList()

                // Then
                XCTFail("It should have thrown an exception")
            } catch DistributionPointError.programError {
                // All is well
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - needsToPromptForPassword tests

    func test_needsToPromptForPassword() throws {
        // When
        let result = dp.needsToPromptForPassword()

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - cancel tests

    func test_cancel() throws {
        // Given
        let destinationDp = MockDistributionPoint(name: "TestDestinationdp", fileManager: mockFileManager)
        dp.inProgressDstDp = destinationDp

        // When
        dp.cancel()

        // Then
        XCTAssertTrue(dp.isCanceled)
        XCTAssertTrue(destinationDp.isCanceled)
    }

    // MARK: - willDownloadFiles tests

    func test_willDownloadFiles() throws {
        // When
        let result = dp.willDownloadFiles()

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - downloadFile tests

    func test_downloadFile() throws {
        // Given
        let fileName = "fileName"
        let fileUrl = URL(fileURLWithPath: "/Source/Path/\(fileName)")
        let dpFile = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(123456), checksums: nil)
        let synchronizationProgress = SynchronizationProgress()
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            let result = try await dp.downloadFile(file: dpFile, progress: synchronizationProgress)

            // Then
            XCTAssertNil(result)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - transferFile tests

    func test_transferFile_happyPath() throws {
        // Given
        let fileName = "fileName"
        let srcFileUrl = URL(fileURLWithPath: "/Source/Path/\(fileName)")
        let srcFile = DpFile(name: fileName, fileUrl: srcFileUrl, size: Int64(123456), checksums: nil)
        let synchronizationProgress = SynchronizationProgress()
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await dp.transferFile(srcFile: srcFile, moveFrom: nil, progress: synchronizationProgress)

                // Then
                XCTFail("It should have thrown an exception")
            } catch DistributionPointError.programError {
                // All is well
            }
            expectationCompleted.fulfill()
        }
    }

    // MARK: - deleteFile tests

    func test_deleteFile()  throws {
        // Given
        let fileName = "fileName"
        let fileUrl = URL(fileURLWithPath: "/Source/Path/\(fileName)")
        let dpFile = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(123456), checksums: nil)
        let synchronizationProgress = SynchronizationProgress()
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await dp.deleteFile(file: dpFile, progress: synchronizationProgress)

                // Then
                XCTFail("It should have thrown an exception")
            } catch DistributionPointError.programError {
                // All is well
            }
            expectationCompleted.fulfill()
        }
    }

    // MARK: - selectionName tests

    func test_selectionName_noSelection() throws {
        // Given

        // When
        let result = dp.selectionName()

        // Then
        XCTAssertEqual(result, "--")
    }

    // MARK: - calculateTotalTransferSize tests

    func test_calculateTotalTransferSize_withFiles() throws {
        // Given
        let fileName = "fileName"
        let fileUrl = URL(fileURLWithPath: "/Source/Path/\(fileName)")
        let dpFile1 = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(123), checksums: nil)
        let dpFile2 = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(456), checksums: nil)
        let dpFile3 = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(123456), checksums: nil)
        let filesToSync = [dpFile1, dpFile2, dpFile3]

        // When
        let result = dp.calculateTotalTransferSize(filesToSync: filesToSync)

        // Then
        XCTAssertEqual(result, 124035)
    }

    func test_calculateTotalTransferSize_noFiles() throws {
        // Given
        let filesToSync: [DpFile] = []

        // When
        let result = dp.calculateTotalTransferSize(filesToSync: filesToSync)

        // Then
        XCTAssertEqual(result, 0)
    }

    // MARK: - copyFiles tests

    func test_copyFiles_withNoFiles() throws {
        // Given
        let selectedItems: [DpFile] = []
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 0)
        XCTAssertNil(synchronizationProgress.currentFileSizeTransferred)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 0)
    }

    func test_copyFiles_withSrcFilesAndNoSelection() throws {
        // Given
        let selectedItems: [DpFile] = []
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 23972245)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 23972245)
    }

    func test_copyFiles_withSrcFilesAndNoSelectionAndDownload() throws {
        // Given
        let selectedItems: [DpFile] = []
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        srcDp.willDownloadFilesValue = true
        addTestSrcFiles(dp: srcDp)
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 47944490)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 47944490)
    }

    func test_copyFiles_withSrcAndDstFilesAndNoSelection() throws {
        // Given
        let selectedItems: [DpFile] = []
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 392000)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 392000)
    }

    func test_copyFiles_withSrcAndDstFilesAndNoSelectionForce() throws {
        // Given
        let selectedItems: [DpFile] = []
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: true, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 23972245)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 23972245)
    }

    func test_copyFiles_withSrcAndDstFilesWithSelection() throws {
        // Given
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let selectedItems: [DpFile] = [ srcDp.dpFiles.files[0], srcDp.dpFiles.files[3], srcDp.dpFiles.files[6]]
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 388888)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 388888)
    }

    func test_copyFiles_withSrcAndDstFilesWithSelectionForce() throws {
        // Given
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let selectedItems: [DpFile] = [ srcDp.dpFiles.files[0], srcDp.dpFiles.files[3], srcDp.dpFiles.files[6]]
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: true, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 512344)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 512344)
    }

    func test_copyFiles_withSrcAndDstFilesWithSelectionOneFailed() throws {
        // Given
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let selectedItems: [DpFile] = [ srcDp.dpFiles.files[0], srcDp.dpFiles.files[3], srcDp.dpFiles.files[6]]
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        dstDp.errors = [ nil, TestErrors.SomethingWentHaywire, nil] // For transferFile
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Not all files were transferred from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 388888)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 0)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 55555)
    }

    func test_copyFiles_withSrcAndDstFilesWithSelectionAllFailed() throws {
        // Given
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let selectedItems: [DpFile] = [ srcDp.dpFiles.files[0], srcDp.dpFiles.files[3], srcDp.dpFiles.files[6]]
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        dstDp.errors = [ TestErrors.SomethingWentHaywire, TestErrors.SomethingWentHaywire, TestErrors.SomethingWentHaywire] // For transferFile
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "No files were transferred from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 388888)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 0)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 0)
    }

    func test_copyFiles_withSrcAndDstFilesAndNoSelectionCancel() throws {
        // Given
        let selectedItems: [DpFile] = []
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        srcDp.cancelSync = true
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: nil, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Canceled synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 392000)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 0)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 0)
    }

    func test_copyFiles_withSrcAndDstFilesAndNoSelectionWithJamfProInstance() throws {
        // Given
        let selectedItems: [DpFile] = []
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let jamfProInstance = MockJamfProInstance()
        jamfProInstance.packages = packagesFromDpFiles(dpFiles: dstDp.dpFiles.files)

        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: jamfProInstance, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 392000)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 392000)
        XCTAssertEqual(jamfProInstance.filesAdded.count, 1)
        XCTAssertEqual(jamfProInstance.packagesUpdated.count, 3)
    }

    func test_copyFiles_withSrcAndDstFilesAndNoSelectionForceWithJamfProInstance() throws {
        // Given
        let selectedItems: [DpFile] = []
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let jamfProInstance = MockJamfProInstance()
        jamfProInstance.packages = packagesFromDpFiles(dpFiles: dstDp.dpFiles.files)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: jamfProInstance, forceSync: true, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 23972245)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 23972245)
        XCTAssertEqual(jamfProInstance.filesAdded.count, 1)
        XCTAssertEqual(jamfProInstance.packagesUpdated.count, 6)
    }

    func test_copyFiles_withSrcAndDstFilesWithSelectionWithJamfProInstance() throws {
        // Given
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let selectedItems: [DpFile] = [ srcDp.dpFiles.files[0], srcDp.dpFiles.files[3], srcDp.dpFiles.files[6]]
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let jamfProInstance = MockJamfProInstance()
        jamfProInstance.packages = packagesFromDpFiles(dpFiles: dstDp.dpFiles.files)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: jamfProInstance, forceSync: false, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 388888)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 388888)
        XCTAssertEqual(jamfProInstance.filesAdded.count, 1)
        XCTAssertEqual(jamfProInstance.packagesUpdated.count, 1)
    }

    func test_copyFiles_withSrcAndDstFilesWithSelectionForceWithJamfProInstance() throws {
        // Given
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let selectedItems: [DpFile] = [ srcDp.dpFiles.files[0], srcDp.dpFiles.files[3], srcDp.dpFiles.files[6]]
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)
        let jamfProInstance = MockJamfProInstance()
        jamfProInstance.packages = packagesFromDpFiles(dpFiles: dstDp.dpFiles.files)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // Not as testable otherwise since it does it in the main thread, which may not happen until after the test is completed

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: jamfProInstance, forceSync: true, progress: synchronizationProgress)
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNotNil(findLogMessage(messageString: "Finished synchronizing from TestSrcDp (local) to TestDstDp (local)"))
        XCTAssertEqual(synchronizationProgress.totalSize, 512344)
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 333333)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 512344)
        XCTAssertEqual(jamfProInstance.filesAdded.count, 1)
        XCTAssertEqual(jamfProInstance.packagesUpdated.count, 2)
    }

    // MARK: - deleteFilesNotOnSource tests

    func test_deleteFilesNotOnSource_withFolderDpDestination() throws {
        // Given
        let srcDp = MockDistributionPoint(name: "TestSrcDp", fileManager: mockFileManager)
        addTestSrcFiles(dp: srcDp)
        let synchronizationProgress = SynchronizationProgress()
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        addTestDstFiles(dp: dstDp)

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await dstDp.deleteFilesNotOnSource(srcDp: srcDp, progress: synchronizationProgress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(dstDp.filesDeleted.count, 1)
        if dstDp.filesDeleted.count > 0 {
            XCTAssertEqual(dstDp.filesDeleted[0].name, "MissingOnSrc.dmg")
        }
    }

    // MARK: - transferLocal tests

    func test_transferLocal_badFileUrl() throws {
        // Given
        let localPath = "/path"
        let fileName = "fileName.pkg"
        let srcFile = DpFile(name: fileName, size: 123456789)
        let synchronizationProgress = SynchronizationProgress()

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await dp.transferLocal(localPath: localPath, srcFile: srcFile, moveFrom: nil, progress: synchronizationProgress)

                // Then
                XCTFail("It should have failed with DistributionPointError.badFileUrl")
            } catch DistributionPointError.badFileUrl {
                // All good
            }

            // For this type of DP, nothing happens, but need to make sure it returns without error.
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_transferLocal_copy() throws {
        // Given
        let localPath = "/dst/path"
        let fileName = "fileName.pkg"
        let srcFile = DpFile(name: fileName, fileUrl: URL(fileURLWithPath: "/src/path/fileName.pkg"), size: 123456789)
        let synchronizationProgress = SynchronizationProgress()
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        synchronizationProgress.printToConsole = true // So it will update before the test is over
        synchronizationProgress.currentTotalSizeTransferred = 1234

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await dstDp.transferLocal(localPath: localPath, srcFile: srcFile, moveFrom: nil, progress: synchronizationProgress)

            // For this type of DP, nothing happens, but need to make sure it returns without error.
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

    func test_transferLocal_move() throws {
        // Given
        let localPath = "/dst/path"
        let fileName = "fileName.pkg"
        let srcFile = DpFile(name: fileName, size: 123456789)
        let synchronizationProgress = SynchronizationProgress()
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        synchronizationProgress.printToConsole = true // So it will update before the test is over
        synchronizationProgress.currentTotalSizeTransferred = 1234

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await dstDp.transferLocal(localPath: localPath, srcFile: srcFile, moveFrom: URL(fileURLWithPath: "/src/path/fileName.pkg"), progress: synchronizationProgress)

            // For this type of DP, nothing happens, but need to make sure it returns without error.
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(mockFileManager.itemRemoved, URL(fileURLWithPath: "/dst/path/fileName.pkg"))
        XCTAssertEqual(mockFileManager.srcItemMoved, URL(fileURLWithPath: "/src/path/fileName.pkg"))
        XCTAssertEqual(mockFileManager.dstItemMoved, URL(fileURLWithPath: "/dst/path/fileName.pkg"))
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 123456789)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 123458023)
   }

    func test_transferLocal_removeFailed() throws {
        // Given
        let localPath = "/dst/path"
        let fileName = "fileName.pkg"
        let srcFile = DpFile(name: fileName, fileUrl: URL(fileURLWithPath: "/src/path/fileName.pkg"), size: 123456789)
        let synchronizationProgress = SynchronizationProgress()
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        mockFileManager.removeItemError = TestErrors.SomethingWentHaywire
        synchronizationProgress.printToConsole = true // So it will update before the test is over
        synchronizationProgress.currentTotalSizeTransferred = 1234

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await dstDp.transferLocal(localPath: localPath, srcFile: srcFile, moveFrom: nil, progress: synchronizationProgress)

            // For this type of DP, nothing happens, but need to make sure it returns without error.
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertNil(mockFileManager.itemRemoved)
        XCTAssertEqual(mockFileManager.srcItemCopied, URL(fileURLWithPath: "/src/path/fileName.pkg"))
        XCTAssertEqual(mockFileManager.dstItemCopied, URL(fileURLWithPath: "/dst/path/fileName.pkg"))
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 123456789)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 123458023)
    }

    func test_transferLocal_copyFailed() throws {
        // Given
        let localPath = "/dst/path"
        let fileName = "fileName.pkg"
        let srcFile = DpFile(name: fileName, fileUrl: URL(fileURLWithPath: "/src/path/fileName.pkg"), size: 123456789)
        let synchronizationProgress = SynchronizationProgress()
        let dstDp = MockDistributionPoint(name: "TestDstDp", fileManager: mockFileManager)
        mockFileManager.copyError = TestErrors.SomethingWentHaywire

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await dstDp.transferLocal(localPath: localPath, srcFile: srcFile, moveFrom: nil, progress: synchronizationProgress)

                // Then
                XCTFail("It should have thrown an exception")
            } catch TestErrors.SomethingWentHaywire {
                // All is well
            }

            // For this type of DP, nothing happens, but need to make sure it returns without error.
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(mockFileManager.itemRemoved, URL(fileURLWithPath: "/dst/path/fileName.pkg"))
        XCTAssertNil(mockFileManager.srcItemCopied)
        XCTAssertNil(mockFileManager.dstItemCopied)
    }

    // MARK: - Private helpers

    private func findLogMessage(messageString: String) -> LogMessage? {
        return logMessages.first { $0.message == messageString }
    }

    private func addTestSrcFiles(dp: DistributionPoint) {
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .SHA_512, value: "abcdef123456"))
        dp.dpFiles.files.append(DpFile(name: "MatchingSha512.pkg", size: 123456, checksums: checksums1))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "a1b2c3d4e5"))
        dp.dpFiles.files.append(DpFile(name: "MismatchedSha512.dmg", size: 890, checksums: checksums2))

        let checksums3 = Checksums()
        checksums3.updateChecksum(Checksum(type: .MD5, value: "a1b2c3"))
        dp.dpFiles.files.append(DpFile(name: "MatchingMd5.pkg", size: 12345678, checksums: checksums3))

        let checksums4 = Checksums()
        checksums4.updateChecksum(Checksum(type: .MD5, value: "bad123"))
        dp.dpFiles.files.append(DpFile(name: "MismatchedMd5.pkg", size: 55555, checksums: checksums4))

        dp.dpFiles.files.append(DpFile(name: "SizeMatched.pkg", size: 11111111))

        dp.dpFiles.files.append(DpFile(name: "SizeMismatch.pkg", size: 2222))

        dp.dpFiles.files.append(DpFile(name: "MissingOnDst.dmg", size: 333333))
    }

    private func addTestDstFiles(dp: DistributionPoint) {
        let checksums1 = Checksums()
        checksums1.updateChecksum(Checksum(type: .SHA_512, value: "abcdef123456"))
        dp.dpFiles.files.append(DpFile(name: "MatchingSha512.pkg", size: 123456, checksums: checksums1))

        let checksums2 = Checksums()
        checksums2.updateChecksum(Checksum(type: .SHA_512, value: "a1b2c3d4e5f6"))
        dp.dpFiles.files.append(DpFile(name: "MismatchedSha512.dmg", size: 890, checksums: checksums2))

        let checksums3 = Checksums()
        checksums3.updateChecksum(Checksum(type: .MD5, value: "a1b2c3"))
        dp.dpFiles.files.append(DpFile(name: "MatchingMd5.pkg", size: 12345678, checksums: checksums3))

        let checksums4 = Checksums()
        checksums4.updateChecksum(Checksum(type: .MD5, value: "bad12345"))
        dp.dpFiles.files.append(DpFile(name: "MismatchedMd5.pkg", size: 55555, checksums: checksums4))

        dp.dpFiles.files.append(DpFile(name: "SizeMatched.pkg", size: 11111111))

        dp.dpFiles.files.append(DpFile(name: "SizeMismatch.pkg", size: 22222))

        dp.dpFiles.files.append(DpFile(name: "MissingOnSrc.dmg", size: 456789))
    }

    private func packagesFromDpFiles(dpFiles: [DpFile]) -> [Package] {
        var packages: [Package] = []
        for dpFile in dpFiles {
            packages.append(packagesFromDpFile(dpFile: dpFile))
        }
        return packages
    }

    private func packagesFromDpFile(dpFile: DpFile) -> Package {
        return Package(jamfProId: 0, displayName: dpFile.name, fileName: dpFile.name, category: "", size: dpFile.size, checksums: dpFile.checksums)
    }
}
