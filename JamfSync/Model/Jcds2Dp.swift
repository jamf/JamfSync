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
        // check filesize and set up chuck info
        if let fileProperties = try? FileManager.default.attributesOfItem(atPath: fileUrl.path(percentEncoded: false)) {
            if let size = fileProperties[FileAttributeKey.size] as? NSNumber {
                let uploadFileSize = size.doubleValue
                Chunk.all = Int(truncating: size)
                Chunk.numberOf = Int(uploadFileSize)/Chunk.size
                if Chunk.all % Chunk.size > 0 {
                    Chunk.numberOf += 1
                }
                print("chunks: \(Chunk.numberOf)")
                if uploadFileSize > 32212255000 {
                    //WriteToLog.shared.message(stringOfText: "[uploadPackages] ***** maximum upload file size (30GB) exceeded. File size: \(Int(uploadFileSize)) *****")
                    return
                    //print("update upload counter \(#line)")
                }
            }
        } else {
            //WriteToLog.shared.message(stringOfText: "[uploadPackages] a problem occurred trying to access the file: \(fileUrl)")
        }
        
//        ThePayload.hash = try! Payload.shared.fileSha256(forFile: fileUrl)
        let uploadId = await createMultipartUpload(fileUrl: fileUrl)
            
//        createMultipartUpload(fileUrl: fileUrl) {
//            (result: String) in
//                       print("[createMultipartUpload] result: \(result)")
//            let uploadId = result
            print("[createMultipartUpload] UploadId: \(uploadId)")
//                        _ = enableSleep()
            partNumberEtagList.removeAll()
            let result = await multipartUploadController(whichChunk: 1, uploadId: uploadId, fileUrl: fileUrl)
//            multipartUploadController(whichChunk: 1, uploadId: uploadId, fileUrl: fileUrl) {
//                result in
                var completionArray = ""
                if result {
                    print("All chunks uploaded successfully")
                    
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
                    print("[chunkUploads] completionXml: \n\(completionXml)")
                    
                    
//                                var s3Info = [String: Any]()
//                                TokenDelegate.shared.getToken(whichServer: "source", base64creds: JamfProServer.base64Creds["source"] ?? "") {
//                                    authResult in
//                                    let (statusCode,theResult) = authResult
////                                    print("[multipartUploadController] refresh getToken result: \(authResult)")
//
//                                    if theResult == "success" {
//                    JcdsApi.shared.action(packageURL: fileUrl.path(percentEncoded: false), packageName: fileUrl.lastPathComponent, method: "POST") { [self]
//                                (result: Any) in
//                                print("[multipartUploadController] uploadInfo: \(result)")
//                                            s3Info = result as! [String : Any]
//                                            let newToken = s3Info["sessionToken"] as? String ?? ""
//                                            print("[multipartUploadController] newToken: \(newToken)")
////                                            s3Info = result as? [String: Any] ?? [:]
//                                            var newUploadInfo = uploadInfo
//                                            newUploadInfo.updateValue(newToken, forKey: "sessionToken")
//                                            print("[completeMultipartUpload] UploadId: \(uploadId)")
                                let responseString = await completeMultipartUpload(fileUrl: fileUrl, completeMultipartUploadXml: completionXml, uploadId: uploadId)
//                                completeMultipartUpload(fileUrl: fileUrl, completeMultipartUploadXml: completionXml, uploadId: uploadId) {
//                                    (result: String) in
                                    print("[JcdsApi.shared.completeMultipartUpload] result: \(responseString)")
//                                }
                                
//                            }
//                                    } else {
//
//                                    }
//                                }
                    
                } else {
                    print("Failed to upload data")
                }
                _ = enableSleep()
