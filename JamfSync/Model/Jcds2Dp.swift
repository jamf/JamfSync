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
    
    // for aws uri encoding - BIG-RAT
    var myCharacterSet = CharacterSet()

    init(jamfProInstanceId: UUID? = nil, jamfProInstanceName: String? = nil) {
        super.init(name: "JCDS")
        self.jamfProInstanceId = jamfProInstanceId
        self.jamfProInstanceName = jamfProInstanceName
        self.willDownloadFiles = true
        
        // character set for asw header uri encoding - BIG-RAT
        myCharacterSet.formUnion(.alphanumerics)
        myCharacterSet.insert(charactersIn: "/-._~")
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
                    try fileManager.moveRetainingDestinationPermisssions(at: moveFrom, to: localUrl)
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
        
        
        _ = disableSleep(reason: "start upload")

        if let fileProperties = try? FileManager.default.attributesOfItem(atPath: fileUrl.path(percentEncoded: false)) {
            if let size = fileProperties[FileAttributeKey.size] as? NSNumber {
                let uploadFileSize = size.doubleValue
                Chunk.all = Int(truncating: size)
                Chunk.numberOf = Int(uploadFileSize)/Chunk.size
                if Chunk.all % Chunk.size > 0 {
                    Chunk.numberOf += 1
                }
                LogManager.shared.logMessage(message: "File will be split into \(Chunk.numberOf) parts.", level: .debug)
                if uploadFileSize > 32212255000 {
                    LogManager.shared.logMessage(message: "Maximum upload file size (30GB) exceeded. File size: \(Int(uploadFileSize))", level: .info)
                    return
                }
            }
        } else {
            LogManager.shared.logMessage(message: "A problem occurred trying to access the file: \(fileUrl)", level: .debug)
        }
        
        let uploadId = await createMultipartUpload(fileUrl: fileUrl)
        
            partNumberEtagList.removeAll()
            let result = await multipartUploadController(whichChunk: 1, uploadId: uploadId, fileUrl: fileUrl)
            var completionArray = ""
            if result {
                LogManager.shared.logMessage(message: "All chunks uploaded successfully", level: .debug)
                
                for thePart in partNumberEtagList.sorted(by: {$0.partNumber < $1.partNumber}) {
                    let currentPart = """
                            <Part>
                                <PartNumber>\(thePart.partNumber)</PartNumber>
                                <ETag>\(thePart.eTag)</ETag>
                            </Part>
                        
                        """
                    completionArray.append(currentPart)
                }
                let completionXml = """
                    <CompleteMultipartUpload>
                    \(completionArray)</CompleteMultipartUpload>
                    """
//
                    let responseString = await completeMultipartUpload(fileUrl: fileUrl, completeMultipartUploadXml: completionXml, uploadId: uploadId)
                LogManager.shared.logMessage(message: "Join parts response: \(responseString)", level: .debug)
            } else {
                LogManager.shared.logMessage(message: "Failed to start uploading", level: .debug)
            }
            _ = enableSleep()
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
    
    private func awsSignature256(for resource: String, httpMethod: String, date: String, accessKeyId: String, secretKey: String, bucket: String, key: String, queryParameters: String = "", region: String, fileUrl: URL, hashedPayload: String, contentType: String, currentDate: String) -> String {
        
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
        canonicalURI = canonicalURI?.addingPercentEncoding(withAllowedCharacters: myCharacterSet) ?? ""
        
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
    
    private func createMultipartUpload(fileUrl: URL) async -> String {
        
        let packageToUpload = fileUrl.lastPathComponent
        LogManager.shared.logMessage(message: "Start uploading \(packageToUpload)", level: .info)
        
        var urlHostAllowedPlus = CharacterSet.urlHostAllowed
        urlHostAllowedPlus.remove(charactersIn: "+")
        let encodedPackageName = packageToUpload.addingPercentEncoding(withAllowedCharacters: urlHostAllowedPlus) ?? ""
        
        let bucket          = initiateUploadData?.bucketName ?? ""
        let region          = initiateUploadData?.region ?? ""
        let key             = (initiateUploadData?.path ?? "") + encodedPackageName + "?uploads"
        let accessKeyId     = initiateUploadData?.accessKeyID ?? ""
        let secretAccessKey = initiateUploadData?.secretAccessKey ?? ""
        let sessionToken    = initiateUploadData?.sessionToken ?? ""
        let contentType     = ""
        let jcdsServerURL   = ( region == "us-east-1" ) ? URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!:URL(string: "https://\(bucket).s3-\(region).amazonaws.com/\(key)")!
        
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: currentDate)
        
        var request = URLRequest(url: jcdsServerURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        
        request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
        request.addValue("\(bucket).s3.amazonaws.com", forHTTPHeaderField: "Host")
        request.addValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(dateString, forHTTPHeaderField: "x-amz-date")
        request.addValue(sessionToken, forHTTPHeaderField: "x-amz-security-token")
        
        request.httpMethod = "POST"
        let signatureProvided = "\(awsSignature256(for: sessionToken, httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretKey: secretAccessKey, bucket: bucket, key: key, queryParameters: "uploads=", region: region, fileUrl: fileUrl, hashedPayload: "", contentType: contentType, currentDate: "\(currentDate)"))"
        
        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-security-token,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")
        
        
        URLCache.shared.removeAllCachedResponses()
        
        uploadTime.start = Int(Date().timeIntervalSince1970)
        do {
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
                    LogManager.shared.logMessage(message: "Create multipart error: \(message)", level: .debug)
                } else {
                    LogManager.shared.logMessage(message: "Create multipart response: \(responseString)", level: .debug)
                }
                return("multipart failed")
            }
        } catch {
            return("multipart failed")
        }
    }
    
    private func multipartUploadController(whichChunk: Int, uploadId: String, fileUrl: URL) async -> Bool {
        
        var uploadedChunks   = 0
        var currentSessions  = 1
        var expireEpoch      = initiateUploadData?.expiration ?? 0
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
            
            let result = await multipartUpload(whichChunk: Chunk.index, uploadId: uploadId, fileUrl: fileUrl)
                currentSessions -= 1
                switch result {
                case .success:
                    uploadedChunks += 1
                    failedParts.removeAll(where: { $0 == Chunk.index })
                    LogManager.shared.logMessage(message: "Uploaded chunk \(Chunk.index), \(Chunk.numberOf - uploadedChunks) remaining", level: .debug)
                case .failure(let error):
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
    
    private func multipartUpload(whichChunk: Int, uploadId: String, fileUrl: URL) async -> (Result<Void, Error>) {
        
        LogManager.shared.logMessage(message: "Start processing part \(whichChunk)", level: .debug)
           
        let chunk = getChunk(fileUrl: fileUrl, part: whichChunk)
        
        if chunk.count == 0 {
            return(.success(()))
            
        }
        let partNumber      = whichChunk
        let packageToUpload = fileUrl.lastPathComponent
        
        var urlHostAllowedPlus = CharacterSet.urlHostAllowed
        urlHostAllowedPlus.remove(charactersIn: "+")
        let encodedPackageName = packageToUpload.addingPercentEncoding(withAllowedCharacters: urlHostAllowedPlus) ?? ""
        
        let bucket          = initiateUploadData?.bucketName ?? ""
        let region          = initiateUploadData?.region ?? ""
        let key             = (initiateUploadData?.path ?? "") + encodedPackageName
        let accessKeyId     = initiateUploadData?.accessKeyID ?? ""
        let secretAccessKey = initiateUploadData?.secretAccessKey ?? ""
        let sessionToken    = initiateUploadData?.sessionToken ?? ""
        let jcdsServerURL   = ( region == "us-east-1" ) ? URL(string: "https://\(bucket).s3.amazonaws.com/\(key)?partNumber=\(partNumber)&uploadId=\(uploadId)")!:URL(string: "https://\(bucket).s3-\(region).amazonaws.com/\(key)?partNumber=\(partNumber)&uploadId=\(uploadId)")!
        
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: currentDate)
        
        var urlSession: URLSession = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpShouldSetCookies = true
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.timeoutIntervalForRequest = 3600.0
            configuration.timeoutIntervalForResource = 3600.0
//            configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
            return URLSession(configuration: configuration)
        }()
        
        var request = URLRequest(url: jcdsServerURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 3600)
        
        var hashOfPayload = ""
        var hashedPayload = ""
        
        request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
        request.addValue("\(bucket).s3.amazonaws.com", forHTTPHeaderField: "Host")
        request.addValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(dateString, forHTTPHeaderField: "x-amz-date")
        request.addValue(sessionToken, forHTTPHeaderField: "x-amz-security-token")
        
        request.httpMethod = "PUT"
        
        var signatureProvided = "\(awsSignature256(for: sessionToken, httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretKey: secretAccessKey, bucket: bucket, key: key, queryParameters: "partNumber=\(partNumber)&uploadId=\(uploadId)", region: region, fileUrl: fileUrl, hashedPayload: hashedPayload, contentType: contentType(filename: packageToUpload) ?? "", currentDate: "\(currentDate)"))"
        
        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-security-token,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")
        
        URLCache.shared.removeAllCachedResponses()
        
        do {
            let (responseData, response) = try await urlSession.upload(for: request, from: chunk)
            
            let responseString = String(data: responseData, encoding: .utf8) ?? ""
            
            let httpResponse = response as? HTTPURLResponse
            let allHeaders = httpResponse?.allHeaderFields
            
            print("[multipartUpload] partNumber: \(partNumber) - Etag: \(allHeaders?["Etag"] ?? "")")
            partNumberEtagList.append(CompleteMultipart(partNumber: partNumber, eTag: "\(allHeaders?["Etag"] ?? "")"))

            return(.success(()))
        } catch {
            return(.failure(error))
        }
    }
    
    private func completeMultipartUpload(fileUrl: URL, completeMultipartUploadXml: String, uploadId: String) async -> String {
                
        let packageToUpload = fileUrl.lastPathComponent
        
        var urlHostAllowedPlus = CharacterSet.urlHostAllowed
        urlHostAllowedPlus.remove(charactersIn: "+")
        let encodedPackageName = packageToUpload.addingPercentEncoding(withAllowedCharacters: urlHostAllowedPlus) ?? ""
        
        let bucket          = initiateUploadData?.bucketName ?? ""
        let region          = initiateUploadData?.region ?? ""
        let key             = (initiateUploadData?.path ?? "") + encodedPackageName
        let accessKeyId     = initiateUploadData?.accessKeyID ?? ""
        let secretAccessKey = initiateUploadData?.secretAccessKey ?? ""
        let sessionToken    = initiateUploadData?.sessionToken ?? ""
        var contentType     = ""
        let jcdsServerURL   = ( region == "us-east-1" ) ? URL(string: "https://\(bucket).s3.amazonaws.com/\(key)" + "?uploadId=\(uploadId)")!:URL(string: "https://\(bucket).s3-\(region).amazonaws.com/\(key)" + "?uploadId=\(uploadId)")!
        
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: currentDate)
        
        var request = URLRequest(url: jcdsServerURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        
        
        request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
        request.addValue("text/xml", forHTTPHeaderField: "Content-Type")
        request.addValue("\(bucket).s3.amazonaws.com", forHTTPHeaderField: "Host")
        request.addValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(dateString, forHTTPHeaderField: "x-amz-date")
        request.addValue(sessionToken, forHTTPHeaderField: "x-amz-security-token")
        
        request.httpMethod = "POST"
        let signatureProvided = "\(awsSignature256(for: sessionToken, httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretKey: secretAccessKey, bucket: bucket, key: key, queryParameters: "uploadId=\(uploadId)", region: region, fileUrl: fileUrl, hashedPayload: "", contentType: contentType, currentDate: "\(currentDate)"))"
        
        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-security-token,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")
        
        let requestData = completeMultipartUploadXml.data(using: .utf8)
        request.httpBody = requestData

        URLCache.shared.removeAllCachedResponses()
        
        var responseString = ""
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            responseString = String(data: responseData, encoding: .utf8) ?? ""
        } catch {
            responseString = error.localizedDescription
        }
        uploadTime.end = Int(Date().timeIntervalSince1970)
        LogManager.shared.logMessage(message: "Finished uploading \(packageToUpload)", level: .info)
        LogManager.shared.logMessage(message: "Upload of \(packageToUpload) completed in \(uploadTime.total())", level: .info)
        
        _ = enableSleep()
        return(responseString)
    }
    
    private func getChunk(fileUrl: URL, part: Int) -> Data {
        let fileHandle = try? FileHandle(forReadingFrom: fileUrl)

        fileHandle!.seek(toFileOffset: UInt64((part-1)*Chunk.size))
        let data = fileHandle!.readData(ofLength: Chunk.size)
        
        try? fileHandle?.close()
                         
        return data
    }
    
    private func headersToStrings(headers: [String: String]) {
        Headers.canonical = ""
        Headers.signed    = ""
        for (key, value) in headers.sorted(by: <) {
            Headers.canonical.append("\(key.lowercased()):\(value)\n")
            Headers.signed.append("\(key.lowercased());")
        }
        Headers.canonical = String(Headers.canonical.dropLast())
        Headers.signed    = String(Headers.signed.dropLast())
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
    
    private func headersToStrings(requestHeaders: [String: String]) -> (String, String) {
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
    
    private func hmac_sha256(date: String, secretAccessKey: String, region: String, stringToSign: String) -> String {
       
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
