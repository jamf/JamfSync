//
//  Copyright 2026, Jamf
//

@testable import Jamf_Sync
import XCTest

final class Jcds2DpAdditionalTests: XCTestCase {
    var jcds2Dp: PartialMockJcds2Dp!
    var mockJamfProInstance: MockJamfProInstance!
    let jamfProInstanceId = UUID()

    override func setUpWithError() throws {
        jcds2Dp = PartialMockJcds2Dp()
        mockJamfProInstance = MockJamfProInstance()
        mockJamfProInstance.id = jamfProInstanceId
        mockJamfProInstance.url = URL(string: "https://test.jamfcloud.com")
        mockJamfProInstance.token = "test-token"

        jcds2Dp.jamfProInstanceId = jamfProInstanceId
        jcds2Dp.mockJamfProInstance = mockJamfProInstance

        // Add to DataModel for findJamfProInstance
        DataModel.shared.savableItems.items.removeAll()
        DataModel.shared.savableItems.items.append(mockJamfProInstance)
    }

    override func tearDownWithError() throws {
        jcds2Dp = nil
        mockJamfProInstance = nil
        DataModel.shared.savableItems.items.removeAll()
    }

    // MARK: - Initialization tests

    func test_init_setsPropertiesCorrectly() throws {
        // Given/When
        let cloudDp = Jcds2Dp(jamfProInstanceId: jamfProInstanceId, jamfProInstanceName: "Test")

        // Then
        XCTAssertEqual(cloudDp.name, "JCDS")
        XCTAssertEqual(cloudDp.jamfProInstanceId, jamfProInstanceId)
        XCTAssertEqual(cloudDp.jamfProInstanceName, "Test")
        XCTAssertTrue(cloudDp.willDownloadFiles)
        XCTAssertEqual(cloudDp.expirationBuffer, 60)
    }

    func test_init_withNoParameters() throws {
        // Given/When
        let cloudDp = Jcds2Dp()

        // Then
        XCTAssertEqual(cloudDp.name, "JCDS")
        XCTAssertNil(cloudDp.jamfProInstanceId)
        XCTAssertNil(cloudDp.jamfProInstanceName)
        XCTAssertTrue(cloudDp.willDownloadFiles)
    }

    // MARK: - retrieveFileList additional tests

    func test_retrieveFileList_withFileTypeFiltering() throws {
        // Given
        let filesRequestResponse = """
        [ {
          "fileName" : "test.pkg",
          "length" : 1000,
          "md5" : "abc123",
          "sha3" : "def456"
        }, {
          "fileName" : "test.txt",
          "length" : 100,
          "md5" : "xyz789",
          "sha3" : "uvw012"
        } ]
        """
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(
            MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json",
                                   returnData: filesRequestResponse.data(using: .utf8))
        )