//            }
//        }
        
        /*
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
        */
    }
    
    private func splitFile(fileUrl: URL) -> Bool {
        // writes parts to files
        print("split file")
        let data = FileManager.default.contents(atPath: fileUrl.path(percentEncoded: false)) ?? Data()
        var startIndex = 0
        var part       = 1
        let totalSize = data.count

        var url: URL?
        while startIndex < totalSize {
            print("[chunkData] startIndex: \(startIndex)")
            let endIndex = min(startIndex + Chunk.size, totalSize)
            let chunk = data.subdata(in: startIndex..<endIndex)
            
            let filename = fileUrl.lastPathComponent
            url = URL(filePath: "/tmp/\(filename).part\(part)")
            
            do {
                try chunk.write(to: url!, options: [.atomic, .completeFileProtection])
            } catch {
                print(error.localizedDescription)
                return false
            }
            part+=1
            
            print("chunk \((startIndex/Chunk.size)+1) size: \(chunk.count)")
            startIndex += Chunk.size
                
        }
        return true
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
        
//        print("[awsSignature] hmac_sha256String: \(hmac_sha256String)")
        
        return hmac_sha256String
        
    }
    
    private func awsSignature256(for resource: String, httpMethod: String, date: String, accessKeyId: String, secretKey: String, bucket: String, key: String, queryParameters: String = "", region: String, fileUrl: URL, hashedPayload: String, contentType: String, currentDate: String) -> String {
        
        var requestHeaders = [String:String]()
//        requestHeaders["content-type"] = "\(contentType)"
        requestHeaders["date"] = currentDate
        requestHeaders["host"] = "\(bucket).s3.amazonaws.com"
//        if !hashedPayload.isEmpty {
            requestHeaders["x-amz-content-sha256"] = "UNSIGNED-PAYLOAD"
//        }
//        requestHeaders["x-amz-content-sha256"] = hashedPayload
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
        print("[awsSignature256] canonicalURI: \(canonicalURI)")
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
        print("[awsSignature256] canonicalRequest \n\(canonicalRequest)")
        
//        let data = canonicalRequest.data(using: String.Encoding.utf8)!
//            let length = Int(CC_SHA256_DIGEST_LENGTH)
//            var digest = [UInt8](repeating: 0, count: length)
//            data.withUnsafeBytes {
//                _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
//            }
//        let canonicalRequestStringCC = digest.compactMap { String(format: "%02x", $0) }.joined()
        let canonicalRequestData = Data(canonicalRequest.utf8)
        let canonicalRequestDataHashed = SHA256.hash(data: canonicalRequestData)
        let canonicalRequestString = canonicalRequestDataHashed.compactMap { String(format: "%02x", $0) }.joined()
        
        print("[awsSignature256]   canonicalRequestString: \(canonicalRequestString)")
        
        let scope = "\(date.prefix(8))/\(region)/s3/aws4_request"
        // STRING TO SIGN
        let stringToSign = """
            AWS4-HMAC-SHA256
            \(date)
            \(scope)
            \(canonicalRequestString)
            """

        print("\n[awsSignature] stringToSign: \(stringToSign)\n")
        
        let hexOfFinalSignature = hmac_sha256(date: "\(date.prefix(8))", secretKey: secretKey, key: key, region: region, stringToSign: stringToSign)
        
        return hexOfFinalSignature
//        return finalSignature
    }
    
    private func createMultipartUpload(fileUrl: URL) async -> String {
        
        if !splitFile(fileUrl: fileUrl) {
            return("multipart failed")
        }
        let packageToUpload = fileUrl.lastPathComponent
        
        var urlHostAllowedPlus = CharacterSet.urlHostAllowed
        urlHostAllowedPlus.remove(charactersIn: "+")
        let encodedPackageName = packageToUpload.addingPercentEncoding(withAllowedCharacters: urlHostAllowedPlus) ?? ""
        
        let bucket          = initiateUploadData?.bucketName ?? ""
        let region          = initiateUploadData?.region ?? ""
        let key             = (initiateUploadData?.path ?? "") + encodedPackageName + "?uploads"
        let accessKeyId     = initiateUploadData?.accessKeyID ?? ""
        let secretAccessKey = initiateUploadData?.secretAccessKey ?? ""
        let sessionToken    = initiateUploadData?.sessionToken ?? ""
        var contentType     = ""
        var jcdsServerURL   = URL(string: "")
        
        print("bucket: \(bucket)")
        print("region: \(region)")
        print("key: \(key)")
        print("accessKeyId: \(accessKeyId)")
        print("secretAccessKey: \(secretAccessKey)")
        print("sessionToken: \(sessionToken)")
        
        //                print("[uploadPackages] S3 url: https://\(bucket).s3.amazonaws.com/\(key)")
        jcdsServerURL = ( region == "us-east-1" ) ? URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!:URL(string: "https://\(bucket).s3-\(region).amazonaws.com/\(key)")!
        
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: currentDate)
        
