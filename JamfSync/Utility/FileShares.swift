//
//  Copyright 2024, Jamf
//

import Foundation

enum FileShareMountFailure: Error {
    case addressMissing
    case shareNameMissing
    case mountingFailed
    case unmountingFailed
    case noUsername
    case noPassword
}

actor FileShares {
    static let shared = FileShares()
    var fileShares: [FileShare]

    private init() {
        fileShares = []
    }

    /// Mounts a file share and returns a mountpoint, or just returns the mountpoint if it's already been mounted
    /// - Parameters:
    ///     - type: The connection type for mounting
    ///     - address: The address of the fileshare
    ///     - shareName: The name of the directory being shared
    ///     - username: The username to use when mounting the fileshare
    ///     - password: The password to use when mounting the fileshare
    func mountFileShare(type: ConnectionType, address: String, shareName: String, username: String, password: String) async throws -> FileShare {
        var fileShare = findFileShare(type: type, address: address, shareName: shareName)
        if fileShare == nil {
            fileShare = FileShare(type: type, address: address, shareName: shareName, username: username, password: password)
            if let fileShare { // This will always succeed but this is so we don't need to use !
                fileShares.append(fileShare)
                try await fileShare.mount()
            }
        }

        guard let fileShare else { throw DistributionPointError.programError }
        return fileShare
    }

    /// Stores the information including mount point for a fileshare that's already mounted. This is used for unit tests.
    /// - Parameters:
    ///     - type: The connection type for mounting
    ///     - address: The address of the fileshare
    ///     - shareName: The name of the directory being shared
    ///     - username: The username to use when mounting the fileshare
    ///     - password: The password to use when mounting the fileshare
    ///     - mountPoint: The mountPoint of the fileshare
    func alreadyMounted(type: ConnectionType, address: String, shareName: String, username: String, password: String, mountPoint: String?) {
        let fileShare = FileShare(type: type, address: address, shareName: shareName, username: username, password: password, mountPoint: mountPoint)
        fileShares.append(fileShare)
    }

    private func findFileShare(type: ConnectionType, address: String, shareName: String) -> FileShare? {
        return fileShares.first { $0.type == type && $0.address == address && $0.shareName == shareName }
    }
}
