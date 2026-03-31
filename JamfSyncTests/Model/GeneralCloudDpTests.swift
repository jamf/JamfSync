//
//  Copyright 2026, Jamf
//

@testable import Jamf_Sync
import XCTest

final class GeneralCloudDpTests: XCTestCase {
    var generalCloudDp: GeneralCloudDp!
    var mockJamfProInstance: MockJamfProInstance!
    let jamfProInstanceId = UUID()
    let jamfProInstanceName = "TestJamfPro"

    override func setUpWithError() throws {
        generalCloudDp = GeneralCloudDp(jamfProInstanceId: jamfProInstanceId, jamfProInstanceName: jamfProInstanceName)
        mockJamfProInstance = MockJamfProInstance()
        mockJamfProInstance.id = jamfProInstanceId
        mockJamfProInstance.name = jamfProInstanceName
        mockJamfProInstance.url = URL(string: "https://test.jamfcloud.com")
        mockJamfProInstance.token = "test-token"

        // Add mock instance to DataModel for findJamfProInstance to work
        DataModel.shared.savableItems.items.removeAll()
        DataModel.shared.savableItems.items.append(mockJamfProInstance)
    }

    override func tearDownWithError() throws {
        generalCloudDp = nil
        mockJamfProInstance = nil
        DataModel.shared.savableItems.items.removeAll()
    }

    // MARK: - Initialization tests

    func test_init_setsPropertiesCorrectly() throws {
        // Given/When - from setUp

        // Then
        XCTAssertEqual(generalCloudDp.name, "Cloud")
        XCTAssertEqual(generalCloudDp.readWrite, .writeOnly)
        XCTAssertEqual(generalCloudDp.jamfProInstanceId, jamfProInstanceId)
        XCTAssertEqual(generalCloudDp.jamfProInstanceName, jamfProInstanceName)
        XCTAssertTrue(generalCloudDp.updatePackageInfoBeforeTransfer)
        XCTAssertTrue(generalCloudDp.willDownloadFiles)
        XCTAssertTrue(generalCloudDp.deleteByRemovingPackage)
    }

    func test_init_withNoParameters() throws {
        // Given/When
        let cloudDp = GeneralCloudDp()

        // Then
        XCTAssertEqual(cloudDp.name, "Cloud")
        XCTAssertNil(cloudDp.jamfProInstanceId)
        XCTAssertNil(cloudDp.jamfProInstanceName)
    }

    // MARK: - retrieveFileList tests