//        let session: URLSession = URLSession(configuration: .default,
//                                             delegate: self,
//                                             delegateQueue: theUploadQ)
        var request = URLRequest(url: jcdsServerURL!,
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        
        request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
        //                request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        request.addValue("\(bucket).s3.amazonaws.com", forHTTPHeaderField: "Host")
        //                request.addValue(hashedPayload, forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(dateString, forHTTPHeaderField: "x-amz-date")
        request.addValue(sessionToken, forHTTPHeaderField: "x-amz-security-token")
        
        request.httpMethod = "POST"
        var signatureProvided = ""
//        if JamfProServer.dpType["destination"] == "S3" {
//            signatureProvided = "\(AmazonS3.shared.awsSignatureV4(securityToken: "", httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucket, scope: "", region: region, key: key, hashedPayload: "", contentType: contentType, currentDate: "\(currentDate)"))"
//        } else {
            signatureProvided = "\(awsSignature256(for: sessionToken, httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretKey: secretAccessKey, bucket: bucket, key: key, queryParameters: "uploads=", region: region, fileUrl: fileUrl, hashedPayload: "", contentType: contentType, currentDate: "\(currentDate)"))"
//        }
        
        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-security-token,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")
        
        
        // start upload process
        URLCache.shared.removeAllCachedResponses()
        
        ////WriteToLog.shared.message(stringOfText: "[uploadPackages] Perform upload task for \(fileUrl.lastPathComponent)")

        uploadTime.start = Int(Date().timeIntervalSince1970)
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let responseString = String(data: responseData, encoding: .utf8) ?? ""
            print("[createMultipartUpload] upload response: \(responseString)")
            
            let uploadId = tagValue(xmlString: responseString, startTag: "<UploadId>", endTag: "</UploadId>", includeTags: false)
            if uploadId != "" {
               return(uploadId)
            } else {
//                DispatchQueue.main.async{
                    //WriteToLog.shared.message(stringOfText: "[createMultipartUpload] S3 response: \(responseData)")
                    if let messageRange = responseString.range(of: "<Message>(.*?)</Message>", options: .regularExpression) {
                        var message = responseString[messageRange]
                        message = "\(message.replacingOccurrences(of: "<Message>", with: "").replacingOccurrences(of: "</Message>", with: ""))"
                        //_ = Alert.shared.display(header: "", message: String(message), secondButton: "")
                    } else {
                        //_ = Alert.shared.display(header: "", message: responseData, secondButton: "")
                    }
                    return("multipart failed")
                    //print("update upload counter \(#line)")
//                }
            }
        } catch {
            return("multipart failed")
        }
        /*
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("[createMultipartUpload] Error: \(error)")
                let errorFailingURLStringKey = tagValue(xmlString: "\(error)", startTag: "NSErrorFailingURLStringKey=", endTag: ", ", includeTags: false)
                //                        let errorFailingURLStringKey = error.localizedDescription
                let failedPackage = URL(string: errorFailingURLStringKey)?.lastPathComponent
                
                //            print("URLSessionTask description: \(String(describing: failedPackage!))")
                //WriteToLog.shared.message(stringOfText: "[createMultipartUpload] \(errorFailingURLStringKey)")
                //WriteToLog.shared.message(stringOfText: "[createMultipartUpload] Failed to upload: \(String(describing: failedPackage!))")
                //print("update upload counter \(#line)")
            } else if let data = data {
                let responseData = String(data: data, encoding: .utf8) ?? ""
                print("[createMultipartUpload] upload response: \(responseData)")
                
                let uploadId = tagValue(xmlString: responseData, startTag: "<UploadId>", endTag: "</UploadId>", includeTags: false)
                if uploadId != "" {
                   return(uploadId)
                } else {
                    DispatchQueue.main.async{
                        //WriteToLog.shared.message(stringOfText: "[createMultipartUpload] S3 response: \(responseData)")
                        if let messageRange = responseData.range(of: "<Message>(.*?)</Message>", options: .regularExpression) {
                            var message = responseData[messageRange]
                            message = "\(message.replacingOccurrences(of: "<Message>", with: "").replacingOccurrences(of: "</Message>", with: ""))"
                            _ = Alert.shared.display(header: "", message: String(message), secondButton: "")
                        } else {
                            _ = Alert.shared.display(header: "", message: responseData, secondButton: "")
                        }
                        return("multipart failed")
                        //print("update upload counter \(#line)")
                    }
                }
               
            }
        }
        task.resume()
        */
    }
    
    private func multipartUploadController(whichChunk: Int, uploadId: String, fileUrl: URL) async -> Bool {
        
        var uploadedChunks = 0
        var failedChunks   = 0
        var currentSessions = 1

        var uploading = false
        
//        let uploadGroup = DispatchGroup()
//        while (uploadedChunks+failedChunks) < Chunk.numberOf {
        while true {
//        while Chunk.index <= Chunk.numberOf {
            // allow up to 3 concurrent uploads
            if currentSessions < 4 && Chunk.index <= Chunk.numberOf {
//                uploading = true
                
                let currentEpoch = Int(Date().timeIntervalSince1970)
                let expireEpoch = initiateUploadData?.expiration ?? 0 //s3Info["expiration"] as? Int ?? 0
                let timeLeft = (expireEpoch - currentEpoch)/60
                //*
                print("[multipartUploadController] timeLeft: \(timeLeft) minutes")
                if timeLeft < 5 {
                    // renew upload token
                    currentSessions += 1
//                    TokenDelegate.shared.getToken(whichServer: "source", base64creds: JamfProServer.base64Creds["source"] ?? "") { [self]
//                        authResult in
//                        let (statusCode,theResult) = authResult
                        let theResult = "success"
//                        print("[multipartUploadController] refresh getToken result: \(authResult)")
                        
                        if theResult == "success" {
//                            JcdsApi.shared.action(packageURL: fileUrl.path(percentEncoded: false), packageName: "", method: "POST", renew: true) { [self]
//                                (result: Any) in
//                                print("[multipartUploadController] uploadInfo: \(result)")
//                                renew(uploadInfo: result as! [String : Any])
//                                s3Info = result as? [String: Any] ?? [:]
//                                s3Info = uploadInfo
                                
//                                currentSessions += 1
                                print("[multipartUploadController] call for part: \(Chunk.index)")
                                
                            let result = await multipartUpload(whichChunk: Chunk.index, uploadId: uploadId, chunk2: Data(), fileUrl: fileUrl)
//                                multipartUpload(whichChunk: Chunk.index, uploadId: uploadId, chunk2: Data(), fileUrl: fileUrl) {
//                                    result in
                                    currentSessions -= 1
                                    switch result {
                                    case .success:
                                        uploadedChunks += 1
                                        print("Uploaded chunk \(uploadedChunks) of \(Chunk.numberOf)")
                                    case .failure(let error):
                                        failedChunks += 1
                                        print("Failed to upload chunk: \(error.localizedDescription)")
                                    }
                                    if uploadedChunks+failedChunks == Chunk.numberOf {
                                        if failedChunks == 0 {
                                            return(true)
                                        } else {
                                            print("\(failedChunks) parts failed to upload")
                                            return(false)
                                        }
                                    }
                                    uploading = false
//                                }
                                
                                print("[multipartUploadController] increase index to: \(Chunk.index+1)")
                                Chunk.index += 1
//                            }
                        } else {
                            
                        }
//                    }
                } else {
                    
                    currentSessions += 1
                    print("[multipartUploadController] call for part: \(Chunk.index)")
                    
                    let result = await multipartUpload(whichChunk: Chunk.index, uploadId: uploadId, chunk2: Data(), fileUrl: fileUrl)
//                    multipartUpload(whichChunk: Chunk.index, uploadId: uploadId, chunk2: Data(), fileUrl: fileUrl) {
//                        result in
                        currentSessions -= 1
                        switch result {
                        case .success:
                            uploadedChunks += 1
                            print("Uploaded chunk \(uploadedChunks) of \(Chunk.numberOf)")
                        case .failure(let error):
                            failedChunks += 1
                            print("Failed to upload chunk: \(error.localizedDescription)")
                        }
                        if uploadedChunks+failedChunks == Chunk.numberOf {
                            if failedChunks == 0 {
                                return(true)
                            } else {
                                print("\(failedChunks) parts failed to upload")
                                return(false)
                            }
                        }
                        uploading = false
//                    }
                    
                    print("[multipartUploadController] increase index to: \(Chunk.index+1)")
                    Chunk.index += 1
                    
                }
                
                
            } else {
                sleep(1)
            }
        }   // while - end
    }
    
    //  async -> String
    private func multipartUpload(whichChunk: Int, uploadId: String, chunk2: Data, fileUrl: URL) async -> (Result<Void, Error>) {
//    func multipartUpload(whichChunk: Int, uploadId: String, chunk2: Data, fileUrl: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        print("[multipartUpload] whichChunk: \(whichChunk)")
           
        
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
        var contentType     = ""
        var jcdsServerURL   = URL(string: "")
        
        //                print("[uploadPackages] S3 url: https://\(bucket).s3.amazonaws.com/\(key)")
        jcdsServerURL = ( region == "us-east-1" ) ? URL(string: "https://\(bucket).s3.amazonaws.com/\(key)?partNumber=\(partNumber)&uploadId=\(uploadId)")!:URL(string: "https://\(bucket).s3-\(region).amazonaws.com/\(key)?partNumber=\(partNumber)&uploadId=\(uploadId)")!
        
        let fileType = fileUrl.pathExtension
        switch fileType {
        case "pkg":
            //WriteToLog.shared.message(stringOfText: "[uploadPackages] Content-Type: application/x-newton-compatible-pkg")
            contentType = "application/x-newton-compatible-pkg"
        case "dmg":
            //WriteToLog.shared.message(stringOfText: "[uploadPackages] Content-Type: application/octet-stream")
            contentType = "application/octet-stream"
        case "zip":
            //WriteToLog.shared.message(stringOfText: "[uploadPackages] Content-Type: application/zip")
            contentType = "application/zip"     // or application/x-zip-compressed?
        default:
            //WriteToLog.shared.message(stringOfText: "[uploadPackages] Content-Type: unsupported (\(fileType))")
            contentType = ""
        }
        
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
        
//        let session: URLSession = URLSession(configuration: urlSession.configuration,
//                                             delegate: self,
//                                             delegateQueue: theUploadQ)
        var request = URLRequest(url: jcdsServerURL!,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 3600)
        
        var hashOfPayload = ""
        var hashedPayload = ""
//        do {
//            hashOfPayload = try fileSha256(forFile: fileUrl)
//        } catch {
//            print("\n[uploadPackages] hashOfPayload: failed")
////            completion("[uploadPackages] hashOfPayload: failed")
//            return
//        }
        
        request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
        //                request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        request.addValue("\(bucket).s3.amazonaws.com", forHTTPHeaderField: "Host")
        //                request.addValue(hashedPayload, forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(dateString, forHTTPHeaderField: "x-amz-date")
        request.addValue(sessionToken, forHTTPHeaderField: "x-amz-security-token")
        
        request.httpMethod = "PUT"
        
        var signatureProvided = "\(awsSignature256(for: sessionToken, httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretKey: secretAccessKey, bucket: bucket, key: key, queryParameters: "partNumber=\(partNumber)&uploadId=\(uploadId)", region: region, fileUrl: fileUrl, hashedPayload: hashedPayload, contentType: contentType, currentDate: "\(currentDate)"))"
        
        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-security-token,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")
        
        //                request.httpMethod = "POST"   // will cause errors - <Message>The specified method is not allowed against this resource.</Message><Method>POST</Method>
//                    print("[uploadPackages] all headers \(request.allHTTPHeaderFields ?? [:])")
        
        // start upload process
        URLCache.shared.removeAllCachedResponses()
        
        //WriteToLog.shared.message(stringOfText: "[multipartUpload] Perform upload task for \(fileUrl.lastPathComponent)")
//        uploadStartTime = Date()
        do {
            let (responseData, response) = try await URLSession.shared.upload(for: request, from: chunk)
//            let (responseData, response) = try await URLSession.shared.data(for: request)
            let responseString = String(data: responseData, encoding: .utf8) ?? ""
            
            let httpResponse = response as? HTTPURLResponse
            let allHeaders = httpResponse?.allHeaderFields
            
            print("[multipartUpload] partNumber: \(partNumber) - Etag: \(allHeaders?["Etag"] ?? "")")
            partNumberEtagList.append(CompleteMultipart(partNumber: partNumber, eTag: "\(allHeaders?["Etag"] ?? "")"))

            return(.success(()))
        } catch {
            return(.failure(error))
        }
        
        /*
        let task = session.uploadTask(with: request, from: chunk) { data, response, error in
//        let task = session.dataTask(with: request) { data, response, error in
            session.finishTasksAndInvalidate()


            let httpResponse = response as? HTTPURLResponse
            let allHeaders = httpResponse?.allHeaderFields 
            
            print("[multipartUpload] partNumber: \(partNumber) - Etag: \(allHeaders?["Etag"] ?? "")")
            partNumberEtagList.append(CompleteMultipart(partNumber: partNumber, eTag: "\(allHeaders?["Etag"] ?? "")"))

            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
        task.resume()
         */
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
        var jcdsServerURL   = URL(string: "")
        
        jcdsServerURL = ( region == "us-east-1" ) ? URL(string: "https://\(bucket).s3.amazonaws.com/\(key)" + "?uploadId=\(uploadId)")!:URL(string: "https://\(bucket).s3-\(region).amazonaws.com/\(key)" + "?uploadId=\(uploadId)")!
        
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: currentDate)
        
