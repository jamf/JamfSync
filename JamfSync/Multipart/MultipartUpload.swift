//
//  Copyright 2024, Jamf
//

import Foundation
import CryptoKit

protocol RenewTokenProtocol {
    func renewUploadToken() async throws
}

class MultipartUpload {
    var initiateUploadData: JsonInitiateUpload
    let renewTokenObject: RenewTokenProtocol
    let progress: SynchronizationProgress
    var uploadTime = UploadTime()
    var partNumberEtagList: [CompletedChunk] = []
    var totalChunks = 0
    let maxUploadSize = 32212255000
    let chunkSize = 1024 * 1024 * 10
    
    let operationQueue = OperationQueue()
    var urlSession: URLSession?
    
    init(initiateUploadData: JsonInitiateUpload, renewTokenObject: RenewTokenProtocol, progress: SynchronizationProgress) {
        self.initiateUploadData = initiateUploadData
        self.renewTokenObject = renewTokenObject
        self.progress = progress
    }
    
    func createUrlSession(sessionDelegate: CloudSessionDelegate) -> URLSession {
        return URLSession(configuration: .default,
                          delegate: sessionDelegate,
                          delegateQueue: operationQueue)
    }
    
    func startMultipartUpload(fileUrl: URL, fileSize: Int64) async throws -> String {
        totalChunks = Int(truncatingIfNeeded: (fileSize + Int64(chunkSize) - 1) / Int64(chunkSize))
        if fileSize > maxUploadSize {
            LogManager.shared.logMessage(message: "Maximum upload file size (30GB) exceeded. File size: \(fileSize)", level: .error)
            throw DistributionPointError.maxUploadSizeExceeded
        }
        LogManager.shared.logMessage(message: "File will be split into \(totalChunks) parts.", level: .debug)

        let filename = fileUrl.lastPathComponent
        LogManager.shared.logMessage(message: "Starting upload of \(filename)", level: .debug)

        let request = try createMultipartUploadRequest(fileUrl: fileUrl, httpMethod: "POST", urlQuery: "uploads=", start: true)

        URLCache.shared.removeAllCachedResponses()

        uploadTime.start = Date().timeIntervalSince1970
        let (responseData, response) = try await URLSession.shared.data(for: request)
        let responseDataString = String(data: responseData, encoding: .utf8) ?? ""
        if let httpResponse = response as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                LogManager.shared.logMessage(message: "Failed to upload \(filename). Status code: \(httpResponse.statusCode)", level: .debug)
                throw ServerCommunicationError.uploadFailed(statusCode: httpResponse.statusCode, message: responseDataString)
            }
        }

        let uploadId = tagValue(xmlString: responseDataString, startTag: "<UploadId>", endTag: "</UploadId>")
        if uploadId != "" {
           return(uploadId)
        } else {
            if let messageRange = responseDataString.range(of: "<Message>(.*?)</Message>", options: .regularExpression) {
                var message = responseDataString[messageRange]
                message = "\(message.replacingOccurrences(of: "<Message>", with: "").replacingOccurrences(of: "</Message>", with: ""))"
                LogManager.shared.logMessage(message: "Error occurred when starting the multipart upload: \(message)", level: .error)
            } else {
                LogManager.shared.logMessage(message: "Error occurred when starting the multipart upload: \(responseDataString)", level: .error)
            }
            throw DistributionPointError.uploadFailure
        }
    }

    private func tagValue(xmlString:String, startTag:String, endTag:String) -> String {
        var rawValue = ""
        if let start = xmlString.range(of: startTag),
            let end  = xmlString.range(of: endTag, range: start.upperBound..<xmlString.endIndex) {
            rawValue.append(String(xmlString[start.upperBound..<end.lowerBound]))
        }
        return rawValue
    }

    private func createMultipartUploadRequest(fileUrl: URL, httpMethod: String, urlQuery: String? = nil, start: Bool = false, contentType: String? = nil) throws -> URLRequest {
        let filename = fileUrl.lastPathComponent
        var urlHostAllowedPlus = CharacterSet.urlHostAllowed
        urlHostAllowedPlus.remove(charactersIn: "+")
        let encodedPackageName = filename.addingPercentEncoding(withAllowedCharacters: urlHostAllowedPlus) ?? ""

        let bucket          = initiateUploadData.bucketName ?? ""
        let region          = initiateUploadData.region ?? ""
        let key             = (initiateUploadData.path ?? "") + encodedPackageName + (start ? "?uploads" : "")
        let accessKeyId     = initiateUploadData.accessKeyID ?? ""
        let secretAccessKey = initiateUploadData.secretAccessKey ?? ""
        let sessionToken    = initiateUploadData.sessionToken ?? ""
        var urlQueryString  = ""
        if let urlQuery {
            urlQueryString = start ? "&\(urlQuery)" : "?\(urlQuery)"
        }
        let regionString = region == "us-east-1" ? "" : "-\(region)"
        let jcdsServerURL   = URL(string: "https://\(bucket).s3\(regionString).amazonaws.com/\(key)\(urlQueryString)")

        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: currentDate)

        guard let jcdsServerURL else { throw DistributionPointError.badUploadUrl }
        var request = URLRequest(url: jcdsServerURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData)

        request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
        request.addValue("\(bucket).s3.amazonaws.com", forHTTPHeaderField: "Host")
        request.addValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(dateString, forHTTPHeaderField: "x-amz-date")
        request.addValue(sessionToken, forHTTPHeaderField: "x-amz-security-token")
        if let contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        request.httpMethod = httpMethod
        let signatureProvided = "\(awsSignature256(for: sessionToken, httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretKey: secretAccessKey, bucket: bucket, key: key, queryParameters: urlQuery ?? "", region: region, currentDate: "\(currentDate)"))"

        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-security-token,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")

        return request
    }

    func processMultipartUpload(whichChunk: Int, uploadId: String, fileUrl: URL) async throws {
        let minTokenRemainingTime = 5
        var uploadedChunks    = 0
        var remainingParts    = Array(1...totalChunks)
        var failedParts       = [Int]()
        var chunkIndex        = 0

        partNumberEtagList.removeAll()

        while uploadedChunks < totalChunks {
            chunkIndex = remainingParts.removeFirst()
            LogManager.shared.logMessage(message: "Call for part: \(chunkIndex)", level: .debug)

            if let expireEpoch = initiateUploadData.expiration {
                let currentEpoch = Int(Date().timeIntervalSince1970)
                let timeLeft = (expireEpoch - currentEpoch)/60

                LogManager.shared.logMessage(message: "Upload token time remaining: \(timeLeft) minutes", level: .debug)
                if timeLeft < minTokenRemainingTime {
                    try await renewTokenObject.renewUploadToken()
                }
            }

            do {
                try await uploadChunk(whichChunk: chunkIndex, uploadId: uploadId, fileUrl: fileUrl, progress: progress)
                uploadedChunks += 1
                failedParts.removeAll(where: { $0 == chunkIndex })
                LogManager.shared.logMessage(message: "Uploaded chunk \(chunkIndex), \(totalChunks - uploadedChunks) remaining", level: .debug)
            } catch {
                if failedParts.firstIndex(where: { $0 == chunkIndex }) != nil {
                    LogManager.shared.logMessage(message: "Part \(chunkIndex) has previously failed, aborting upload.", level: .debug)
                    throw DistributionPointError.uploadFailure
                } else {
                    remainingParts.append(chunkIndex)
                    failedParts.append(chunkIndex)
                    LogManager.shared.logMessage(message: "**** Failed to upload chunk \(chunkIndex): \(error.localizedDescription)", level: .debug)
                }
            }
        }
    }

    private func uploadChunk(whichChunk: Int, uploadId: String, fileUrl: URL, progress: SynchronizationProgress) async throws {
        LogManager.shared.logMessage(message: "Start processing part \(whichChunk)", level: .debug)

        let chunkData = try getChunkData(fileUrl: fileUrl, part: whichChunk)

        guard chunkData.count > 0 else { return }

        let sessionDelegate = CloudSessionDelegate(progress: progress)
        urlSession = createUrlSession(sessionDelegate: sessionDelegate)
        guard let urlSession else { throw DistributionPointError.programError }

        let request = try createMultipartUploadRequest(fileUrl: fileUrl, httpMethod: "PUT", urlQuery: "partNumber=\(whichChunk)&uploadId=\(uploadId)")

        URLCache.shared.removeAllCachedResponses()
        
        let (responseData, response) = try await urlSession.upload(for: request, from: chunkData)
        if let httpResponse = response as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                LogManager.shared.logMessage(message: "Failed to upload part \(whichChunk) for \(fileUrl). Status code: \(httpResponse.statusCode)", level: .debug)
                let responseDataString = String(data: responseData, encoding: .utf8) ?? ""
                throw ServerCommunicationError.uploadFailed(statusCode: httpResponse.statusCode, message: responseDataString)
            }
            let allHeaders = httpResponse.allHeaderFields
            let etag = allHeaders["Etag"] as? String ?? ""
            LogManager.shared.logMessage(message: "[multipartUpload] partNumber: \(whichChunk) - Etag: \(etag)", level: .debug)
            partNumberEtagList.append(CompletedChunk(partNumber: whichChunk, eTag: etag))
        } else {
            LogManager.shared.logMessage(message: "No response for part \(whichChunk) for \(fileUrl).", level: .debug)
        }
    }

    func completeMultipartUpload(fileUrl: URL, uploadId: String) async throws {
        let completedPartsXml = createCompletedPartsXml()
        let packageToUpload = fileUrl.lastPathComponent

        var request = try createMultipartUploadRequest(fileUrl: fileUrl, httpMethod: "POST", urlQuery: "uploadId=\(uploadId)", contentType: "text/xml")

        let requestData = completedPartsXml.data(using: .utf8)
        request.httpBody = requestData

        URLCache.shared.removeAllCachedResponses()
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
               LogManager.shared.logMessage(message: "Failed to complete upload for \(packageToUpload). Status code: \(httpResponse.statusCode)", level: .error)
                let responseDataString = String(data: responseData, encoding: .utf8) ?? ""
                throw ServerCommunicationError.uploadFailed(statusCode: httpResponse.statusCode, message: responseDataString)
            }
        }

        uploadTime.end = Date().timeIntervalSince1970
        LogManager.shared.logMessage(message: "Finished uploading \(packageToUpload)", level: .info)
        LogManager.shared.logMessage(message: "Upload of \(packageToUpload) completed in \(uploadTime.total())", level: .info)
    }

    private func createCompletedPartsXml() -> String {
        var completionArray = ""
        for thePart in partNumberEtagList.sorted(by: {$0.partNumber < $1.partNumber}) {
            let currentPart = """
                    <Part>
                        <PartNumber>\(thePart.partNumber)</PartNumber>
                        <ETag>\(thePart.eTag)</ETag>
                    </Part>
                
                """
            completionArray.append(currentPart)
        }
        return """
            <CompleteMultipartUpload>
            \(completionArray)</CompleteMultipartUpload>
            """
    }

    private func getChunkData(fileUrl: URL, part: Int) throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: fileUrl)

        fileHandle.seek(toFileOffset: UInt64((part - 1) * chunkSize))
        let data = fileHandle.readData(ofLength: chunkSize)

        try fileHandle.close()

        return data
    }

    private func awsSignature256(for resource: String, httpMethod: String, date: String, accessKeyId: String, secretKey: String, bucket: String, key: String, queryParameters: String = "", region: String/*, fileUrl: URL, contentType: String*/, currentDate: String) -> String {

        var requestHeaders = [String:String]()
        requestHeaders["date"] = currentDate
        requestHeaders["host"] = "\(bucket).s3.amazonaws.com"
        requestHeaders["x-amz-content-sha256"] = "UNSIGNED-PAYLOAD"
        requestHeaders["x-amz-date"] = date
        requestHeaders["x-amz-security-token"] = resource

        var sortedHeaders = ""
        var signedHeaders = ""
        for (key, value) in requestHeaders.sorted(by: { $0.0 < $1.0 }) {
            sortedHeaders.append("\(key.lowercased()):\(value)\n")
            signedHeaders.append("\(key.lowercased());")
        }
        sortedHeaders = String(sortedHeaders.dropLast())
        signedHeaders = String(signedHeaders.dropLast())
        var canonicalURI = key.removingPercentEncoding?.replacingOccurrences(of: "?uploads", with: "")
        var allowedUrlCharacters = CharacterSet() // used to encode AWS URI headers
        allowedUrlCharacters.formUnion(.alphanumerics)
        allowedUrlCharacters.insert(charactersIn: "/-._~")
        canonicalURI = canonicalURI?.addingPercentEncoding(withAllowedCharacters: allowedUrlCharacters) ?? ""

        // CANONICAL REQUEST //
        let canonicalRequest = """
        \(httpMethod.uppercased())
        /\(canonicalURI ?? "")
        \(queryParameters)
        \(sortedHeaders)
        
        \(signedHeaders)
        UNSIGNED-PAYLOAD
        """
        LogManager.shared.logMessage(message: "CanonicalRequest: \(canonicalRequest)", level: .debug)

        let canonicalRequestData = Data(canonicalRequest.utf8)
        let canonicalRequestDataHashed = SHA256.hash(data: canonicalRequestData)
        let canonicalRequestString = canonicalRequestDataHashed.compactMap { String(format: "%02x", $0) }.joined()
        
        let scope = "\(date.prefix(8))/\(region)/s3/aws4_request"
        let stringToSign = """
            AWS4-HMAC-SHA256
            \(date)
            \(scope)
            \(canonicalRequestString)
            """
        LogManager.shared.logMessage(message: "StringToSign: \(stringToSign)", level: .debug)

        let hexOfFinalSignature = hmac_sha256(date: "\(date.prefix(8))", secretKey: secretKey, key: key, region: region, stringToSign: stringToSign)

        return hexOfFinalSignature
    }

    private func contentType(filename: String) -> String? {
        let ext = URL(fileURLWithPath: filename).pathExtension
        switch ext {
        case "pkg", "mpkg":
            return "application/x-newton-compatible-pkg"
        case "dmg":
            return "application/octet-stream"
        case "zip":
            return "application/zip"
        default:
            return nil
        }
    }

    private func hmac_sha256(date: String, secretKey: String, key: String, region: String, stringToSign: String) -> String {
        let aws4SecretKey = Data("AWS4\(secretKey)".utf8)
        let dateStampData = Data(date.utf8)
        let regionNameData = Data(region.utf8)
        let serviceNameData = Data("s3".utf8)
        let aws4_requestData = Data("aws4_request".utf8)
        let stringToSignData = Data(stringToSign.utf8)

        var symmetricKey = SymmetricKey(data: aws4SecretKey)
        let dateKey = HMAC<SHA256>.authenticationCode(for: dateStampData, using: symmetricKey)

        symmetricKey = SymmetricKey(data: Data(dateKey))
        let dateRegionKey = HMAC<SHA256>.authenticationCode(for: regionNameData, using: symmetricKey)

        symmetricKey = SymmetricKey(data: Data(dateRegionKey))
        let dateRegionServiceKey = HMAC<SHA256>.authenticationCode(for: serviceNameData, using: symmetricKey)

        symmetricKey = SymmetricKey(data: Data(dateRegionServiceKey))
        let signingKey = HMAC<SHA256>.authenticationCode(for: aws4_requestData, using: symmetricKey)

        symmetricKey = SymmetricKey(data: Data(signingKey))
        let finalSigningSHA256 = HMAC<SHA256>.authenticationCode(for: stringToSignData, using: symmetricKey)
        let hmac_sha256String = Data(finalSigningSHA256).map { String(format: "%02x", $0) }.joined()

        return hmac_sha256String

    }
}
