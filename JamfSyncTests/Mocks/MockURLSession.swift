//
//  Copyright 2026, Jamf
//

@testable import Jamf_Sync
import Foundation

class MockURLSession: URLSessionProtocol {
    var dataResult: (Data, URLResponse)?
    var uploadResult: (Data, URLResponse)?
    var errorToThrow: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = errorToThrow { throw error }
        return dataResult!
    }

    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        if let error = errorToThrow { throw error }
        return uploadResult!
    }
}
