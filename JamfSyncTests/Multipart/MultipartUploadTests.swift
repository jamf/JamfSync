//
//  Copyright 2026, Jamf
//

@testable import Jamf_Sync
import XCTest

// MARK: - Helpers

class MockRenewToken: RenewTokenProtocol {
    var renewCalled = false
    func renewUploadToken() async throws {
        renewCalled = true
    }
}

/// Subclass that overrides uploadChunk so processMultipartUpload can be tested without network
class MockMultipartUpload: MultipartUpload {
    var chunkResults: [Int: Error?] = [:] // partNumber -> nil means success, non-nil means throw
    var uploadedChunks: [Int] = []

    override func uploadChunk(whichChunk: Int, uploadId: String, fileUrl: URL, progress: SynchronizationProgress) async throws {
        if let result = chunkResults[whichChunk], let error = result {
            throw error
        }
        uploadedChunks.append(whichChunk)
    }
}

// MARK: - MultipartUploadTests

final class MultipartUploadTests: XCTestCase {

    var upload: MultipartUpload!
    var mockSession: MockURLSession!
    var mockRenew: MockRenewToken!
    var progress: SynchronizationProgress!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockRenew = MockRenewToken()
        progress = SynchronizationProgress()
        upload = MultipartUpload(
            initiateUploadData: makeInitiateUpload(),
            renewTokenObject: mockRenew,
            progress: progress,
            sharedSession: mockSession
        )
    }

    // MARK: - tagValue tests

    func test_tagValue_extractsValueBetweenTags() {
        let xml = "<UploadId>abc-123</UploadId>"
        XCTAssertEqual(upload.tagValue(xmlString: xml, startTag: "<UploadId>", endTag: "</UploadId>"), "abc-123")
    }

    func test_tagValue_returnsEmptyWhenTagMissing() {
        let xml = "<Other>value</Other>"
        XCTAssertEqual(upload.tagValue(xmlString: xml, startTag: "<UploadId>", endTag: "</UploadId>"), "")
    }

    func test_tagValue_returnsEmptyForEmptyString() {
        XCTAssertEqual(upload.tagValue(xmlString: "", startTag: "<UploadId>", endTag: "</UploadId>"), "")
    }

    func test_tagValue_handlesMultipleTags() {
        let xml = "<A>first</A><B>second</B>"
        XCTAssertEqual(upload.tagValue(xmlString: xml, startTag: "<B>", endTag: "</B>"), "second")
    }

    // MARK: - contentType tests

    func test_contentType_pkg() {
        XCTAssertEqual(upload.contentType(filename: "installer.pkg"), "application/x-newton-compatible-pkg")
    }

    func test_contentType_mpkg() {
        XCTAssertEqual(upload.contentType(filename: "installer.mpkg"), "application/x-newton-compatible-pkg")
    }

    func test_contentType_dmg() {
        XCTAssertEqual(upload.contentType(filename: "disk.dmg"), "application/octet-stream")
    }

    func test_contentType_zip() {
        XCTAssertEqual(upload.contentType(filename: "archive.zip"), "application/zip")
    }

    func test_contentType_unknown() {
        XCTAssertNil(upload.contentType(filename: "script.sh"))
    }

    // MARK: - createCompletedPartsXml tests

    func test_createCompletedPartsXml_emptyList() {
        let xml = upload.createCompletedPartsXml()
        XCTAssertTrue(xml.contains("<CompleteMultipartUpload>"))
        XCTAssertFalse(xml.contains("<Part>"))
    }

    func test_createCompletedPartsXml_singlePart() {
        upload.partNumberEtagList = [CompletedChunk(partNumber: 1, eTag: "etag1")]
        let xml = upload.createCompletedPartsXml()
        XCTAssertTrue(xml.contains("<PartNumber>1</PartNumber>"))
        XCTAssertTrue(xml.contains("<ETag>etag1</ETag>"))
    }

    func test_createCompletedPartsXml_multiplePartsSortedByPartNumber() {
        upload.partNumberEtagList = [
            CompletedChunk(partNumber: 3, eTag: "etag3"),
            CompletedChunk(partNumber: 1, eTag: "etag1"),
            CompletedChunk(partNumber: 2, eTag: "etag2")
        ]
        let xml = upload.createCompletedPartsXml()
        let pos1 = xml.range(of: "<PartNumber>1</PartNumber>")!.lowerBound
        let pos2 = xml.range(of: "<PartNumber>2</PartNumber>")!.lowerBound
        let pos3 = xml.range(of: "<PartNumber>3</PartNumber>")!.lowerBound
        XCTAssertTrue(pos1 < pos2 && pos2 < pos3, "Parts should be sorted in ascending order")
    }

    // MARK: - hmac_sha256 tests

    func test_hmac_sha256_returns64CharHex() {
        let result = upload.hmac_sha256(date: "20240101", secretKey: "secret", key: "packages/test.pkg", region: "us-east-1", stringToSign: "AWS4-HMAC-SHA256\ntest\nscope\nhash")
        XCTAssertEqual(result.count, 64)
        XCTAssertTrue(result.allSatisfy { $0.isHexDigit }, "Result should be lowercase hex")
    }

    func test_hmac_sha256_deterministicOutput() {
        let args = ("20240101", "secret", "packages/test.pkg", "us-east-1", "stringToSign")
        let result1 = upload.hmac_sha256(date: args.0, secretKey: args.1, key: args.2, region: args.3, stringToSign: args.4)
        let result2 = upload.hmac_sha256(date: args.0, secretKey: args.1, key: args.2, region: args.3, stringToSign: args.4)
        XCTAssertEqual(result1, result2)
    }

    func test_hmac_sha256_differentInputsProduceDifferentOutput() {
        let result1 = upload.hmac_sha256(date: "20240101", secretKey: "secret1", key: "packages/test.pkg", region: "us-east-1", stringToSign: "data")
        let result2 = upload.hmac_sha256(date: "20240101", secretKey: "secret2", key: "packages/test.pkg", region: "us-east-1", stringToSign: "data")
        XCTAssertNotEqual(result1, result2)
    }

    // MARK: - awsSignature256 tests

    func test_awsSignature256_returns64CharHex() {
        let result = upload.awsSignature256(
            for: "sessionToken", httpMethod: "PUT", date: "20240101T000000Z",
            accessKeyId: "AKID", secretKey: "secret", bucket: "mybucket",
            key: "packages/test.pkg", queryParameters: "", region: "us-east-1",
            currentDate: "2024-01-01 00:00:00 +0000"
        )
        XCTAssertEqual(result.count, 64)
        XCTAssertTrue(result.allSatisfy { $0.isHexDigit })
    }

    func test_awsSignature256_deterministicOutput() {
        let sig1 = upload.awsSignature256(for: "token", httpMethod: "PUT", date: "20240101T000000Z", accessKeyId: "AKID", secretKey: "secret", bucket: "bucket", key: "key", queryParameters: "", region: "us-east-1", currentDate: "2024-01-01 00:00:00 +0000")
        let sig2 = upload.awsSignature256(for: "token", httpMethod: "PUT", date: "20240101T000000Z", accessKeyId: "AKID", secretKey: "secret", bucket: "bucket", key: "key", queryParameters: "", region: "us-east-1", currentDate: "2024-01-01 00:00:00 +0000")
        XCTAssertEqual(sig1, sig2)
    }

    func test_awsSignature256_differentMethodProducesDifferentSignature() {
        let sig1 = upload.awsSignature256(for: "token", httpMethod: "PUT", date: "20240101T000000Z", accessKeyId: "AKID", secretKey: "secret", bucket: "bucket", key: "key", queryParameters: "", region: "us-east-1", currentDate: "2024-01-01 00:00:00 +0000")
        let sig2 = upload.awsSignature256(for: "token", httpMethod: "POST", date: "20240101T000000Z", accessKeyId: "AKID", secretKey: "secret", bucket: "bucket", key: "key", queryParameters: "", region: "us-east-1", currentDate: "2024-01-01 00:00:00 +0000")
        XCTAssertNotEqual(sig1, sig2)
    }

    // MARK: - startMultipartUpload tests

    func test_startMultipartUpload_throwsWhenFileSizeExceedsMax() async {
        let fileUrl = URL(fileURLWithPath: "/tmp/large.pkg")
        let oversizedBytes: Int64 = 32_212_255_001

        do {
            _ = try await upload.startMultipartUpload(fileUrl: fileUrl, fileSize: oversizedBytes)
            XCTFail("Should have thrown maxUploadSizeExceeded")
        } catch DistributionPointError.maxUploadSizeExceeded {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_startMultipartUpload_setsCorrectTotalChunks() async throws {
        let chunkSize = upload.chunkSize
        let fileSize = Int64(chunkSize * 3 + 1) // 4 chunks
        let uploadIdXml = "<InitiateMultipartUploadResult><UploadId>uid-abc</UploadId></InitiateMultipartUploadResult>"
        mockSession.dataResult = makeHTTPResponse(body: uploadIdXml, statusCode: 200)

        _ = try await upload.startMultipartUpload(fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), fileSize: fileSize)

        XCTAssertEqual(upload.totalChunks, 4)
    }

    func test_startMultipartUpload_returnsUploadId() async throws {
        let uploadIdXml = "<InitiateMultipartUploadResult><UploadId>uid-abc</UploadId></InitiateMultipartUploadResult>"
        mockSession.dataResult = makeHTTPResponse(body: uploadIdXml, statusCode: 200)

        let uploadId = try await upload.startMultipartUpload(fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), fileSize: 1024)

        XCTAssertEqual(uploadId, "uid-abc")
    }

    func test_startMultipartUpload_throwsOnHTTPError() async {
        mockSession.dataResult = makeHTTPResponse(body: "Service Unavailable", statusCode: 503)

        do {
            _ = try await upload.startMultipartUpload(fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), fileSize: 1024)
            XCTFail("Should have thrown")
        } catch ServerCommunicationError.uploadFailed(let statusCode, _) {
            XCTAssertEqual(statusCode, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_startMultipartUpload_throwsWhenUploadIdMissing() async {
        mockSession.dataResult = makeHTTPResponse(body: "<Error><Message>Access Denied</Message></Error>", statusCode: 200)

        do {
            _ = try await upload.startMultipartUpload(fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), fileSize: 1024)
            XCTFail("Should have thrown uploadFailure")
        } catch DistributionPointError.uploadFailure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - processMultipartUpload tests

    func test_processMultipartUpload_allChunksSucceed() async throws {
        let mockUpload = makeMockUpload()
        mockUpload.totalChunks = 3

        try await mockUpload.processMultipartUpload(whichChunk: 1, uploadId: "uid", fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"))

        XCTAssertEqual(Set(mockUpload.uploadedChunks), Set([1, 2, 3]))
    }

    func test_processMultipartUpload_retriesChunkOnFirstFailure() async throws {
        let mockUpload = makeMockUpload()
        mockUpload.totalChunks = 2
        var callCount = 0
        // Chunk 1 fails on first attempt only
        mockUpload.chunkResults[1] = nil // will be overridden per-call in subclass... need a stateful mock
        // Use a stateful approach: override to fail first call then succeed
        let statefulUpload = StatefulMockMultipartUpload(
            initiateUploadData: makeInitiateUpload(),
            renewTokenObject: mockRenew,
            progress: progress,
            sharedSession: mockSession
        )
        statefulUpload.totalChunks = 2
        statefulUpload.failChunk = 1
        statefulUpload.failCount = 1

        try await statefulUpload.processMultipartUpload(whichChunk: 1, uploadId: "uid", fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"))

        XCTAssertEqual(Set(statefulUpload.uploadedChunks), Set([1, 2]))
    }

    func test_processMultipartUpload_throwsWhenChunkFailsTwice() async {
        let statefulUpload = StatefulMockMultipartUpload(
            initiateUploadData: makeInitiateUpload(),
            renewTokenObject: mockRenew,
            progress: progress,
            sharedSession: mockSession
        )
        statefulUpload.totalChunks = 2
        statefulUpload.failChunk = 1
        statefulUpload.failCount = 2 // always fail chunk 1

        do {
            try await statefulUpload.processMultipartUpload(whichChunk: 1, uploadId: "uid", fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"))
            XCTFail("Should have thrown uploadFailure")
        } catch DistributionPointError.uploadFailure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_processMultipartUpload_stopWhenCanceled() async throws {
        let mockUpload = makeMockUpload()
        mockUpload.totalChunks = 3
        mockUpload.isCanceled = true

        try await mockUpload.processMultipartUpload(whichChunk: 1, uploadId: "uid", fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"))

        XCTAssertTrue(mockUpload.uploadedChunks.isEmpty, "No chunks should upload when already canceled")
    }

    // MARK: - completeMultipartUpload tests

    func test_completeMultipartUpload_succeeds() async throws {
        upload.partNumberEtagList = [CompletedChunk(partNumber: 1, eTag: "etag1")]
        mockSession.dataResult = makeHTTPResponse(body: "<CompleteMultipartUploadResult/>", statusCode: 200)

        try await upload.completeMultipartUpload(fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), uploadId: "uid-abc")
        // No throw = success
    }

    func test_completeMultipartUpload_throwsOnHTTPError() async {
        upload.partNumberEtagList = [CompletedChunk(partNumber: 1, eTag: "etag1")]
        mockSession.dataResult = makeHTTPResponse(body: "Internal Server Error", statusCode: 500)

        do {
            try await upload.completeMultipartUpload(fileUrl: URL(fileURLWithPath: "/tmp/test.pkg"), uploadId: "uid-abc")
            XCTFail("Should have thrown")
        } catch ServerCommunicationError.uploadFailed(let statusCode, _) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeInitiateUpload() -> JsonInitiateUpload {
        let json = """
        {"accessKeyID":"AKID","secretAccessKey":"secret","sessionToken":"token",
         "region":"us-east-1","bucketName":"mybucket","path":"packages/","uuid":"uuid1"}
        """
        let decoder = JSONDecoder()
        return try! decoder.decode(JsonInitiateUpload.self, from: Data(json.utf8))
    }

    private func makeMockUpload() -> MockMultipartUpload {
        MockMultipartUpload(
            initiateUploadData: makeInitiateUpload(),
            renewTokenObject: mockRenew,
            progress: progress,
            sharedSession: mockSession
        )
    }

    private func makeHTTPResponse(body: String, statusCode: Int) -> (Data, URLResponse) {
        let data = Data(body.utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://mybucket.s3.amazonaws.com/")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

// MARK: - StatefulMockMultipartUpload

/// Fails a specific chunk N times then succeeds, to test retry logic
class StatefulMockMultipartUpload: MultipartUpload {
    var failChunk: Int = 0
    var failCount: Int = 0
    var uploadedChunks: [Int] = []
    private var failCallsSoFar = 0

    override func uploadChunk(whichChunk: Int, uploadId: String, fileUrl: URL, progress: SynchronizationProgress) async throws {
        if whichChunk == failChunk && failCallsSoFar < failCount {
            failCallsSoFar += 1
            throw DistributionPointError.uploadFailure
        }
        uploadedChunks.append(whichChunk)
    }
}
