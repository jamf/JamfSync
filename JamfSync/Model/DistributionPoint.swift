//
//  Copyright 2024, Jamf
//

import Foundation
import Subprocess

enum DistributionPointError: Error {
    case programError // Shouldn't normally be possible unless there is an erroneous change
    case failed
    case badFileUrl
    case badUploadUrl
    case badDownloadUrl
    case cannotGetFileList
    case tempDirectoryNotCreated
    case failedToInitiateCloudUpload
    case failedToRetrieveCloudDownloadUri
    case downloadFromCloudFailed
    case invalidFileType
    case couldNotCreateTemporaryDirectory
    case awsSignatureFailed
    case createAwsUploadRequestFailed
    case failedToCreateZipFile
    case downloadingNotSupported
    case uploadingNotSupported
    case uploadFailure
    case maxUploadSizeExceeded
}

enum ReadWriteCapable {
    case readWrite
    case readOnly
    case writeOnly

    func readSupported() -> Bool {
        return self == .readWrite || self == .readOnly
    }

    func writeSupported() -> Bool {
        return self == .readWrite || self == .writeOnly
    }
}

class DistributionPoint: Identifiable {
    /// The unique id of the distribution point.
    var id = UUID()

    /// The name of the distribution point. If this is associated with a Jamf Pro instance, the name is provided by Jamf Pro.
    /// If it's a folder distribution point,  that is provided by the user when the distribution point is set up.
    var name: String

    /// The unique id of the jamf pro instance that is associated with this distribution point. It may be nil if it's not associated with a Jamf Pro instance.
    var jamfProInstanceId: UUID?

    /// The name of the jamf pro instance that is associated with this distribution point. It may be nil if it's not associated with a Jamf Pro instance.
    var jamfProInstanceName: String?

    /// Indicates whether the files on the distribution point have been loaded yet.
    var filesLoaded = false

    /// The files associated with the distribution point. If the filesLoaded flag is false, then they have not have been loaded yet.
    var dpFiles = DpFiles()

    /// The FileManager instance to use. This may be set to a mock class for testing
    var fileManager = FileManager.default

    /// Indicates whether any ongoing syncrhonization needs to stop ASAP.
    var isCanceled = false

    /// The destination distribution point that is currently being synchronized. It should be set to nil when synchronization is not in progress.
    var inProgressDstDp: DistributionPoint?

    /// Whether the distribution point is read only, write only, or read write
    var readWrite: ReadWriteCapable = .readWrite

    /// Indicates if the package information needs to be updated before transferring the package
    var updatePackageInfoBeforeTransfer = false

    /// If files were zipped, this will be true, indicating that we need to refresh the file list
    var filesWereZipped = false

    /// Inidates whether the distribution point will download files before transferring them. This should be overridden by any distribution points that require downloading first.
    var willDownloadFiles = false

    /// Indicates if a file will be deleted by removing it from the corresponding package from the Jamf Pro server
    var deleteByRemovingPackage = false

    /// Initialize the class.
    ///
    /// - Parameters:
    ///     - name: The name of the distribution point
    ///     - id: The id of the distribution point. This defaults to nil for when it should just create a unique id.
    ///     - fileManager: The FileManager instance to use. This defaults to nil when the default instance should be used.
    init(name: String, id: UUID? = nil, fileManager: FileManager? = nil) {
        self.name = name
        if let id {
            self.id = id
        }
        if let fileManager {
            self.fileManager = fileManager
        }
    }

    // MARK: Functions that may be overridden by each type of distribution point

    /// Whether or not to show the calculate checksum button. This should be overridden by distribution points where the checksums can be calculated.
    func showCalcChecksumsButton() -> Bool {
        return false
    }

    /// Prepares the distribution point for use, such as when a file share needs to be mounted.
    /// If this is not overridden by a specific distrubtion point, then this does nothing.
    func prepareDp() async throws {
    }

    /// Cleans up after the distribution point, such as when a file share needs to be unmounted.
    /// If this is not overridden by a specific distrubtion point, then this does nothing.
    func cleanupDp() async throws {
    }

