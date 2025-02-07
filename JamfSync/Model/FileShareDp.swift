//
//  Copyright 2024, Jamf
//

import Foundation

class FileShareDp: DistributionPoint {
    var jamfProId: Int
    var address: String?
    var isMaster: Bool
    var connectionType: ConnectionType
    var shareName: String?
    var workgroupOrDomain: String?
    var sharePort: Int?
    var readOnlyUsername: String?
    var readOnlyPassword: String?
    var readWriteUsername: String?
    var readWritePassword: String?
    var fileShare: FileShare?
    var mountPoint: String?
    var localPath: String?
    var userSettings = UserSettings.shared

    let keychainHelper = KeychainHelper()

    init(jamfProId: Int, name: String, address: String, isMaster: Bool, connectionType: ConnectionType, shareName: String, workgroupOrDomain: String, sharePort: Int, readOnlyUsername: String?, readOnlyPassword: String?, readWriteUsername: String?, readWritePassword: String?) {
        self.jamfProId = jamfProId
        self.address = address
        self.isMaster = isMaster
        self.connectionType = connectionType
        self.shareName = shareName
        self.workgroupOrDomain = workgroupOrDomain
        self.sharePort = sharePort
        self.readOnlyUsername = readOnlyUsername
        self.readOnlyPassword = readOnlyPassword
        self.readWriteUsername = readWriteUsername
        self.readWritePassword = readWritePassword
        super.init(name: name)
    }

    init(JsonDpDetail: JsonDpDetail) {
        self.jamfProId = JsonDpDetail.id ?? -1
        self.address = JsonDpDetail.ip_address
        self.isMaster = JsonDpDetail.is_master ?? false
        if let connectionTypeString = JsonDpDetail.connection_type, let connectionType = ConnectionType(rawValue: connectionTypeString) {
            self.connectionType = connectionType
        } else {
            self.connectionType = .smb
        }
        self.shareName = JsonDpDetail.share_name
        self.workgroupOrDomain = JsonDpDetail.workgroup_or_domain
        self.sharePort = JsonDpDetail.share_port
        self.readOnlyUsername = JsonDpDetail.read_only_username
        self.readOnlyPassword = nil // This would normally be from JsonDpDetail.read_only_password_sha256, but that's all asterisks
        self.readWriteUsername = JsonDpDetail.read_write_username
        self.readWritePassword = nil // This would normally be from JsonDpDetail.read_write_password_sha256, but that's all asterisks
        super.init(name: JsonDpDetail.name ?? "")
        loadKeychainData()
    }

    override func showCalcChecksumsButton() -> Bool {
        return true
    }

    override func prepareDp() async throws {
        try await mount()
    }

    override func cleanupDp() async throws {
        Task { @MainActor in
            DataModel.shared.showSpinner = true
        }

        try await fileShare?.unmount()

        Task { @MainActor in
            DataModel.shared.showSpinner = false
        }
    }

    override func retrieveFileList(limitFileTypes: Bool = true) async throws {
        try await mount()
        guard let localPath else { 
            throw DistributionPointError.cannotGetFileList
        }
        try await retrieveLocalFileList(localPath: localPath, limitFileTypes: limitFileTypes)
    }

    override func transferFile(srcFile: DpFile, moveFrom: URL? = nil, progress: SynchronizationProgress) async throws {
        guard let localPath else { throw DistributionPointError.cannotGetFileList }
        try await transferLocal(localPath: localPath, srcFile: srcFile, moveFrom: moveFrom, progress: progress)
    }

    override func deleteFile(file: DpFile, progress: SynchronizationProgress) async throws {
        guard let localPath else { throw DistributionPointError.cannotGetFileList }
        let fileUrl = URL(fileURLWithPath: localPath).appendingPathComponent(file.name)
        try deleteLocal(localUrl: fileUrl, progress: progress)
    }

    override func needsToPromptForPassword() -> Bool {
        return readWritePassword == nil
    }

    // MARK: - Private functions

    private func mount() async throws {
        guard let address else { throw FileShareMountFailure.addressMissing }
        guard let shareName else { throw FileShareMountFailure.shareNameMissing }
        guard let readWriteUsername else { throw FileShareMountFailure.noUsername }
        guard let readWritePassword else { throw FileShareMountFailure.noPassword }

        Task { @MainActor in
            DataModel.shared.showSpinner = true
        }
        do {
            fileShare = try await FileShares.shared.mountFileShare(type: connectionType, address: address, shareName: shareName, username: readWriteUsername, password: readWritePassword)
            if let mountPoint = await fileShare?.mountPoint {
                let mountPointUrl = URL(filePath: mountPoint)
                let packagesUrl = mountPointUrl.appendingPathComponent("Packages", isDirectory: true)
                localPath = packagesUrl.path().removingPercentEncoding
                if let localPath, !fileManager.fileExists(atPath: localPath) {
                    do {
                        try fileManager.createDirectory(at: packagesUrl, withIntermediateDirectories: false)
                    } catch {
                        LogManager.shared.logMessage(message: "\"Packages\" directory does not exist on file share \(name) and it couldn't be created: \(error)", level: .error)
                        throw error
                    }
                }
                saveUsernameInUserSettings(username: readWriteUsername)
            }
        } catch {
            let serviceName = keychainHelper.fileShareServiceName(username: readWriteUsername, urlString: address)
            Task { @MainActor in
                DataModel.shared.dpToPromptForPassword = self
                DataModel.shared.shouldPromptForDpPassword = true
            }
            Task { @MainActor in
                DataModel.shared.showSpinner = false
            }
            throw error
        }
        Task { @MainActor in
            DataModel.shared.showSpinner = false
        }
    }

    private func loadKeychainData() {
        guard let address, let readWriteUsername else { return }
        let keychainHelper = KeychainHelper()
        var serviceName = keychainHelper.fileShareServiceName(username: readWriteUsername, urlString: address)
        Task {
            do {
                let data = try await keychainHelper.getInformationFromKeychain(serviceName: serviceName, key: readWriteUsername)
                readWritePassword = String(data: data, encoding: .utf8)
            }
            catch {
                // Check to see if there is an alternate username in the settings and if so, see if there's a keychain entry for that
                let distributionPointUsernames = userSettings.distributionPointUsernames
                if let username = distributionPointUsernames[address], username != readWriteUsername {
                    do {
                        serviceName = keychainHelper.fileShareServiceName(username: username, urlString: address)
                        let data = try await keychainHelper.getInformationFromKeychain(serviceName: serviceName, key: username)
                        self.readWritePassword = String(data: data, encoding: .utf8)
                        self.readWriteUsername = username
                    } catch {
                        // If it fails for any reason, just assume it's not available in the keychain. The user will need to go in and edit the password.
                    }
                }
            }
        }
    }

    func saveUsernameInUserSettings(username: String) {
        guard let address else { return }
        var distributionPointUsernames = userSettings.distributionPointUsernames
        if distributionPointUsernames[address] != username {
            distributionPointUsernames[address] = username
            userSettings.distributionPointUsernames = distributionPointUsernames
        }
    }
}
