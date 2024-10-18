//
//  Copyright 2024, Jamf
//

import Foundation

class Jcds2Dp: DistributionPoint, RenewTokenProtocol {
    var dpIndex: Int?
    var initiateUploadData: JsonInitiateUpload?
    let expirationBuffer = 60 // If the uploading will expire in 60 seconds, initiate upload again
    let operationQueue = OperationQueue()
    var urlSession: URLSession?
    var downloadTask: URLSessionDownloadTask?
    var dispatchGroup: DispatchGroup?
    var keepAwake = KeepAwake()
    var multipartUpload: MultipartUpload?

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
        if let moveFrom {
            let tempDirectory = try temporaryFileManager.createTemporaryDirectory(directoryName: "JcdsUploads")
            localUrl = tempDirectory.appendingPathComponent(srcFile.name)
            if let localUrl {
                try fileManager.moveRetainingDestinationPermisssions(at: moveFrom, to: localUrl)
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
        multipartUpload?.cancel()
        multipartUpload = nil
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
            // Need to move this to our own temp directory since otherwise it can get deleted by the system before we're done with it.
            let newLocation = try temporaryFileManager.moveToTemporaryDirectory(src: downloadLocation, dstName: downloadLocation.lastPathComponent)
            return newLocation
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
    
    func renewUploadToken() async throws {
        guard let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId), let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        let initiateUploadUrl = url.appendingPathComponent("/api/v1/jcds/renew-credentials")
        let response = try await jamfProInstance.dataRequest(url: initiateUploadUrl, httpMethod: "POST")
        if let data = response.data {
            let decoder = JSONDecoder()
            let renewedCredentials = try? decoder.decode(JsonInitiateUpload.self, from: data)
            initiateUploadData?.accessKeyID = renewedCredentials?.accessKeyID
            initiateUploadData?.expiration = renewedCredentials?.expiration
            initiateUploadData?.secretAccessKey = renewedCredentials?.secretAccessKey
            initiateUploadData?.sessionToken = renewedCredentials?.sessionToken
        }
    }

    private func uploadToCloud(file: DpFile, moveFrom: URL?, progress: SynchronizationProgress) async throws {
        guard let initiateUploadData else { throw DistributionPointError.failedToInitiateCloudUpload }
        var fileUrl: URL?
        var fileSize: Int64?
        if let moveFrom {
            fileUrl = moveFrom
        } else {
            fileUrl = file.fileUrl
        }

        if let fileUrl, fileSize == nil {
            fileSize = sizeOfFile(fileUrl: fileUrl)
        }

        guard let fileUrl, let fileSize else { throw DistributionPointError.badFileUrl }

        keepAwake.disableSleep(reason: "Starting upload")
        defer { keepAwake.enableSleep() }

        multipartUpload = MultipartUpload(initiateUploadData: initiateUploadData, renewTokenObject: self, progress: progress)
        guard let multipartUpload else { throw DistributionPointError.programError }

        let uploadId = try await multipartUpload.startMultipartUpload(fileUrl: fileUrl, fileSize: fileSize)

        try await multipartUpload.processMultipartUpload(whichChunk: 1, uploadId: uploadId, fileUrl: fileUrl)
        LogManager.shared.logMessage(message: "All chunks uploaded successfully", level: .debug)

        try await multipartUpload.completeMultipartUpload(fileUrl: fileUrl, uploadId: uploadId)
        self.multipartUpload = nil
    }
}