    /// Retrieves a list of files that are associated with the distribution point. The dpFiles
    /// Each type of distribution point must override this and provide its own implementation.
    func retrieveFileList() async throws {
        // This function must be overridden by a child class
        throw DistributionPointError.programError
    }

    /// Returns whether the user needs to be prompted for the password in order to use this distribution point.
    /// If this is not overridden by a specific distrubtion point, then it returns false
    /// - Returns: Returns true if it needs to prompt the user for a password, otherwise false.
    func needsToPromptForPassword() -> Bool {
        return false
    }

    /// Cancels the synchronization.
    /// This may be overridden by a child class if it needs to do anything else while cancelling.
    func cancel() {
        isCanceled = true
        inProgressDstDp?.cancel()
        if let jamfProInstanceId, let jamfProInstance = findJamfProInstance(id: jamfProInstanceId) {
            jamfProInstance.cancel()
        }
    }

    /// Downloads a file so it can be used.
    /// This needs to be overridden by a child distribution point class if downloading is necessary in order for it to be available locally. Otherwise this function can be ignored.
    /// - Parameters:
    ///     - file: The file that needs to be downloaded.
    ///     - progress: The progress object that should be updated with the download progress.
    /// - Returns: Returns the local path where the file was downloaded to.
    func downloadFile(file: DpFile, progress: SynchronizationProgress) async throws -> URL? {
        return nil
    }

    /// Transfers a file to this distribution point.
    /// This function must be overridden by a child distribution point class.
    /// - Parameters:
    ///     - srcFile: The source file that should be transferred to this distribution point.
    ///     - moveFrom: The URL of the file that is to be moved to this distribution point. It should be nil if the source file needs to exist in its current location after it is transferred. If it is not nil and the file is not actually moved, then it should be deleted after the transfer is successfully completed.
    ///     - progress: The progress object that should be updated with the transfer progress.
    func transferFile(srcFile: DpFile, moveFrom: URL? = nil, progress: SynchronizationProgress) async throws {
        // This function must be overridden by a child class.
        throw DistributionPointError.programError
    }

    /// Deletes a file from this distribution point.
    /// This function must be overridden by a child distribution point class.
    /// - Parameters:
    ///     - file: The file to remove
    ///     - progress: The progress object that should be updated with the deletion progress.
    func deleteFile(file: DpFile, progress: SynchronizationProgress) async throws {
        // This function must be overridden by a child class.
        throw DistributionPointError.programError
    }

    // MARK: Functions that are common to all distribution points

    /// The name to use in the selection list
    func selectionName() -> String {
        if id == DataModel.noSelection {
            return name
        } else {
            return "\(name) (\(jamfProInstanceName != nil ? "\(jamfProInstanceName ?? "")" : "local"))"
        }
    }

    /// Loops through the files to synchronize to calculate the total size of files to be transferred.
    /// - Parameters:
    ///     - filesToSync: The list of files that are to be synchronized.
    /// - Returns: The total size of all files to be synchronized.
    func calculateTotalTransferSize(filesToSync: [DpFile]) -> Int64 {
        var total: Int64 = 0
        for file in filesToSync {
            total += file.size ?? 0
        }
        return total
    }

    /// Copies files from this distribution point to another distribution point.
    /// - Parameters:
    ///     - selectedItems: The selected items to synchronize. If the selection list is empty, it will synchronize all files from the source distribution point.
    ///     - dstDp: The destination distribution point to copy the files to.
    ///     - jamfProInstance: The Jamf Pro instance of the destination distribution point, if it is associated with one
    ///     - forceSync: Set to true if it should copy files even if they are the same on both the source and destination
    ///     - progress: The progress object that should be updated as the synchronization progresses.
    func copyFiles(selectedItems: [DpFile], dstDp: DistributionPoint, jamfProInstance: JamfProInstance?, forceSync: Bool, progress: SynchronizationProgress) async throws {
        let filesToSync = filesToSynchronize(selectedItems: selectedItems, dstDp: dstDp, forceSync: forceSync)
        try await copyFilesToDst(sourceName: selectionName(), willDownloadFiles: willDownloadFiles, filesToSync: filesToSync, dstDp: dstDp, jamfProInstance: jamfProInstance, forceSync: forceSync, progress: progress)
    }