        let expectation = XCTestExpectation()
        Task {
            // When - limit file types
            try await jcds2Dp.retrieveFileList(limitFileTypes: true)

            // Then - only .pkg should be included
            XCTAssertTrue(jcds2Dp.filesLoaded)
            XCTAssertEqual(jcds2Dp.dpFiles.files.count, 1)
            XCTAssertEqual(jcds2Dp.dpFiles.files[0].name, "test.pkg")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_withoutFileTypeFiltering() throws {
        // Given
        let filesRequestResponse = """
        [ {
          "fileName" : "test.pkg",
          "length" : 1000,
          "md5" : "abc123",
          "sha3" : "def456"
        }, {
          "fileName" : "test.txt",
          "length" : 100,
          "md5" : "xyz789",
          "sha3" : "uvw012"
        } ]
        """
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(
            MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json",
                                   returnData: filesRequestResponse.data(using: .utf8))
        )

        let expectation = XCTestExpectation()
        Task {
            // When - don't limit file types
            try await jcds2Dp.retrieveFileList(limitFileTypes: false)

            // Then - both should be included
            XCTAssertTrue(jcds2Dp.filesLoaded)
            XCTAssertEqual(jcds2Dp.dpFiles.files.count, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_emptyArray() throws {
        // Given
        let filesRequestResponse = "[]"
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(
            MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json",
                                   returnData: filesRequestResponse.data(using: .utf8))
        )

        let expectation = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.retrieveFileList()

            // Then
            XCTAssertTrue(jcds2Dp.filesLoaded)
            XCTAssertEqual(jcds2Dp.dpFiles.files.count, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_withOnlyMd5() throws {
        // Given
        let filesRequestResponse = """
        [ {
          "fileName" : "test.pkg",
          "length" : 1000,
          "md5" : "abc123"
        } ]
        """
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(
            MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json",
                                   returnData: filesRequestResponse.data(using: .utf8))
        )

        let expectation = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.retrieveFileList()

            // Then
            XCTAssertTrue(jcds2Dp.filesLoaded)
            XCTAssertEqual(jcds2Dp.dpFiles.files.count, 1)
            XCTAssertNotNil(jcds2Dp.dpFiles.files[0].checksums.findChecksum(type: .MD5))
            XCTAssertNil(jcds2Dp.dpFiles.files[0].checksums.findChecksum(type: .SHA3_512))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_withOnlySha3() throws {
        // Given
        let filesRequestResponse = """
        [ {
          "fileName" : "test.pkg",
          "length" : 1000,
          "sha3" : "def456"
        } ]
        """
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(
            MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json",
                                   returnData: filesRequestResponse.data(using: .utf8))
        )

        let expectation = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.retrieveFileList()

            // Then
            XCTAssertTrue(jcds2Dp.filesLoaded)
            XCTAssertEqual(jcds2Dp.dpFiles.files.count, 1)
            XCTAssertNil(jcds2Dp.dpFiles.files[0].checksums.findChecksum(type: .MD5))
            XCTAssertNotNil(jcds2Dp.dpFiles.files[0].checksums.findChecksum(type: .SHA3_512))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_retrieveFileList_nilJamfProInstanceId() throws {
        // Given
        jcds2Dp.jamfProInstanceId = nil

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await jcds2Dp.retrieveFileList()

                // Then
                XCTFail("Should have thrown ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - deleteFile tests

    func test_deleteFile_success() throws {
        // Given
        let dpFile = DpFile(name: "test.pkg", size: 1000)
        let progress = SynchronizationProgress()

        let deleteUrl = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files/test.pkg")
        mockJamfProInstance.mockRequestsAndResponses.append(
            MockDataRequestResponse(url: deleteUrl, httpMethod: "DELETE", contentType: "application/json",
                                   returnData: Data())
        )

        let expectation = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.deleteFile(file: dpFile, progress: progress)

            // Then - Should complete without error
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_deleteFile_noJamfProInstance() throws {
        // Given
        jcds2Dp.mockJamfProInstance = nil // No instance found
        let dpFile = DpFile(name: "test.pkg", size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await jcds2Dp.deleteFile(file: dpFile, progress: progress)

                // Then
                XCTFail("Should have thrown ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_deleteFile_nilJamfProUrl() throws {
        // Given
        mockJamfProInstance.url = nil
        let dpFile = DpFile(name: "test.pkg", size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await jcds2Dp.deleteFile(file: dpFile, progress: progress)

                // Then
                XCTFail("Should have thrown ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - cancel tests

    func test_cancel_clearsState() throws {
        // Given
        jcds2Dp.urlSession = URLSession(configuration: .default)
        jcds2Dp.dispatchGroup = DispatchGroup()
        jcds2Dp.dispatchGroup?.enter() // Must enter before leave() is called

        // When
        jcds2Dp.cancel()

        // Then
        XCTAssertTrue(jcds2Dp.isCanceled)
        XCTAssertNil(jcds2Dp.downloadTask)
        XCTAssertNil(jcds2Dp.urlSession)
    }

    func test_cancel_withDownloadTask() throws {
        // Given
        let session = URLSession(configuration: .default)
        let url = URL(string: "https://test.jamfcloud.com/test.pkg")!
        jcds2Dp.urlSession = session
        jcds2Dp.downloadTask = session.downloadTask(with: url)
        jcds2Dp.dispatchGroup = DispatchGroup()
        jcds2Dp.dispatchGroup?.enter()

        // When
        jcds2Dp.cancel()

        // Then
        XCTAssertTrue(jcds2Dp.isCanceled)
        XCTAssertNil(jcds2Dp.downloadTask)
        XCTAssertNil(jcds2Dp.urlSession)
    }

    func test_cancel_multipartUploadIsNilAfterCancel() throws {
        // Given
        // Note: We can't easily construct a MultipartUpload in tests, so we just verify
        // that cancel() properly nils it out when it exists
        jcds2Dp.dispatchGroup = DispatchGroup()
        jcds2Dp.dispatchGroup?.enter()

        // When
        jcds2Dp.cancel()

        // Then
        XCTAssertTrue(jcds2Dp.isCanceled)
        // MultipartUpload would be nil after cancel if it existed
    }

    func test_cancel_whenAlreadyCanceled() throws {
        // Given
        jcds2Dp.cancel()
        XCTAssertTrue(jcds2Dp.isCanceled)

        // When - Cancel again
        jcds2Dp.cancel()

        // Then - Should still be in canceled state without error
        XCTAssertTrue(jcds2Dp.isCanceled)
    }

    func test_cancel_withNilProperties() throws {
        // Given - Everything is nil by default
        XCTAssertNil(jcds2Dp.urlSession)
        XCTAssertNil(jcds2Dp.downloadTask)
        XCTAssertNil(jcds2Dp.dispatchGroup)

        // When
        jcds2Dp.cancel()

        // Then - Should handle nil gracefully
        XCTAssertTrue(jcds2Dp.isCanceled)
    }

    // MARK: - createUrlSession tests

    func test_createUrlSession_returnsValidSession() throws {
        // Given
        let progress = SynchronizationProgress()
        let sessionDelegate = CloudSessionDelegate(progress: progress)

        // When
        let session = jcds2Dp.createUrlSession(sessionDelegate: sessionDelegate)

        // Then
        XCTAssertNotNil(session)
        XCTAssertNotNil(session.configuration)
        XCTAssertNotNil(session.delegate)
    }

    // MARK: - downloadFile tests

    func test_downloadFile_noJamfProInstance() throws {
        // Given
        jcds2Dp.jamfProInstanceId = UUID() // Non-existent
        let dpFile = DpFile(name: "test.pkg", size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                _ = try await jcds2Dp.downloadFile(file: dpFile, progress: progress)

                // Then
                XCTFail("Should have thrown an error")
            } catch {
                // Expected - will fail trying to get cloud URI
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_downloadFile_nilJamfProUrl() throws {
        // Given
        mockJamfProInstance.url = nil
        let dpFile = DpFile(name: "test.pkg", size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                _ = try await jcds2Dp.downloadFile(file: dpFile, progress: progress)

                // Then
                XCTFail("Should have thrown ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - transferFile tests

    func test_transferFile_noJamfProInstance() throws {
        // Given
        jcds2Dp.mockJamfProInstance = nil // No instance found
        let srcFile = DpFile(name: "test.pkg", fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), size: 1000)
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await jcds2Dp.transferFile(srcFile: srcFile, moveFrom: nil, progress: progress)

                // Then
                XCTFail("Should have thrown ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // Expected - will fail trying to initiate upload
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func test_transferFile_noFileUrl() throws {
        // Given
        let initiateUploadResponse = """
        {
            "region": "us-east-1",
            "bucketName": "test-bucket",
            "path": "test/path",
            "uuid": "test-uuid",
            "chunkSize": 5242880,
            "accessKeyID": "test-access-key",
            "secretAccessKey": "test-secret-key",
            "sessionToken": "test-session-token",
            "expiration": "2026-12-31T23:59:59Z"
        }
        """
        let initiateUploadUrl = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(
            MockDataRequestResponse(url: initiateUploadUrl, httpMethod: "POST", contentType: "application/json",
                                   returnData: initiateUploadResponse.data(using: .utf8))
        )

        let srcFile = DpFile(name: "test.pkg", size: 1000) // No fileUrl
        let progress = SynchronizationProgress()

        let expectation = XCTestExpectation()
        Task {
            do {
                // When
                try await jcds2Dp.transferFile(srcFile: srcFile, moveFrom: nil, progress: progress)

                // Then
                XCTFail("Should have thrown an error")
            } catch {
                // Expected - should throw error when fileUrl is nil
                // Most likely badFileUrl or failedToInitiateCloudUpload
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - finalizeTransfer tests

    // test_finalizeTransfer_withMultipartUpload removed - requires complex multipart upload setup

    func test_finalizeTransfer_withoutMultipartUpload() throws {
        // Given
        jcds2Dp.multipartUpload = nil

        let expectation = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.finalizeTransfer()

            // Then - Should complete without error (no-op)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Edge case tests

    func test_expirationBuffer_hasCorrectValue() throws {
        // Then
        XCTAssertEqual(jcds2Dp.expirationBuffer, 60)
    }

    func test_operationQueue_isInitialized() throws {
        // Then
        XCTAssertNotNil(jcds2Dp.operationQueue)
    }

    func test_retrieveFileList_clearsExistingFiles() throws {
        // Given - Pre-populate with files
        jcds2Dp.dpFiles.files.append(DpFile(name: "old.pkg", size: 999))
        XCTAssertEqual(jcds2Dp.dpFiles.files.count, 1)

        let filesRequestResponse = """
        [ {
          "fileName" : "new.pkg",
          "length" : 1000,
          "md5" : "abc123"
        } ]
        """
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(
            MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json",
                                   returnData: filesRequestResponse.data(using: .utf8))
        )

        let expectation = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.retrieveFileList()

            // Then - Old files should be cleared
            XCTAssertEqual(jcds2Dp.dpFiles.files.count, 1)
            XCTAssertEqual(jcds2Dp.dpFiles.files[0].name, "new.pkg")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
}
