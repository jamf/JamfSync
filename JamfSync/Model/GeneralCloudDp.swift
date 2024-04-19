//
//  GeneralCloudDp.swift
//

import Foundation

class GeneralCloudDp: DistributionPoint {
    var dpIndex: Int?
    var initiateUploadData: JsonInitiateUpload?
    let expirationBuffer = 60 // If the uploading will expire in 60 seconds, initiate upload again
    let operationQueue = OperationQueue()
    var urlSession: URLSession?
    var downloadTask: URLSessionDownloadTask?
    var dispatchGroup: DispatchGroup?

    init(jamfProInstanceId: UUID? = nil, jamfProInstanceName: String? = nil) {
        super.init(name: "Cloud")
        self.readWrite = .writeOnly
        self.jamfProInstanceId = jamfProInstanceId
        self.jamfProInstanceName = jamfProInstanceName
        self.updatePackageInfoBeforeTransfer = true
    }

    override func retrieveFileList() async throws {
        guard let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId) else { throw ServerCommunicationError.noJamfProUrl }

        // Can't currently read the file list in non JCDS2 cloud instances, so we have to assume that the packages in Jamf Pro are present
        dpFiles.removeAll()
        for package in jamfProInstance.packages {
            dpFiles.files.append(DpFile(name: package.fileName, size: package.size, checksums: package.checksums))
        }

        filesLoaded = true
    }

    override func willDownloadFiles() -> Bool {
        return true
    }

    override func downloadFile(file: DpFile, progress: SynchronizationProgress) async throws -> URL? {
        throw DistributionPointError.downloadingNotSupported
    }

    override func transferFile(srcFile: DpFile, moveFrom: URL? = nil, progress: SynchronizationProgress) async throws {
        guard let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId) else { throw ServerCommunicationError.noJamfProUrl }

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

        // The package should have already been added because updatePackageInfoBeforeTransfer is set to true
        guard let package = jamfProInstance.findPackage(name: srcFile.name), let jamfProId = package.jamfProId else { throw DistributionPointError.uploadFailure }
        guard let fileUrl = localUrl ?? srcFile.fileUrl else { throw DistributionPointError.badFileUrl }

        try await uploadToCloud(packageId: jamfProId, fileUrl: fileUrl, progress: progress, jamfProInstance: jamfProInstance)
    }

    override func deleteFile(file: DpFile, progress: SynchronizationProgress) async throws {
        // The only way to delete files from a general cloud distribution point (non-JCDS2) is to delete the package, which happens after synchronization is completed. So this function will do nothing.
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

    private func uploadToCloud(packageId: Int, fileUrl: URL, progress: SynchronizationProgress, jamfProInstance: JamfProInstance) async throws {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        let boundary = createBoundary()
        let tempFileName = try prepareFileForMultipartUpload(fileUrl: fileUrl, boundary: boundary)
        defer {
            try? FileManager.default.removeItem(at: tempFileName)
        }

        let packageUrl = url.appendingPathComponent("/api/v1/packages/\(packageId)/upload")

        let sessionDelegate = CloudSessionDelegate(progress: progress)
        urlSession = createUrlSession(sessionDelegate: sessionDelegate)
        guard let urlSession else { throw DistributionPointError.programError }

        let request = try createUploadRequest(url: packageUrl, fileUrl: tempFileName, boundary: boundary, jamfProInstance: jamfProInstance)

        let (_, response) = try await urlSession.upload(for: request, fromFile: tempFileName, delegate: sessionDelegate)
        if let httpResponse = response as? HTTPURLResponse {
            switch(httpResponse.statusCode) {
            case 200...299:
                LogManager.shared.logMessage(message: "Successfully uploaded \(fileUrl.lastPathComponent)", level: .verbose)
            default:
                throw ServerCommunicationError.dataRequestFailed(statusCode: httpResponse.statusCode)
            }
        }
    }

    func createBoundary() -> String {
        let alphNumChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let uniqueStr = String((0..<22).map { _ in alphNumChars.randomElement()! })

        return "------------------------\(uniqueStr)"
    }

    private func prepareFileForMultipartUpload(fileUrl: URL, boundary: String) throws -> URL {
        let folder = URL(filePath: NSTemporaryDirectory()).appending(path: "JamfSyncUploads")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let tempFileUrl = folder.appendingPathComponent(fileUrl.lastPathComponent)
        let filename = fileUrl.lastPathComponent

        guard let outputStream = OutputStream(url: tempFileUrl, append: false) else {
            throw ServerCommunicationError.prepareForUploadFailed
        }

        outputStream.open()
        try outputStream.write("--\(boundary)\r\n")
        try outputStream.write("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        try outputStream.write("Content-Type: application/octet-stream\r\n\r\n")
        try outputStream.write(contentsOf: fileUrl)
        try outputStream.write("\r\n")
        try outputStream.write("--\(boundary)--\r\n")
        outputStream.close()

        return tempFileUrl
    }

    private func createUploadRequest(url: URL, fileUrl: URL, boundary: String, jamfProInstance: JamfProInstance) throws -> URLRequest {
        guard let token = jamfProInstance.token else { throw ServerCommunicationError.noToken }
        guard let fileSize = sizeOfFile(fileUrl: fileUrl) else { throw ServerCommunicationError.prepareForUploadFailed }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.allHTTPHeaderFields = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "multipart/form-data; boundary=\(boundary)",
            "Accept": "application/json",
            "Content-Length": "\(fileSize)"
        ]

        return request
    }

    func createUrlSession(sessionDelegate: CloudSessionDelegate) -> URLSession {
        return URLSession(configuration: .default,
                          delegate: sessionDelegate,
                          delegateQueue: operationQueue)
    }
}