    /// Transfers a list of local files to this distribution point.
    /// - Parameters:
    ///     - fileUrls: The local file URLs for the files to transfer
    ///     - jamfProInstance: The Jamf Pro instance of this distribution point, if it is associated with one
    ///     - progress: The progress object that should be updated as the transfer progresses
    /// - Returns: Returns true if all files were copied, otherwise false
    func transferLocalFiles(fileUrls: [URL], jamfProInstance: JamfProInstance?, progress: SynchronizationProgress) async throws {
        let dpFiles = convertFileUrlsToDpFiles(fileUrls: fileUrls)
        try await copyFilesToDst(sourceName: "Selected local files", willDownloadFiles: false, filesToSync: dpFiles, dstDp: self, jamfProInstance: jamfProInstance, forceSync: true, progress: progress)
    }

    /// Removes files from this destination distribution point that are not on thie source distribution point.
    /// - Parameters:
    ///     - srcDp: The destination distribution point to search and delete files that are missing.
    ///     - progress: The progress object that should be updated as the deletion progresses.
    func deleteFilesNotOnSource(srcDp: DistributionPoint, progress: SynchronizationProgress) async throws {
        let filesToRemove = filesToRemove(srcDp: srcDp)
        for file in filesToRemove {
            LogManager.shared.logMessage(message: "Deleting \(file.name) from \(selectionName())", level: .verbose)
            try await deleteFile(file: file, progress: progress)
            dpFiles.files.removeAll(where: { $0.name == file.name } ) // Update the list of files so it accurately reflects the change
        }
    }

    // MARK: Convenience functions for use with the child distribution points

