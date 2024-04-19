//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import XCTest

final class SynchronizeTaskTests: XCTestCase {
    let synchronizeTask = SynchronizeTask()
    let srcDp = MockDistributionPointSync(name: "Source DP")
    let dstDp = MockDistributionPointSync(name: "Destination DP")
    let jamfProInstance = MockJamfProInstance()

    // MARK: - synchronize tests

    func test_synchronize_happyPath() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = false
        let deletePackages = false
        let progress = SynchronizationProgress()

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertTrue(srcDp.prepareDpCalled)
        XCTAssertTrue(srcDp.retrieveFileListCalled)
        XCTAssertTrue(dstDp.prepareDpCalled)
        XCTAssertTrue(dstDp.retrieveFileListCalled)
        XCTAssertTrue(srcDp.copyFilesCalled)
        XCTAssertFalse(dstDp.deleteFilesNotOnSourceCalled)
        XCTAssertFalse(jamfProInstance.deletePackagesNotOnSourceCalled)
    }

    func testtest_synchronize_canceled() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()
        srcDp.cancel()

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertTrue(srcDp.prepareDpCalled)
        XCTAssertTrue(srcDp.retrieveFileListCalled)
        XCTAssertTrue(dstDp.prepareDpCalled)
        XCTAssertTrue(dstDp.retrieveFileListCalled)
        XCTAssertTrue(srcDp.copyFilesCalled)
        XCTAssertFalse(dstDp.deleteFilesNotOnSourceCalled)
        XCTAssertFalse(jamfProInstance.deletePackagesNotOnSourceCalled)
    }

    func test_synchronize_deleteFilesAndPackages() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertTrue(srcDp.prepareDpCalled)
        XCTAssertTrue(srcDp.retrieveFileListCalled)
        XCTAssertTrue(dstDp.prepareDpCalled)
        XCTAssertTrue(dstDp.retrieveFileListCalled)
        XCTAssertTrue(srcDp.copyFilesCalled)
        XCTAssertTrue(dstDp.deleteFilesNotOnSourceCalled)
        XCTAssertTrue(jamfProInstance.deletePackagesNotOnSourceCalled)
    }

    func test_synchronize_deleteFiles() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = false
        let progress = SynchronizationProgress()

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertTrue(srcDp.prepareDpCalled)
        XCTAssertTrue(srcDp.retrieveFileListCalled)
        XCTAssertTrue(dstDp.prepareDpCalled)
        XCTAssertTrue(dstDp.retrieveFileListCalled)
        XCTAssertTrue(srcDp.copyFilesCalled)
        XCTAssertTrue(dstDp.deleteFilesNotOnSourceCalled)
        XCTAssertFalse(jamfProInstance.deletePackagesNotOnSourceCalled)
    }

    func test_synchronize_deletePackages() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = false
        let deletePackages = true
        let progress = SynchronizationProgress()

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertTrue(srcDp.prepareDpCalled)
        XCTAssertTrue(srcDp.retrieveFileListCalled)
        XCTAssertTrue(dstDp.prepareDpCalled)
        XCTAssertTrue(dstDp.retrieveFileListCalled)
        XCTAssertTrue(srcDp.copyFilesCalled)
        XCTAssertFalse(dstDp.deleteFilesNotOnSourceCalled)
        XCTAssertTrue(jamfProInstance.deletePackagesNotOnSourceCalled)
    }

    func test_synchronize_noDeletionOfFilesOrPackages() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = false
        let deletePackages = false
        let progress = SynchronizationProgress()

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertTrue(srcDp.prepareDpCalled)
        XCTAssertTrue(srcDp.retrieveFileListCalled)
        XCTAssertTrue(dstDp.prepareDpCalled)
        XCTAssertTrue(dstDp.retrieveFileListCalled)
        XCTAssertTrue(srcDp.copyFilesCalled)
        XCTAssertFalse(dstDp.deleteFilesNotOnSourceCalled)
        XCTAssertFalse(jamfProInstance.deletePackagesNotOnSourceCalled)
    }

    func test_synchronize_withSelectedItems() throws {
        // Given
        let selectedItems: [DpFile] = [ DpFile(name: "TestFile", size: 12345) ]
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertTrue(srcDp.prepareDpCalled)
        XCTAssertTrue(srcDp.retrieveFileListCalled)
        XCTAssertTrue(dstDp.prepareDpCalled)
        XCTAssertTrue(dstDp.retrieveFileListCalled)
        XCTAssertTrue(srcDp.copyFilesCalled)
        XCTAssertFalse(dstDp.deleteFilesNotOnSourceCalled)
        XCTAssertFalse(jamfProInstance.deletePackagesNotOnSourceCalled)
    }

    func test_synchronize_deleteOnJamfProInstance() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertTrue(srcDp.prepareDpCalled)
        XCTAssertTrue(srcDp.retrieveFileListCalled)
        XCTAssertTrue(dstDp.prepareDpCalled)
        XCTAssertTrue(dstDp.retrieveFileListCalled)
        XCTAssertTrue(srcDp.copyFilesCalled)
        XCTAssertTrue(dstDp.deleteFilesNotOnSourceCalled)
        XCTAssertTrue(jamfProInstance.deletePackagesNotOnSourceCalled)
    }

    func test_synchronize_srcPrepareDpFailed() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()
        srcDp.prepareDpError = TestErrors.SomethingWentHaywire

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

                // Then
                XCTFail("Should have thrown a TestErrors.SomethingWentHaywire exception")
            } catch TestErrors.SomethingWentHaywire {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_synchronize_srcRetrieveFileListFailed() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()
        srcDp.retrieveFileListError = TestErrors.SomethingWentHaywire

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

                // Then
                XCTFail("Should have thrown a TestErrors.SomethingWentHaywire exception")
            } catch TestErrors.SomethingWentHaywire {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_synchronize_dstPrepareDpFailed() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()
        dstDp.prepareDpError = TestErrors.SomethingWentHaywire

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

                // Then
                XCTFail("Should have thrown a TestErrors.SomethingWentHaywire exception")
            } catch TestErrors.SomethingWentHaywire {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_synchronize_dstRetrieveFileListFailed() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()
        dstDp.retrieveFileListError = TestErrors.SomethingWentHaywire

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

                // Then
                XCTFail("Should have thrown a TestErrors.SomethingWentHaywire exception")
            } catch TestErrors.SomethingWentHaywire {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_synchronize_copyFilesFailed() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()
        srcDp.copyFilesError = TestErrors.SomethingWentHaywire

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

                // Then
                XCTFail("Should have thrown a TestErrors.SomethingWentHaywire exception")
            } catch TestErrors.SomethingWentHaywire {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_synchronize_dstDeleteFilesNotOnSourceFailed() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()
        dstDp.deleteFilesNotOnSourceError = TestErrors.SomethingWentHaywire

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

                // Then
                XCTFail("Should have thrown a TestErrors.SomethingWentHaywire exception")
            } catch TestErrors.SomethingWentHaywire {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_synchronize_deletePackagesNotOnSourceFailed() throws {
        // Given
        let selectedItems: [DpFile] = []
        let forceSync = false
        let deleteFiles = true
        let deletePackages = true
        let progress = SynchronizationProgress()
        jamfProInstance.deletePackagesNotOnSourceError = TestErrors.SomethingWentHaywire

        // When
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedItems, jamfProInstance: jamfProInstance, forceSync: forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)

                // Then
                XCTFail("Should have thrown a TestErrors.SomethingWentHaywire exception")
            } catch TestErrors.SomethingWentHaywire {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - cancel tests

    func testCancel() {
        // Given
        synchronizeTask.activeDp = srcDp

        // When
        synchronizeTask.cancel()

        // Then
        XCTAssertTrue(srcDp.isCanceled)
    }
}
