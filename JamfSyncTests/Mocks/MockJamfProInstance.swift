//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import Foundation

struct MockDataRequestResponse {
    var url: URL
    var httpMethod: String
    var httpBodyData: Data?
    var contentType: String
    var returnData: Data?
    var returnResponse: URLResponse?
    var error: Error?
}

class MockJamfProInstance: JamfProInstance {
    var filesAdded: [DpFile] = []
    var packagesUpdated: [Package] = []
    var deletePackagesNotOnSourceCalled = false
    var deletePackagesNotOnSourceError: Error?
    var mockRequestsAndResponses: [MockDataRequestResponse] = []

    override func addPackage(dpFile: DpFile) async throws {
        filesAdded.append(dpFile)
    }

    override func updatePackage(package: Package) async throws {
        packagesUpdated.append(package)
    }

    override func deletePackagesNotOnSource(srcDp: DistributionPoint, progress: SynchronizationProgress) async throws {
        if let deletePackagesNotOnSourceError {
            throw deletePackagesNotOnSourceError
        }
        deletePackagesNotOnSourceCalled = true
    }

    override func dataRequest(url: URL, httpMethod: String, httpBody: Data? = nil, contentType: String = "application/json", acceptType: String? = nil, throwHttpError: Bool = true, timeout: Double = JamfProInstance.normalTimeoutValue) async throws -> (data: Data?, response: URLResponse?) {
        if let requestResponse = findRequestResponse(url: url, httpMethod: httpMethod, httpBody: httpBody, contentType: contentType) {
            if let error = requestResponse.error {
                throw error
            }
            return (data: requestResponse.returnData, response: requestResponse.returnResponse)
        }
        return (data: nil, response: nil)
    }

    // MARK: - Private helpers

    private func findRequestResponse(url: URL, httpMethod: String, httpBody: Data?, contentType: String) -> MockDataRequestResponse? {
        mockRequestsAndResponses.first { return $0.url == url && $0.httpMethod == httpMethod && $0.httpBodyData == httpBody && $0.contentType == contentType }
    }
}
