//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import XCTest

class PartialMockJcds2Dp: Jcds2Dp {
    var mockJamfProInstance: MockJamfProInstance?

    override func findJamfProInstance(id: UUID) -> JamfProInstance? {
        return mockJamfProInstance
    }
}

final class Jcds2DpTests: XCTestCase {
    var jcds2Dp = PartialMockJcds2Dp()
    var mockJamfProInstance = MockJamfProInstance()

    override func setUpWithError() throws {
        jcds2Dp.jamfProInstanceId = UUID()
        jcds2Dp.mockJamfProInstance = mockJamfProInstance
        mockJamfProInstance.url = URL(string: "https://jamfUrl.com")
    }

    // MARK: - retrieveFileList tests

    func test_retrieveFileList_happyPath() throws {
        // Given
        let filesRequestResponse = """
[ {
  "fileName" : "Chromecast.pkg",
  "length" : 3987132,
  "md5" : "6cdd3d819c9fb8367d92f127fcbd4f7d",
  "region" : "us-east-1",
  "sha3" : "8f4b80182a0351e077780f7054bff3d78fbd323f032aa65df30108adbdd0ed92544f206a3aa1476d9ef90c681cee22d57419113edddeaccaa64f5bc4795d34fe"
}, {
  "fileName" : "CyberDuck.pkg",
  "length" : 24107206,
  "md5" : "7a93b7fcd13eced3184cb2d0db324b31",
  "region" : "us-east-1",
  "sha3" : "3bae7bb96f1c6d34a56c5512fb421deeb521488b193207f5f737adcbe9c28078037e91c2769fb18fc880c6dbff6632d438e5e4ac40dabdb07e6fdb2e67c31d42"
}, {
  "fileName" : "SelfService.pkg",
  "length" : 158429417,
  "md5" : "04a0cea89b760663b946400862e5f772",
  "region" : "us-east-1",
  "sha3" : "817b2a7a15c28f25b0930eff5f86f333b78025244cf1f1931684c35ed1ed292f3f7ba7871776aae3439a456cdf39a82aff614664ece5d5f93699ed4c5d88a064"
} ]
"""
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json", returnData: filesRequestResponse.data(using: .utf8)))
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.retrieveFileList()

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(jcds2Dp.dpFiles.files.count, 3)
        if jcds2Dp.dpFiles.files.count == 3 {
            var file = jcds2Dp.dpFiles.files[0]
            XCTAssertEqual(file.name, "Chromecast.pkg")
            XCTAssertEqual(file.size, 3987132)
            XCTAssertEqual(file.checksums.findChecksum(type: .MD5)?.value, "6cdd3d819c9fb8367d92f127fcbd4f7d")
            XCTAssertEqual(file.checksums.findChecksum(type: .SHA3_512)?.value, "8f4b80182a0351e077780f7054bff3d78fbd323f032aa65df30108adbdd0ed92544f206a3aa1476d9ef90c681cee22d57419113edddeaccaa64f5bc4795d34fe")
            file = jcds2Dp.dpFiles.files[1]
            XCTAssertEqual(file.name, "CyberDuck.pkg")
            XCTAssertEqual(file.size, 24107206)
            XCTAssertEqual(file.checksums.findChecksum(type: .MD5)?.value, "7a93b7fcd13eced3184cb2d0db324b31")
            XCTAssertEqual(file.checksums.findChecksum(type: .SHA3_512)?.value, "3bae7bb96f1c6d34a56c5512fb421deeb521488b193207f5f737adcbe9c28078037e91c2769fb18fc880c6dbff6632d438e5e4ac40dabdb07e6fdb2e67c31d42")
            file = jcds2Dp.dpFiles.files[2]
            XCTAssertEqual(file.name, "SelfService.pkg")
            XCTAssertEqual(file.size, 158429417)
            XCTAssertEqual(file.checksums.findChecksum(type: .MD5)?.value, "04a0cea89b760663b946400862e5f772")
            XCTAssertEqual(file.checksums.findChecksum(type: .SHA3_512)?.value, "817b2a7a15c28f25b0930eff5f86f333b78025244cf1f1931684c35ed1ed292f3f7ba7871776aae3439a456cdf39a82aff614664ece5d5f93699ed4c5d88a064")
        }

    }

