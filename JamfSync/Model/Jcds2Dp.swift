//
//  Copyright 2024, Jamf
//

import Foundation
import CryptoKit

class Jcds2Dp: DistributionPoint {
    var dpIndex: Int?
    var initiateUploadData: JsonInitiateUpload?
    let expirationBuffer = 60 // If the uploading will expire in 60 seconds, initiate upload again
    let operationQueue = OperationQueue()
    var urlSession: URLSession?
    var downloadTask: URLSessionDownloadTask?
    var dispatchGroup: DispatchGroup?

    init(jamfProInstanceId: UUID? = nil, jamfProInstanceName: String? = nil) {
        super.init(name: "JCDS")
        self.jamfProInstanceId = jamfProInstanceId
        self.jamfProInstanceName = jamfProInstanceName
        self.willDownloadFiles = true
    }

    override func retrieveFileList() async throws {
        guard let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId), let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }
        let cloudFilesUrl = url.appendingPathComponent("/api/v1/jcds/files")

        dpFiles.files.removeAll()

        let response = try await jamfProInstance.dataRequest(url: cloudFilesUrl, httpMethod: "GET")
        if let data = response.data {
            let dataString = String(data: data, encoding: .utf8)
            let decoder = JSONDecoder()
            var cloudFiles: [JsonCloudFile]?
            do {
                cloudFiles = try decoder.decode([JsonCloudFile].self, from: data)
            } catch {
                LogManager.shared.logMessage(message: "Failed to parse cloud files from \(selectionName()). \(error) \(dataString ?? "nil")", level: .verbose)
                throw ServerCommunicationError.parsingError
            }
            if let cloudFiles {
                for cloudFile in cloudFiles {
                    guard let filename = cloudFile.fileName else {
                        LogManager.shared.logMessage(message: "Missing name for cloud file for Jamf Pro instance: \(jamfProInstanceName ?? "")", level: .error)
                        continue
                    }
                    let checksums = Checksums()
                    if let sha3 = cloudFile.sha3 {
                        checksums.updateChecksum(Checksum(type: .SHA3_512, value: sha3))
                    }
                    if let md5 = cloudFile.md5 {
                        checksums.updateChecksum(Checksum(type: .MD5, value: md5))
                    }
                    let dpFile = DpFile(name: filename, size: cloudFile.length ?? 0, checksums: checksums)

                    dpFiles.files.append(dpFile)
                }
            }
        }

        filesLoaded = true
    }

    override func downloadFile(file: DpFile, progress: SynchronizationProgress) async throws -> URL? {
        guard let cloudUri = try await retrieveCloudDownloadUri(file: file, progress: progress) else { throw DistributionPointError.failedToRetrieveCloudDownloadUri }

        return try downloadFromUri(file: file, uri: cloudUri, progress: progress)
    }

    override func transferFile(srcFile: DpFile, moveFrom: URL? = nil, progress: SynchronizationProgress) async throws {
        var localUrl = moveFrom
        var tempDirectory: URL?
        if let moveFrom {
            tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("JamfSync")
            if let tempDirectory {
                try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: false)
                localUrl = tempDirectory.appendingPathComponent(srcFile.name)
                if let localUrl {
                    try fileManager.moveItem(at: moveFrom, to: localUrl)
                }
            }
        }

        defer {
            if let localUrl {
                do {
                    try fileManager.removeItem(at: localUrl)
                } catch {
                    LogManager.shared.logMessage(message: "Failed to remove temporary download file \(localUrl): \(error)", level: .warning)
                }
            }
            if let tempDirectory {
                do {
                    try fileManager.removeItem(at: tempDirectory)
                } catch {
                    LogManager.shared.logMessage(message: "Failed to remove temporary directory \(tempDirectory): \(error)", level: .warning)
                }
            }
        }

        try await initiateUpload()
        try await uploadToCloud(file: srcFile, moveFrom: localUrl, progress: progress)
    }

    override func deleteFile(file: DpFile, progress: SynchronizationProgress) async throws {
        guard let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId), let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }
        let fileName = fileNameFromDpFile(file)
        let cloudFileUrl = url.appendingPathComponent("/api/v1/jcds/files/\(fileName)")

        let _ = try await jamfProInstance.dataRequest(url: cloudFileUrl, httpMethod: "DELETE")
    }

    override func cancel() {
        super.cancel()
        downloadTask?.cancel()
        downloadTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        dispatchGroup?.leave()
    }

    // MARK: - Private functions

    private func supportsJcds2() async throws -> Bool {
        guard let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId), let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        // Try to get the information for a non-existent file. If it returns a 500, then JCDS2 is not supported. If it returns 404, then it's good.
        let cloudFileUrl = url.appendingPathComponent("/api/v1/jcds/files/nonexistentfile")

        let response = try await jamfProInstance.dataRequest(url: cloudFileUrl, httpMethod: "GET", throwHttpError: false)
        if let httpResponse = response.response as? HTTPURLResponse {
            return httpResponse.statusCode != 500
        }
        return false
    }

    private func retrieveCloudDownloadUri(file: DpFile, progress: SynchronizationProgress) async throws -> URL? {
        guard let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId), let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }
        let fileName = fileNameFromDpFile(file)
        let cloudFileUrl = url.appendingPathComponent("/api/v1/jcds/files/\(fileName)")

        let response = try await jamfProInstance.dataRequest(url: cloudFileUrl, httpMethod: "GET")
        if let data = response.data {
            let decoder = JSONDecoder()
            if let cloudFileDownload = try? decoder.decode(JsonCloudFileDownload.self, from: data), let uri = cloudFileDownload.uri {
                return URL(string: uri)
            }
        }
        return nil
    }

    private func fileNameFromDpFile(_ dpFile: DpFile) -> String {
        guard let fileUrl = dpFile.fileUrl else { return dpFile.name }
        return fileUrl.lastPathComponent
    }

    private func downloadFromUri(file: DpFile, uri: URL, progress: SynchronizationProgress) /*async*/ throws -> URL {
        dispatchGroup = DispatchGroup()
        guard let dispatchGroup else { throw DistributionPointError.programError }
        dispatchGroup.enter()

        let sessionDelegate = CloudSessionDelegate(progress: progress, dispatchGroup: dispatchGroup)
        urlSession = createUrlSession(sessionDelegate: sessionDelegate)

        downloadTask = urlSession?.downloadTask(with: uri)
        downloadTask?.resume()

        dispatchGroup.wait()
        self.dispatchGroup = nil

        if let downloadLocation = sessionDelegate.downloadLocation {
            return downloadLocation
        }

        throw DistributionPointError.downloadFromCloudFailed
    }

    func createUrlSession(sessionDelegate: CloudSessionDelegate) -> URLSession {
        return URLSession(configuration: .default,
                          delegate: sessionDelegate,
                          delegateQueue: operationQueue)
    }

    private func initiateUpload() async throws {
        guard let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId), let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        let initiateUploadUrl = url.appendingPathComponent("/api/v1/jcds/files")
        let response = try await jamfProInstance.dataRequest(url: initiateUploadUrl, httpMethod: "POST")
        if let data = response.data {
            let decoder = JSONDecoder()
            self.initiateUploadData = try? decoder.decode(JsonInitiateUpload.self, from: data)
        }
    }

    private func uploadToCloud(file: DpFile, moveFrom: URL?, progress: SynchronizationProgress) async throws {
        guard let initiateUploadData, let bucketName = initiateUploadData.bucketName else { throw DistributionPointError.failedToInitiateCloudUpload }
        var fileUrl: URL?
        if let moveFrom {
            fileUrl = moveFrom
        } else {
            fileUrl = file.fileUrl
        }
        guard let fileUrl else { throw DistributionPointError.badFileUrl }

        let encodedPackageName = file.name.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved) ?? ""
        let key = (initiateUploadData.path ?? "") + encodedPackageName
        guard let jcdsServerUrl = URL(string: "https://\(bucketName).s3.amazonaws.com/\(key)") else { throw DistributionPointError.badUploadUrl }
        guard let contentType = contentType(filename: file.name) else { throw DistributionPointError.invalidFileType }

        let sessionDelegate = CloudSessionDelegate(progress: progress)
        urlSession = createUrlSession(sessionDelegate: sessionDelegate)
        guard let urlSession else { throw DistributionPointError.programError }
        
        let currentDate = Date()
        let requestTimeStamp = timeStamp(date: currentDate)

        let request = try createAwsUploadRequest(uploadData: initiateUploadData, jcdsServerUrl: jcdsServerUrl, key: key, contentType: contentType, currentDate: "\(currentDate)", requestTimeStamp: requestTimeStamp)
            
        let (responseData, response) = try await urlSession.upload(for: request, fromFile: fileUrl, delegate: sessionDelegate)
        if let httpResponse = response as? HTTPURLResponse {
            LogManager.shared.logMessage(message: "Upload returned \(String(data: responseData, encoding: .utf8) ?? "")", level: .debug)
            switch(httpResponse.statusCode) {
            case 200...299:
                LogManager.shared.logMessage(message: "Successfully uploaded \(file.name)", level: .verbose)
            default:
                let message = parseErrorData(data: responseData)
                throw ServerCommunicationError.dataRequestFailed(statusCode: httpResponse.statusCode, message: message)
            }
        }
    }

    private func parseErrorData(data: Data) -> String? {
        var message: String?
        let xmlParser = XMLParser(data: data)
        let xmlErrorParser = XmlErrorParser()
        xmlParser.delegate = xmlErrorParser
        xmlParser.parse()
        if xmlParser.parserError == nil {
            message = "\(xmlErrorParser.code ?? ""): \(xmlErrorParser.message ?? "") - max allowed size = \(xmlErrorParser.maxAllowedSize ?? "")"
        }
        return message
    }

    private func createAwsUploadRequest(uploadData: JsonInitiateUpload, jcdsServerUrl: URL, key: String, contentType: String, currentDate: String, requestTimeStamp: String) throws -> URLRequest {
        
        var request = URLRequest(url: jcdsServerUrl, cachePolicy: .reloadIgnoringLocalCacheData)
        
        guard let securityToken = uploadData.sessionToken, let accessKeyID = uploadData.accessKeyID, let bucketName = uploadData.bucketName, let region = uploadData.region else {
            throw DistributionPointError.createAwsUploadRequestFailed
        }
        
        request.httpMethod = "PUT"
        request.addValue(currentDate, forHTTPHeaderField: "date")
        request.addValue("\(bucketName).s3.amazonaws.com", forHTTPHeaderField: "host")
        request.addValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(requestTimeStamp, forHTTPHeaderField: "x-amz-date")
        request.addValue(securityToken, forHTTPHeaderField: "x-amz-security-token")
        
        let (signedHeaders, signatureProvided) = try awsSignatureV4(uploadData: uploadData, httpMethod: "PUT", requestHeaders: request.allHTTPHeaderFields ?? [:], date: requestTimeStamp, key: key, hashedPayload: "", contentType: contentType, currentDate: currentDate)
        
        request.addValue("AWS4-HMAC-SHA256 Credential=\(String(describing: accessKeyID))/\(requestTimeStamp.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=\(signedHeaders),Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")

        request.timeoutInterval = JamfProInstance.uploadTimeoutValue

        return request
    }
    
    private func awsSignatureV4(uploadData: JsonInitiateUpload, httpMethod: String, requestHeaders: [String: String], date: String, key: String, hashedPayload: String, contentType: String, currentDate: String) throws -> (String, String) {
        
        guard let secretAccessKey = uploadData.secretAccessKey, let region = uploadData.region else {
            throw DistributionPointError.awsSignatureFailed
        }
        
        var allowedUrlCharacters = CharacterSet() // used to encode AWS URI headers
        allowedUrlCharacters.formUnion(.alphanumerics)
        allowedUrlCharacters.insert(charactersIn: "/-._~")
        
        let (sortedHeaders, signedHeaders) = headersToStrings(requestHeaders: requestHeaders)

        var canonicalUri = key.removingPercentEncoding
        canonicalUri = canonicalUri?.addingPercentEncoding(withAllowedCharacters: allowedUrlCharacters) ?? ""

        let canonicalRequest = """
        \(httpMethod.uppercased())
        /\(canonicalUri ?? "")
        
        \(sortedHeaders)
        
        \(signedHeaders)
        \(requestHeaders["x-amz-content-sha256"] ?? "UNSIGNED-PAYLOAD")
        """
        
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
                
        let hexOfFinalSignature = hmac_sha256(date: "\(date.prefix(8))", secretAccessKey: secretAccessKey, region: region, stringToSign: stringToSign)
        
        return (signedHeaders, hexOfFinalSignature)
    }
    
    func headersToStrings(requestHeaders: [String: String]) -> (String, String) {
        var sortedHeaders = ""
        var signedHeaders = ""
        for (key, value) in requestHeaders.sorted(by: { $0.0 < $1.0 }) {
            sortedHeaders.append("\(key.lowercased()):\(value)\n")
            signedHeaders.append("\(key.lowercased());")
        }
        sortedHeaders = String(sortedHeaders.dropLast())
        signedHeaders = String(signedHeaders.dropLast())
        return (sortedHeaders, signedHeaders)
    }
    
    func hmac_sha256(date: String, secretAccessKey: String, region: String, stringToSign: String) -> String {
       
        let aws4SecretKey = Data("AWS4\(secretAccessKey)".utf8)
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

    private func timeStamp(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        return dateFormatter.string(from: date)
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
}