    /// Convenience function for distribution points to use when retrieving files from a local directory.
    /// - Parameters:
    ///     - localPath: The path to the local directory containing the files for the distribution point.
    ///     - limitFileTypes: Indicates whether the files should be limited to just valid distribution point files (pkg, dmg, zip)
    func retrieveLocalFileList(localPath: String, limitFileTypes: Bool = true) async throws {
        let directoryContents = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: localPath), includingPropertiesForKeys: nil
        )

        dpFiles.files.removeAll()
        for url in directoryContents {
            if !limitFileTypes || isAcceptableForDp(url: url) {
                let dpFile = DpFile(name: url.lastPathComponent, fileUrl: url, size: sizeOfFile(fileUrl: url))
                dpFiles.files.append(dpFile)
            }
        }

        filesLoaded = true
    }

    /// Convenience function for distribution points that need to transfer the file to a local directory.
    /// - Parameters:
    ///     - localPath: The local path that the file should be transfered to.
    ///     - srcFile: The source file to transfer.
    ///     - moveFrom: The URL of the file that is to be moved to this distribution point, or nil if the file does not need to be moved.
    ///     - progress: The progress object that should be updated with the transfer progress.
    func transferLocal(localPath: String, srcFile: DpFile, moveFrom: URL? = nil, progress: SynchronizationProgress) async throws {
        guard let srcUrl = moveFrom == nil ? srcFile.fileUrl : moveFrom else { throw DistributionPointError.badFileUrl }
        let filename = srcFile.fileUrl == nil ? srcFile.name : srcUrl.lastPathComponent
        let dstUrl = URL(fileURLWithPath: localPath).appendingPathComponent(filename)
        try? fileManager.removeItem(at: dstUrl)
        if let moveFrom {
            try fileManager.moveRetainingDestinationPermisssions(at: moveFrom, to: dstUrl)
        } else {
            try fileManager.copyItem(at: srcUrl, to: dstUrl)
        }
        progress.updateFileTransferInfo(totalBytesTransferred: srcFile.size ?? 0, bytesTransferred: srcFile.size ?? 0)
    }

    /// Convenience function for distribution points that need to delete a local file.
    /// - Parameters:
    ///     - localUrl: The local URL for the file that should be deleted.
    ///     - progress: The progress object that should be updated with the transfer progress.
    func deleteLocal(localUrl: URL, progress: SynchronizationProgress) throws {
        // This should be extremely quick so probably not worth updating progress
        try fileManager.removeItem(at: localUrl)
    }

    /// Gets the size of a local file.
    /// - Parameters:
    ///     - fileUrl: The URL of the file to get the size of.
    /// - Returns: Returns the size of the file.
    func sizeOfFile(fileUrl: URL) -> Int64? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: fileUrl.path) else {
            return nil
        }

        guard !fileUrl.isDirectory else { return nil }

        return attrs[.size] as? Int64
    }

    /// Retrieves the jamf pro instance by id. This is primarily so that unit tests can get a mock Jamf Pro instance.
    ///  - Parameters:
    ///     - id: The id of the Jamf Pro instance
    /// - Returns: Returns a JamfProInstance.
    func findJamfProInstance(id: UUID) -> JamfProInstance? {
        return DataModel.shared.findJamfProInstance(id: id)
    }

    /// Returns a list of files that are on this distribution point but are not on the source distribution point.
    ///  - Parameters:
    ///     - srcDp: The source distribution point to check for missing files.
    ///   - Returns: Returns a list of files that are on this distribution point but not on the source distribution point.
    func filesToRemove(srcDp: DistributionPoint) -> [DpFile] {
        return dpFiles.files.filter { return srcDp.dpFiles.findDpFile(name: $0.name) == nil }
    }

    // MARK: - Private functions

    private func copyFilesToDst(sourceName: String, willDownloadFiles: Bool, filesToSync: [DpFile], dstDp: DistributionPoint, jamfProInstance: JamfProInstance?, forceSync: Bool, progress: SynchronizationProgress) async throws {
        isCanceled = false
        filesWereZipped = false
        var someFileSucceeded = false
        var someFilesFailed = false
        var downloadMultiple: Int64 = 1
        if willDownloadFiles {
            downloadMultiple = 2
        }
        progress.totalSize = calculateTotalTransferSize(filesToSync: filesToSync) * downloadMultiple
        var currentTotalSizeTransferred: Int64 = 0
        var lastFile: DpFile?
        var lastFileTansferred = false
        inProgressDstDp = dstDp
        for dpFile in filesToSync {
            lastFile = dpFile
            progress.initializeFileTransferInfoForFile(operation: "Copying", currentFile: dpFile, currentTotalSizeTransferred: currentTotalSizeTransferred)

            do {
                lastFileTansferred = false
                var localFileUrl: URL?
                if isCanceled { break }
                if willDownloadFiles {
                    Task { @MainActor in
                        progress.operation = "Downloading"
                    }
                    localFileUrl = try await downloadFile(file: dpFile, progress: progress)
                    Task { @MainActor in
                        progress.operation = "Uploading"
                    }
                    if isCanceled { break }
                } else {
                    if let url = dpFile.fileUrl, isFluffy(url: url) {
                        dpFile.fileUrl = try await zipFile(url: url)
                        if let name = dpFile.fileUrl?.lastPathComponent {
                            dpFile.name = name
                            if let zipUrl = dpFile.fileUrl, let zipSize = sizeOfFile(fileUrl: zipUrl) {
                                dpFile.size = zipSize
                            }
                        }
                        filesWereZipped = true
                    }
                }

                if dstDp.updatePackageInfoBeforeTransfer {
                    try await addOrUpdatePackageInJamfPro(dpFile: dpFile, jamfProInstance: jamfProInstance)
                }

                try await dstDp.transferFile(srcFile: dpFile, moveFrom: localFileUrl, progress: progress)
                lastFileTansferred = true

                if let size = dpFile.size {
                    currentTotalSizeTransferred += size * downloadMultiple
                }
                someFileSucceeded = true

                addOrUpdateInDstList(dpFile: dpFile, dstDp: dstDp)
                if !dstDp.updatePackageInfoBeforeTransfer {
                    try await addOrUpdatePackageInJamfPro(dpFile: dpFile, jamfProInstance: jamfProInstance)
                }
            } catch {
                if isCanceled { break }
                LogManager.shared.logMessage(message: "Failed to copy \(dpFile.name) to \(dstDp.selectionName()): \(error)", level: .error)
                someFilesFailed = true
            }
            if isCanceled { break }
        }
        if let lastFile, lastFileTansferred {
            progress.finalProgressValues(totalBytesTransferred: lastFile.size ?? 0, currentTotalSizeTransferred: currentTotalSizeTransferred)
        }
        inProgressDstDp = nil
        if someFilesFailed {
            if someFileSucceeded {
                LogManager.shared.logMessage(message: "Not all files were transferred from \(sourceName) to \(dstDp.selectionName())", level: .warning)
            } else {
                LogManager.shared.logMessage(message: "No files were transferred from \(sourceName) to \(dstDp.selectionName())", level: .error)
            }
        } else {
            if isCanceled {
                LogManager.shared.logMessage(message: "Canceled synchronizing from \(sourceName) to \(dstDp.selectionName())", level: .warning)
            } else {
                LogManager.shared.logMessage(message: "Finished synchronizing from \(sourceName) to \(dstDp.selectionName())", level: .info)
            }
        }
    }

    func convertFileUrlsToDpFiles(fileUrls: [URL]) -> [DpFile] {
        var dpFiles: [DpFile] = []
        for fileUrl in fileUrls {
            let dpFile = DpFile(name: fileUrl.lastPathComponent, fileUrl: fileUrl, size: sizeOfFile(fileUrl: fileUrl))
            dpFiles.append(dpFile)
        }
        return dpFiles
    }

    private func isAcceptableForDp(url: URL) -> Bool {
        guard url.pathExtension != "dmg" else { return true } // Include .dmg files
        guard !url.lastPathComponent.hasSuffix(".pkg.zip") && !url.lastPathComponent.hasSuffix(".mpkg.zip") else { return true } // Include zip files that have ".pkg.zip" or ".mpkg.zip"
        guard url.pathExtension == "pkg" || url.pathExtension == "mpkg" else { return false } // Exclude if not ".pkg" or ".mpkg"
        guard isFluffy(url: url) else { return true } // Include flat .pkg files (not directories)
        let urlForZipFile = url.appendingPathExtension("zip")
        guard !fileManager.fileExists(atPath: urlForZipFile.path) else { return false } // Exclude fluffy package files that have a corresponding zip file
        return true // Include when it's a fluffy package without a corresponding zip file
    }

    private func isFluffy(url: URL) -> Bool {
        var isDir : ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory:&isDir) == true else { return false }
        return isDir.boolValue
    }

    private func filesToSynchronize(selectedItems: [DpFile], dstDp: DistributionPoint, forceSync: Bool) -> [DpFile] {
        let filesToSync: [DpFile]
        if selectedItems.count == 0 {
            filesToSync = filesToSynchronizeAll(dstDp: dstDp, forceSync: forceSync)
        } else {
            filesToSync = filesToSynchronizeSelected(selectedItems: selectedItems, dstDp: dstDp, forceSync: forceSync)
        }
        return filesToSync
   }

    private func filesToSynchronizeAll(dstDp: DistributionPoint, forceSync: Bool) -> [DpFile] {
        if forceSync {
            return dpFiles.files
        } else {
            return dpFiles.files.filter { file in
                if let dstFile = dstDp.dpFiles.findDpFile(name: file.name) {
                    if file == dstFile {
                        LogManager.shared.logMessage(message: "Skipping file \(file.name) because the source and destination match", level: .verbose)
                        return false
                    }
                }
                return true
            }
        }
    }

    private func filesToSynchronizeSelected(selectedItems: [DpFile], dstDp: DistributionPoint, forceSync: Bool) -> [DpFile] {
        var filesToSync: [DpFile] = []
        for file in selectedItems {
            if let dstFile = dstDp.dpFiles.findDpFile(name: file.name) {
                if forceSync || !(file == dstFile) {
                    filesToSync.append(file)
                } else {
                    LogManager.shared.logMessage(message: "Skipping file \(file.name) because the source and destination match", level: .verbose)
                }
            } else {
                filesToSync.append(file)
            }
        }
        return filesToSync
    }

    private func addOrUpdateInDstList(dpFile: DpFile, dstDp: DistributionPoint) {
        if dstDp.dpFiles.files.contains(where: { $0.name == dpFile.name }) {
            dstDp.dpFiles.files.removeAll(where: { $0.name == dpFile.name })
        }
        dstDp.dpFiles.files.append(dpFile)
    }

    private func addOrUpdatePackageInJamfPro(dpFile: DpFile, jamfProInstance: JamfProInstance?) async throws {
        guard let jamfProInstance else { return }
        let checksum = try await retrieveFileChecksum(dpFile: dpFile)
        if let package = jamfProInstance.findPackage(name: dpFile.name) {
            try await updatePackage(package: package, dpFile: dpFile, jamfProInstance: jamfProInstance)
        } else {
            if let checksum {
                dpFile.checksums.updateChecksum(checksum)
            }
            try await addPackage(dpFile: dpFile, jamfProInstance: jamfProInstance)
        }
    }

    private func updatePackage(package: Package, dpFile: DpFile, jamfProInstance: JamfProInstance) async throws {
        var packageVar = package
        packageVar.checksums = dpFile.checksums
        packageVar.size = dpFile.size
        do {
            try await jamfProInstance.updatePackage(package: packageVar)
        } catch {
            LogManager.shared.logMessage(message: "Failed to update package \(packageVar.fileName): \(error)", level: .error)
            throw error
        }
    }

    private func addPackage(dpFile: DpFile, jamfProInstance: JamfProInstance) async throws {
        do {
            try await jamfProInstance.addPackage(dpFile: dpFile)
        } catch let ServerCommunicationError.dataRequestFailed(statusCode, message) {
            // There is some condition that happens rarely where Jamf Pro will report back that it's trying to add a package that already exists. This will try to reload packages and update the package if found.
            try await duplicateFieldRemediation(dpFile: dpFile, jamfProInstance: jamfProInstance, statusCode: statusCode, message: message)
        }
    }

    private func duplicateFieldRemediation(dpFile: DpFile, jamfProInstance: JamfProInstance, statusCode: Int, message: String?) async throws {
        if statusCode == 400, let message, message.contains("DUPLICATE_FIELD") {
            LogManager.shared.logMessage(message: "Failed to add package \(dpFile.name), reloading packages and trying to update instead.", level: .warning)
            try await jamfProInstance.loadPackages()
            if let package = jamfProInstance.findPackage(name: dpFile.name) {
                try await updatePackage(package: package, dpFile: dpFile, jamfProInstance: jamfProInstance)
                LogManager.shared.logMessage(message: "Updating package \(dpFile.name) was successful.", level: .info)
            } else {
                LogManager.shared.logMessage(message: "Package \(dpFile.name) was not found after reloading packages.", level: .error)
            }
        } else {
            throw ServerCommunicationError.dataRequestFailed(statusCode: statusCode, message: message)
        }
    }

    private func retrieveFileChecksum(dpFile: DpFile) async throws -> Checksum? {
        var checksum: Checksum?
        if let sha512 = dpFile.checksums.findChecksum(type: .SHA_512) {
            checksum = sha512
        } else {
            guard let filePath = dpFile.fileUrl?.path().removingPercentEncoding else { return nil }
            let hashValue = try await FileHash.shared.createSHA512Hash(filePath: filePath)
            if let hashValue {
                checksum = Checksum(type: .SHA_512, value: hashValue)
                dpFile.checksums.updateChecksum(checksum!)
            } else {
                checksum = nil
            }
        }
        return checksum
    }

    private func zipFile(url: URL) async throws -> URL {
        let pathUrl = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        let zipPath = pathUrl.appendingPathComponent(fileName + ".zip")
        fileManager.changeCurrentDirectoryPath(pathUrl.path)

        do {
            let _ = try await Subprocess.string(for: ["/usr/bin/zip", "--symlinks", "-r", zipPath.path, fileName])
        } catch {
            LogManager.shared.logMessage(message: "Failed to create zip file \(zipPath.path) from \(url.path)", level: .error)
            throw DistributionPointError.failedToCreateZipFile
        }

        return zipPath
    }
}