    func test_retrieveFileList_missingFileName() throws {
        // Given
        let filesRequestResponse = """
[ {
  "length" : 3987132,
  "md5" : "6cdd3d819c9fb8367d92f127fcbd4f7d",
  "region" : "us-east-1",
  "sha3" : "8f4b80182a0351e077780f7054bff3d78fbd323f032aa65df30108adbdd0ed92544f206a3aa1476d9ef90c681cee22d57419113edddeaccaa64f5bc4795d34fe"
}, {
  "fileName" : "CyberDuck.pkg",
  "length" : 24107206,
  "md5" : "7a93b7fcd13eced3184cb2d0db324b31",
  "region" : "us-east-1",
  "sha3" : "3bae7bb96f1c6d34a56c5512fb421deeb521488b193207f5f737adcbe9c28078037e91c2769fb18fc880c6dbff6632d438e5e4ac40dabdb07e6fdb2e67c31d42"
}, {
  "fileName" : "SelfService.pkg",
  "length" : 158429417,
  "md5" : "04a0cea89b760663b946400862e5f772",
  "region" : "us-east-1",
  "sha3" : "817b2a7a15c28f25b0930eff5f86f333b78025244cf1f1931684c35ed1ed292f3f7ba7871776aae3439a456cdf39a82aff614664ece5d5f93699ed4c5d88a064"
} ]
"""
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json", returnData: filesRequestResponse.data(using: .utf8)))
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.retrieveFileList()

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(jcds2Dp.dpFiles.files.count, 2)
        if jcds2Dp.dpFiles.files.count == 2 {
            var file = jcds2Dp.dpFiles.files[0]
            XCTAssertEqual(file.name, "CyberDuck.pkg")
            XCTAssertEqual(file.size, 24107206)
            XCTAssertEqual(file.checksums.findChecksum(type: .MD5)?.value, "7a93b7fcd13eced3184cb2d0db324b31")
            XCTAssertEqual(file.checksums.findChecksum(type: .SHA3_512)?.value, "3bae7bb96f1c6d34a56c5512fb421deeb521488b193207f5f737adcbe9c28078037e91c2769fb18fc880c6dbff6632d438e5e4ac40dabdb07e6fdb2e67c31d42")
            file = jcds2Dp.dpFiles.files[1]
            XCTAssertEqual(file.name, "SelfService.pkg")
            XCTAssertEqual(file.size, 158429417)
            XCTAssertEqual(file.checksums.findChecksum(type: .MD5)?.value, "04a0cea89b760663b946400862e5f772")
            XCTAssertEqual(file.checksums.findChecksum(type: .SHA3_512)?.value, "817b2a7a15c28f25b0930eff5f86f333b78025244cf1f1931684c35ed1ed292f3f7ba7871776aae3439a456cdf39a82aff614664ece5d5f93699ed4c5d88a064")
        }

    }

    func test_retrieveFileList_noSize() throws {
        // Given
        let filesRequestResponse = """
[ {
  "fileName" : "CyberDuck.pkg",
  "md5" : "7a93b7fcd13eced3184cb2d0db324b31",
  "region" : "us-east-1",
  "sha3" : "3bae7bb96f1c6d34a56c5512fb421deeb521488b193207f5f737adcbe9c28078037e91c2769fb18fc880c6dbff6632d438e5e4ac40dabdb07e6fdb2e67c31d42"
}, {
  "fileName" : "SelfService.pkg",
  "length" : 158429417,
  "md5" : "04a0cea89b760663b946400862e5f772",
  "region" : "us-east-1",
  "sha3" : "817b2a7a15c28f25b0930eff5f86f333b78025244cf1f1931684c35ed1ed292f3f7ba7871776aae3439a456cdf39a82aff614664ece5d5f93699ed4c5d88a064"
} ]
"""
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json", returnData: filesRequestResponse.data(using: .utf8)))
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await jcds2Dp.retrieveFileList()

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(jcds2Dp.dpFiles.files.count, 2)
        if jcds2Dp.dpFiles.files.count == 2 {
            var file = jcds2Dp.dpFiles.files[0]
            XCTAssertEqual(file.name, "CyberDuck.pkg")
            XCTAssertEqual(file.size, 0)
            XCTAssertEqual(file.checksums.findChecksum(type: .MD5)?.value, "7a93b7fcd13eced3184cb2d0db324b31")
            XCTAssertEqual(file.checksums.findChecksum(type: .SHA3_512)?.value, "3bae7bb96f1c6d34a56c5512fb421deeb521488b193207f5f737adcbe9c28078037e91c2769fb18fc880c6dbff6632d438e5e4ac40dabdb07e6fdb2e67c31d42")
            file = jcds2Dp.dpFiles.files[1]
            XCTAssertEqual(file.name, "SelfService.pkg")
            XCTAssertEqual(file.size, 158429417)
            XCTAssertEqual(file.checksums.findChecksum(type: .MD5)?.value, "04a0cea89b760663b946400862e5f772")
            XCTAssertEqual(file.checksums.findChecksum(type: .SHA3_512)?.value, "817b2a7a15c28f25b0930eff5f86f333b78025244cf1f1931684c35ed1ed292f3f7ba7871776aae3439a456cdf39a82aff614664ece5d5f93699ed4c5d88a064")
        }

    }

    func test_retrieveFileList_noJamfProUrl() throws {
        // Given
        mockJamfProInstance.url = nil
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await jcds2Dp.retrieveFileList()

                // Then
                XCTFail("Should have returned with ServerCommunicationError.noJamfProUrl")
            } catch ServerCommunicationError.noJamfProUrl {
                // All good
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
        XCTAssertFalse(jcds2Dp.filesLoaded)
    }

    func test_retrieveFileList_dataRequestFailedWith500() throws {
        // Given
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json", error: ServerCommunicationError.dataRequestFailed(statusCode: 500)))
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await jcds2Dp.retrieveFileList()

                // Then
                XCTFail("Should have returned with ServerCommunicationError.dataRequestFailed")
            } catch ServerCommunicationError.dataRequestFailed(let statusCode, let message) {
                XCTAssertEqual(statusCode, 500)
                XCTAssertNil(message)
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
        XCTAssertFalse(jcds2Dp.filesLoaded)
    }

    func test_retrieveFileList_parsingError() throws {
        // Given
        let filesRequestResponse = "booger snot"
        let url: URL = mockJamfProInstance.url!.appendingPathComponent("/api/v1/jcds/files")
        mockJamfProInstance.mockRequestsAndResponses.append(MockDataRequestResponse(url: url, httpMethod: "GET", contentType: "application/json", returnData: filesRequestResponse.data(using: .utf8)))
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await jcds2Dp.retrieveFileList()

                // Then
                XCTFail("Should have returned with ServerCommunicationError.parsingError")
            } catch ServerCommunicationError.parsingError {
                // All good
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
        XCTAssertFalse(jcds2Dp.filesLoaded)
    }
}