//        let session: URLSession = URLSession(configuration: .default,
//                                             delegate: self,
//                                             delegateQueue: theUploadQ)
        var request = URLRequest(url: jcdsServerURL!,
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        
        
        request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
        request.addValue("text/xml", forHTTPHeaderField: "Content-Type")
        request.addValue("\(bucket).s3.amazonaws.com", forHTTPHeaderField: "Host")
        //                request.addValue(hashedPayload, forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(dateString, forHTTPHeaderField: "x-amz-date")
        request.addValue(sessionToken, forHTTPHeaderField: "x-amz-security-token")
        
        request.httpMethod = "POST"
        var signatureProvided = ""
//        if JamfProServer.dpType["destination"] == "S3" {
//            signatureProvided = "\(AmazonS3.shared.awsSignatureV4(securityToken: "", httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucket, scope: "", region: region, key: key, hashedPayload: "", contentType: contentType, currentDate: "\(currentDate)"))"
//        } else {
            signatureProvided = "\(awsSignature256(for: sessionToken, httpMethod: request.httpMethod!, date: dateString, accessKeyId: accessKeyId, secretKey: secretAccessKey, bucket: bucket, key: key, queryParameters: "uploadId=\(uploadId)", region: region, fileUrl: fileUrl, hashedPayload: "", contentType: contentType, currentDate: "\(currentDate)"))"
//        }
        
        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-security-token,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")
        
        //                request.httpMethod = "POST"   // will cause errors - <Message>The specified method is not allowed against this resource.</Message><Method>POST</Method>
//                    print("[uploadPackages] all headers \(request.allHTTPHeaderFields ?? [:])")
        
        let requestData = completeMultipartUploadXml.data(using: .utf8)
        request.httpBody = requestData
        // start upload process
        URLCache.shared.removeAllCachedResponses()
        
        //WriteToLog.shared.message(stringOfText: "[completeMultipartUpload] Perform task for \(fileUrl.lastPathComponent)")
        
        do {
//            let (responseData, response) = try await URLSession.shared.upload(for: request, from: chunk)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let responseString = String(data: responseData, encoding: .utf8) ?? ""
            
//                print("[completeMultipartUpload] upload response: \(responseString)")
                  return(responseString)
        } catch {
            return(error.localizedDescription)
        }
        
        
        /*
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("[completeMultipartUpload] Error: \(error)")
                completion(error.localizedDescription)
                
            } else if let data = data {
                let responseData = String(data: data, encoding: .utf8) ?? ""
                print("[completeMultipartUpload] upload response: \(responseData)")
                
                    completion(responseData)
            }
            uploadTime.end = Int(Date().timeIntervalSince1970)
            print("upload completed in \(uploadTime.end - uploadTime.start) seconds")
            
            _ = enableSleep()
        }
        task.resume()
         */

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
