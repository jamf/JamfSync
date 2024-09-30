//
//  Copyright 2024, Jamf
//

import Foundation
import CryptoKit

class MultipartUpload {
    var initiateUploadData: JsonInitiateUpload
    var uploadTime: UploadTime = UploadTime(start: 0, end: 0)

    init(initiateUploadData: JsonInitiateUpload) {
        self.initiateUploadData = initiateUploadData
    }

    func startMultipartUpload(fileUrl: URL) async throws -> String {
        let filename = fileUrl.lastPathComponent
        LogManager.shared.logMessage(message: "Starting upload of \(filename)", level: .debug)

        let request = try createMultipartUploadRequest(fileUrl: fileUrl, urlQuery: "", httpMethod: "POST")

        URLCache.shared.removeAllCachedResponses()

        uploadTime.start = Int(Date().timeIntervalSince1970)
        let (responseData, response) = try await URLSession.shared.data(for: request)
        let responseString = String(data: responseData, encoding: .utf8) ?? ""
        LogManager.shared.logMessage(message: "Create multipart upload response: \(responseString)", level: .debug)

        let uploadId = tagValue(xmlString: responseString, startTag: "<UploadId>", endTag: "</UploadId>", includeTags: false)
        if uploadId != "" {
           return(uploadId)
        } else {
            if let messageRange = responseString.range(of: "<Message>(.*?)</Message>", options: .regularExpression) {
                var message = responseString[messageRange]
                message = "\(message.replacingOccurrences(of: "<Message>", with: "").replacingOccurrences(of: "</Message>", with: ""))"
                LogManager.shared.logMessage(message: "Error occurred when starting the multipart upload: \(message)", level: .error)
            } else {
                LogManager.shared.logMessage(message: "Error occurred when starting the multipart upload: \(responseString)", level: .error)
            }
            throw DistributionPointError.uploadFailure
        }
    }

    private func createMultipartUploadRequest(fileUrl: URL, urlQuery: String, httpMethod: String) throws -> URLRequest {
        let filename = fileUrl.lastPathComponent
        var urlHostAllowedPlus = CharacterSet.urlHostAllowed
        urlHostAllowedPlus.remove(charactersIn: "+")
        let encodedPackageName = filename.addingPercentEncoding(withAllowedCharacters: urlHostAllowedPlus) ?? ""

        let bucket          = initiateUploadData.bucketName ?? ""
        let region          = initiateUploadData.region ?? ""
        let key             = (initiateUploadData.path ?? "") + encodedPackageName + "?uploads"
        let accessKeyId     = initiateUploadData.accessKeyID ?? ""
        let secretAccessKey = initiateUploadData.secretAccessKey ?? ""
        let sessionToken    = initiateUploadData.sessionToken ?? ""
        let contentType     = ""
        let jcdsServerURL   = ( region == "us-east-1" ) ? URL(string: "https://\(bucket).s3.amazonaws.com/\(key)\(urlQuery)"):URL(string: "https://\(bucket).s3-\(region).amazonaws.com/\(key)\(urlQuery)")

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

        request.httpMethod = httpMethod
        let signatureProvided = "\(awsSignature256(for: sessionToken, httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretKey: secretAccessKey, bucket: bucket, key: key, queryParameters: "uploads=", region: region, fileUrl: fileUrl, contentType: contentType, currentDate: "\(currentDate)"))"

        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-security-token,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")

        return request
    }

