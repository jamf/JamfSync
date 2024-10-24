//
//  Copyright 2024, Jamf
//

import Foundation
import NetFS

enum ConnectionType: String {
    case smb = "SMB"
    case afp = "AFP"
}

actor FileShare {
    let type: ConnectionType
    let address: String
    let shareName: String
    let username: String
    let password: String
    var mountPoint: String?
    let fileManager: FileManager

    init(type: ConnectionType, address: String, shareName: String, username: String, password: String, mountPoint: String? = nil, fileManager: FileManager = FileManager.default) {
        self.type = type
        self.address = address
        self.shareName = shareName
        self.username = username
        self.password = password
        self.mountPoint = mountPoint
        self.fileManager = fileManager
    }
    
    func mount() throws {
        if mountPoint != nil {
            return // If already mounted, just return
        }
        guard let url = URL(string: "\(type)://\(address)/\(shareName)"), let mountDirectoryUrl = URL(string: "/Volumes") else { throw FileShareMountFailure.mountingFailed }

        var mountPoints: Unmanaged<CFArray>?
        let uiOptions: NSDictionary = [
            kNAUIOptionKey: kNAUIOptionNoUI
        ]
        let result = NetFSMountURLSync(url as CFURL,
                                       mountDirectoryUrl as CFURL,
                                       username as CFString?,
                                       password as CFString?,
                                       uiOptions as! CFMutableDictionary?,
                                       nil,
                                       &mountPoints)
        guard result == 0 else {
            throw FileShareMountFailure.mountingFailed
        }
        
        if let mountPathStringsArray = mountPoints?.takeRetainedValue() as? [String] {
            if mountPathStringsArray.count > 0 {
                mountPoint = mountPathStringsArray[0]
                return
            }
        }

        throw FileShareMountFailure.mountingFailed
    }

    func unmount() async throws {
        guard let mountPoint else { return }
        let url = URL(filePath: mountPoint)

        try await fileManager.unmountVolume(at: url, options: [FileManager.UnmountOptions.withoutUI])
        self.mountPoint = nil
    }
}