    func test_retrieveFileList_withPackages() throws {
        // Given
        let package1 = Package(jamfProId: 1, displayName: "Package1", fileName: "package1.pkg", category: "Test", size: 1000, checksums: Checksums())
        let package2 = Package(jamfProId: 2, displayName: "Package2", fileName: "package2.dmg", category: "Test", size: 2000, checksums: Checksums())
        mockJamfProInstance.packages = [package1, package2]

        let expectation = XCTestExpectation()
        Task {
            // When
            try await generalCloudDp.retrieveFileList()

            // Then
            XCTAssertTrue(generalCloudDp.filesLoaded)
            XCTAssertEqual(generalCloudDp.dpFiles.files.count, 2)
            XCTAssertEqual(generalCloudDp.dpFiles.files[0].name, "package1.pkg")
            XCTAssertEqual(generalCloudDp.dpFiles.files[0].size, 1000)
            XCTAssertEqual(generalCloudDp.dpFiles.files[1].name, "package2.dmg")
            XCTAssertEqual(generalCloudDp.dpFiles.files[1].size, 2000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_withNoPackages() throws {
        // Given
        mockJamfProInstance.packages = []

        let expectation = XCTestExpectation()
        Task {
            // When
            try await generalCloudDp.retrieveFileList()

            // Then
            XCTAssertTrue(generalCloudDp.filesLoaded)
            XCTAssertEqual(generalCloudDp.dpFiles.files.count, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_limitFileTypes() throws {
        // Given
        let package1 = Package(jamfProId: 1, displayName: "Package1", fileName: "package1.pkg", category: "Test", size: 1000, checksums: Checksums())
        let package2 = Package(jamfProId: 2, displayName: "Package2", fileName: "package2.txt", category: "Test", size: 2000, checksums: Checksums())
        mockJamfProInstance.packages = [package1, package2]

        let expectation = XCTestExpectation()
        Task {
            // When
            try await generalCloudDp.retrieveFileList(limitFileTypes: true)

            // Then - Only .pkg should be included when limiting file types
            XCTAssertTrue(generalCloudDp.filesLoaded)
            XCTAssertEqual(generalCloudDp.dpFiles.files.count, 1)
            XCTAssertEqual(generalCloudDp.dpFiles.files[0].name, "package1.pkg")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_noLimitFileTypes() throws {
        // Given
        let package1 = Package(jamfProId: 1, displayName: "Package1", fileName: "package1.pkg", category: "Test", size: 1000, checksums: Checksums())
        let package2 = Package(jamfProId: 2, displayName: "Package2", fileName: "package2.txt", category: "Test", size: 2000, checksums: Checksums())
        mockJamfProInstance.packages = [package1, package2]

        let expectation = XCTestExpectation()
        Task {
            // When
            try await generalCloudDp.retrieveFileList(limitFileTypes: false)

            // Then - Both should be included when not limiting file types
            XCTAssertTrue(generalCloudDp.filesLoaded)
            XCTAssertEqual(generalCloudDp.dpFiles.files.count, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_noJamfProInstance() throws {
        // Given
        generalCloudDp = GeneralCloudDp(jamfProInstanceId: UUID(), jamfProInstanceName: "NonExistent")

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await generalCloudDp.retrieveFileList()

                // Then
                XCTFail("Should have thrown ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_nilJamfProInstanceId() throws {
        // Given
        generalCloudDp = GeneralCloudDp()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await generalCloudDp.retrieveFileList()

                // Then
                XCTFail("Should have thrown ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - downloadFile tests

    func test_downloadFile_throwsNotSupported() throws {
        // Given
        let dpFile = DpFile(name: "test.pkg", size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                _ = try await generalCloudDp.downloadFile(file: dpFile, progress: progress)

                // Then
                XCTFail("Should have thrown DistributionPointError.downloadingNotSupported")
            } catch DistributionPointError.downloadingNotSupported {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - transferFile tests

    func test_transferFile_noJamfProInstance() throws {
        // Given
        generalCloudDp = GeneralCloudDp(jamfProInstanceId: UUID(), jamfProInstanceName: "NonExistent")
        let srcFile = DpFile(name: "test.pkg", fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await generalCloudDp.transferFile(srcFile: srcFile, moveFrom: nil, progress: progress)

                // Then
                XCTFail("Should have thrown ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_transferFile_packageNotFound() throws {
        // Given
        mockJamfProInstance.packages = []
        let srcFile = DpFile(name: "test.pkg", fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await generalCloudDp.transferFile(srcFile: srcFile, moveFrom: nil, progress: progress)

                // Then
                XCTFail("Should have thrown DistributionPointError.uploadFailure")
            } catch DistributionPointError.uploadFailure {
                // Expected - package not found
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_transferFile_packageMissingJamfProId() throws {
        // Given
        let package = Package(jamfProId: nil, displayName: "test", fileName: "test.pkg", category: "Test", size: 1000, checksums: Checksums())
        mockJamfProInstance.packages = [package]
        let srcFile = DpFile(name: "test.pkg", fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await generalCloudDp.transferFile(srcFile: srcFile, moveFrom: nil, progress: progress)

                // Then
                XCTFail("Should have thrown DistributionPointError.uploadFailure")
            } catch DistributionPointError.uploadFailure {
                // Expected - no Jamf Pro ID
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_transferFile_noFileUrl() throws {
        // Given
        let package = Package(jamfProId: 1, displayName: "test", fileName: "test.pkg", category: "Test", size: 1000, checksums: Checksums())
        mockJamfProInstance.packages = [package]
        let srcFile = DpFile(name: "test.pkg", size: 1000) // No fileUrl
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await generalCloudDp.transferFile(srcFile: srcFile, moveFrom: nil, progress: progress)

                // Then
                XCTFail("Should have thrown DistributionPointError.badFileUrl")
            } catch DistributionPointError.badFileUrl {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - deleteFile tests

    func test_deleteFile_doesNothing() throws {
        // Given
        let dpFile = DpFile(name: "test.pkg", size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            // When
            try await generalCloudDp.deleteFile(file: dpFile, progress: progress)

            // Then - Should complete without error
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - cancel tests

    func test_cancel_clearsState() throws {
        // Given
        generalCloudDp.urlSession = URLSession(configuration: .default)
        generalCloudDp.dispatchGroup = DispatchGroup()
        generalCloudDp.dispatchGroup?.enter() // Must enter before cancel() calls leave()

        // When
        generalCloudDp.cancel()

        // Then
        XCTAssertTrue(generalCloudDp.isCanceled)
        XCTAssertNil(generalCloudDp.downloadTask)
        XCTAssertNil(generalCloudDp.urlSession)
    }

    func test_cancel_withDownloadTask() throws {
        // Given
        let session = URLSession(configuration: .default)
        let url = URL(string: "https://test.jamfcloud.com/test.pkg")!
        generalCloudDp.urlSession = session
        generalCloudDp.downloadTask = session.downloadTask(with: url)
        generalCloudDp.dispatchGroup = DispatchGroup()
        generalCloudDp.dispatchGroup?.enter()

        // When
        generalCloudDp.cancel()

        // Then
        XCTAssertTrue(generalCloudDp.isCanceled)
        XCTAssertNil(generalCloudDp.downloadTask)
        XCTAssertNil(generalCloudDp.urlSession)
    }

    // MARK: - createBoundary tests

    func test_createBoundary_generatesValidBoundary() throws {
        // When
        let boundary = generalCloudDp.createBoundary()

        // Then
        XCTAssertTrue(boundary.hasPrefix("------------------------"))
        XCTAssertEqual(boundary.count, 46) // 24 dashes + 22 random chars

        // Verify it only contains alphanumeric characters after the dashes
        let randomPart = String(boundary.dropFirst(24))
        XCTAssertTrue(randomPart.allSatisfy { $0.isLetter || $0.isNumber })
    }

    func test_createBoundary_generatesUniqueBoundaries() throws {
        // When
        let boundary1 = generalCloudDp.createBoundary()
        let boundary2 = generalCloudDp.createBoundary()
        let boundary3 = generalCloudDp.createBoundary()

        // Then - Should be highly unlikely to generate same boundary twice
        XCTAssertNotEqual(boundary1, boundary2)
        XCTAssertNotEqual(boundary2, boundary3)
        XCTAssertNotEqual(boundary1, boundary3)
    }

    // MARK: - createUrlSession tests

    func test_createUrlSession_returnsValidSession() throws {
        // Given
        let progress = SynchronizationProgress()
        let sessionDelegate = CloudSessionDelegate(progress: progress)

        // When
        let session = generalCloudDp.createUrlSession(sessionDelegate: sessionDelegate)

        // Then
        XCTAssertNotNil(session)
        XCTAssertNotNil(session.configuration)
    }

    // MARK: - Static property tests

    func test_overheadPerFile_isCorrectValue() throws {
        // Then
        XCTAssertEqual(GeneralCloudDp.overheadPerFile, 112)
    }

    // MARK: - Integration test concepts (without actual upload)

    func test_transferFile_setsCorrectOverheadSize() throws {
        // Given
        let package = Package(jamfProId: 1, displayName: "test", fileName: "test.pkg", category: "Test", size: 1000, checksums: Checksums())
        mockJamfProInstance.packages = [package]

        // Create a real temporary file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_transfer.pkg")
        let testData = "test data".data(using: .utf8)!
        try testData.write(to: testFile)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        let srcFile = DpFile(name: "test.pkg", fileUrl: testFile, size: Int64(testData.count))
        let progress = SynchronizationProgress()
        progress.printToConsole = true

        // Note: This test will fail at upload attempt since we don't have a real server
        // But it should get far enough to verify boundary and overhead calculation
        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await generalCloudDp.transferFile(srcFile: srcFile, moveFrom: nil, progress: progress)

                // If we somehow succeed (shouldn't with mock), that's fine too
                expectation.fulfill()
            } catch {
                // Expected to fail at network call, but we can verify progress was set up
                XCTAssertGreaterThan(progress.overheadSizePerFile, GeneralCloudDp.overheadPerFile)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Edge case tests

    func test_retrieveFileList_withPackagesMissingSize() throws {
        // Given
        let package1 = Package(jamfProId: 1, displayName: "Package1", fileName: "package1.pkg", category: "Test", size: nil, checksums: Checksums())
        mockJamfProInstance.packages = [package1]

        let expectation = XCTestExpectation()
        Task {
            // When
            try await generalCloudDp.retrieveFileList()

            // Then
            XCTAssertTrue(generalCloudDp.filesLoaded)
            XCTAssertEqual(generalCloudDp.dpFiles.files.count, 1)
            XCTAssertNil(generalCloudDp.dpFiles.files[0].size)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_withPackagesHavingChecksums() throws {
        // Given
        let checksums = Checksums()
        checksums.updateChecksum(Checksum(type: .MD5, value: "abc123"))
        checksums.updateChecksum(Checksum(type: .SHA_256, value: "def456"))

        let package1 = Package(jamfProId: 1, displayName: "Package1", fileName: "package1.pkg", category: "Test", size: 1000, checksums: checksums)
        mockJamfProInstance.packages = [package1]

        let expectation = XCTestExpectation()
        Task {
            // When
            try await generalCloudDp.retrieveFileList()

            // Then
            XCTAssertTrue(generalCloudDp.filesLoaded)
            XCTAssertEqual(generalCloudDp.dpFiles.files.count, 1)
            XCTAssertNotNil(generalCloudDp.dpFiles.files[0].checksums.findChecksum(type: .MD5))
            XCTAssertNotNil(generalCloudDp.dpFiles.files[0].checksums.findChecksum(type: .SHA_256))
            XCTAssertEqual(generalCloudDp.dpFiles.files[0].checksums.findChecksum(type: .MD5)?.value, "abc123")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_cancel_whenAlreadyCanceled() throws {
        // Given
        generalCloudDp.cancel()
        XCTAssertTrue(generalCloudDp.isCanceled)

        // When - Cancel again
        generalCloudDp.cancel()

        // Then - Should still be in canceled state without error
        XCTAssertTrue(generalCloudDp.isCanceled)
    }

    func test_cancel_withNilProperties() throws {
        // Given - Everything is nil by default after init
        XCTAssertNil(generalCloudDp.urlSession)
        XCTAssertNil(generalCloudDp.downloadTask)
        XCTAssertNil(generalCloudDp.dispatchGroup)

        // When
        generalCloudDp.cancel()

        // Then - Should handle nil gracefully
        XCTAssertTrue(generalCloudDp.isCanceled)
    }
}