    func processMultipartUpload(whichChunk: Int, uploadId: String, fileUrl: URL) async throws -> Bool {
        var uploadedChunks   = 0
        var currentSessions  = 1
        let expireEpoch      = initiateUploadData.expiration ?? 0
        var remainingParts   = Array(1...Chunk.numberOf)
        var failedParts      = [Int]()
        var keepLooping      = true
        var successfullUpload = false
        Chunk.index          = 0

        while keepLooping {
            Chunk.index = remainingParts.removeFirst()
            LogManager.shared.logMessage(message: "Call for part: \(Chunk.index)", level: .debug)

            let currentEpoch = Int(Date().timeIntervalSince1970)
            let timeLeft = (expireEpoch - currentEpoch)/60

            LogManager.shared.logMessage(message: "Upload token time remaining: \(timeLeft) minutes", level: .debug)
            if timeLeft < 5 {
                // place holder for renew upload token
                // await something something...
                // update initiateUploadData if need be
            }
            currentSessions += 1
            print("[multipartUploadController] call for part: \(Chunk.index)")

            do {
                try await uploadChunk(whichChunk: Chunk.index, uploadId: uploadId, fileUrl: fileUrl)
                currentSessions -= 1
                uploadedChunks += 1
                failedParts.removeAll(where: { $0 == Chunk.index })
                LogManager.shared.logMessage(message: "Uploaded chunk \(Chunk.index), \(Chunk.numberOf - uploadedChunks) remaining", level: .debug)
            } catch {
                if (failedParts.firstIndex(where: { $0 == Chunk.index }) != nil) {
                    LogManager.shared.logMessage(message: "Part \(Chunk.index) has previously failed, aborting upload.", level: .debug)
                    keepLooping = false
                } else {
                    remainingParts.append(Chunk.index)
                    failedParts.append(Chunk.index)
                    LogManager.shared.logMessage(message: "**** Failed to upload chunk \(Chunk.index): \(error.localizedDescription)", level: .debug)
                }
            }
            if uploadedChunks == Chunk.numberOf {
                successfullUpload = true
                keepLooping = false
            }
        }
        return(successfullUpload)
    }

    private func uploadChunk(whichChunk: Int, uploadId: String, fileUrl: URL) async throws {
        LogManager.shared.logMessage(message: "Start processing part \(whichChunk)", level: .debug)

        let chunk = try getChunk(fileUrl: fileUrl, part: whichChunk)

        guard chunk.count > 0 else { return }

        let request = try createMultipartUploadRequest(fileUrl: fileUrl, urlQuery: "?partNumber=\(whichChunk)&uploadId=\(uploadId)", httpMethod: "PUT")

        let urlSession: URLSession = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpShouldSetCookies = true
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.timeoutIntervalForRequest = 3600.0
            configuration.timeoutIntervalForResource = 3600.0
//            configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
            return URLSession(configuration: configuration)
        }()

        URLCache.shared.removeAllCachedResponses()

        let (responseData, response) = try await urlSession.upload(for: request, from: chunk)

        let responseString = String(data: responseData, encoding: .utf8) ?? ""

        let httpResponse = response as? HTTPURLResponse
        let allHeaders = httpResponse?.allHeaderFields

        print("[multipartUpload] partNumber: \(whichChunk) - Etag: \(allHeaders?["Etag"] ?? "")")
        partNumberEtagList.append(CompleteMultipart(partNumber: whichChunk, eTag: "\(allHeaders?["Etag"] ?? "")"))
    }

    func completeMultipartUpload(fileUrl: URL, completeMultipartUploadXml: String, uploadId: String) async throws -> String {

        let packageToUpload = fileUrl.lastPathComponent

        var request = try createMultipartUploadRequest(fileUrl: fileUrl, urlQuery: "&uploadId=\(uploadId)", httpMethod: "PUT")

        let requestData = completeMultipartUploadXml.data(using: .utf8)
        request.httpBody = requestData

        URLCache.shared.removeAllCachedResponses()

        var responseString = ""
        let (responseData, response) = try await URLSession.shared.data(for: request)
        responseString = String(data: responseData, encoding: .utf8) ?? ""
        uploadTime.end = Int(Date().timeIntervalSince1970)
        LogManager.shared.logMessage(message: "Finished uploading \(packageToUpload)", level: .info)
        LogManager.shared.logMessage(message: "Upload of \(packageToUpload) completed in \(uploadTime.total())", level: .info)

//        keepAwake.enableSleep()
        return(responseString)
    }

    private func getChunk(fileUrl: URL, part: Int) throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: fileUrl)

        fileHandle.seek(toFileOffset: UInt64((part - 1) * Chunk.size))
        let data = fileHandle.readData(ofLength: Chunk.size)

        try fileHandle.close()

        return data
    }

    private func awsSignature256(for resource: String, httpMethod: String, date: String, accessKeyId: String, secretKey: String, bucket: String, key: String, queryParameters: String = "", region: String, fileUrl: URL, contentType: String, currentDate: String) -> String {

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
//        print("[awsSignature256] ")

        let canonicalRequestData = Data(canonicalRequest.utf8)
        let canonicalRequestDataHashed = SHA256.hash(data: canonicalRequestData)
        let canonicalRequestString = canonicalRequestDataHashed.compactMap { String(format: "%02x", $0) }.joined()

        let scope = "\(date.prefix(8))/\(region)/s3/aws4_request"
        // STRING TO SIGN
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
