//
//  Copyright 2024, Jamf
//

import Foundation

struct JsonToken: Decodable {
    let token: String
    let expires: String
}

struct JsonOauthToken: Decodable {
    let access_token: String
    let scope: String
    let token_type: String
    let expires_in: Int
}

struct JsonCloudInformation: Decodable {
    let cloudInstance: Bool
}

struct JsonCloudDpUploadCapability: Decodable {
    let principalDistributionTechnology: Bool
    let directUploadCapable: Bool
}

struct JsonDps: Decodable {
    let distribution_points: [JsonDp]
}

struct JsonDp: Decodable {
    let id: Int
    let name: String
}

struct JsonDpItem: Decodable {
    let distribution_point: JsonDpDetail
}

struct JsonDpDetail: Decodable {
    var connection_type: String?
    var context: String?
    var enable_load_balancing: Bool?
    var failover_point: String?
    var failover_point_url: String?
    var http_downloads_enabled: Bool?
    var http_password_sha256: String?
    var http_url: String?
    var http_username: String?
    var id: Int?
    var ip_address: String?
    var is_master: Bool?
    var local_path: String?
    var name: String?
    var no_authentication_required: Bool?
    var port: Int?
    var protoco: String?
    var read_only_password_sha256: String?
    var read_only_username: String?
    var read_write_password_sha256: String?
    var read_write_username: String?
    var share_name: String?
    var share_port: Int?
    var ssh_password_sha256: String?
    var ssh_username: String?
    var username_password_required: Bool?
    var workgroup_or_domain: String?
}

struct JsonUapiPackages: Decodable {
    let totalCount: Int
    let results: [JsonUapiPackageDetail]
}

struct JsonUapiPackageDetail: Codable {
    let id: String?
    let packageName: String?
    let fileName: String?
    var categoryId: String?
    var info: String?
    var notes: String?
    var priority: Int?
    var osRequirements: String?
    var fillUserTemplate: Bool?
    var indexed: Bool?
    var uninstall: Bool?
    var fillExistingUsers: Bool?
    var swu: Bool?
    var rebootRequired: Bool?
    var selfHealNotify: Bool?
    var selfHealingAction: String?
    var osInstall: Bool?
    var serialNumber: String?
    var parentPackageId: String?
    var basePath: String?
    var suppressUpdates: Bool?
    var cloudTransferStatus: String?
    var ignoreConflicts: Bool?
    var suppressFromDock: Bool?
    var suppressEula: Bool?
    var suppressRegistration: Bool?
    var installLanguage: String?
    var md5: String?
    var sha256: String?
    var hashType: String?
    var hashValue: String?
    var size: String?
    var osInstallerVersion: String?
    var manifest: String?
    var manifestFileName: String?
    var format: String?

    init(package: Package) {
        if let srcId = package.jamfProId {
            id = String(srcId)
        } else {
            id = nil
        }
        packageName = package.displayName
        fileName = package.fileName
        categoryId = package.category
        categoryId = package.categoryId ?? "-1"
        priority = package.priority ?? 10
        fillUserTemplate = package.fillUserTemplate ?? false
        uninstall = package.uninstall ?? false
        rebootRequired = package.rebootRequired ?? false
        osInstall = package.osInstall ?? false
        suppressUpdates = package.suppressUpdates ?? false
        suppressFromDock = package.suppressFromDock ?? false
        suppressEula = package.suppressEula ?? false
        suppressRegistration = package.suppressRegistration ?? false
        if let checksum = package.checksums.findChecksum(type: .MD5) {
            md5 = checksum.value
        } else {
            md5 = nil
        }
        if let checksum = package.checksums.findChecksum(type: .SHA_256) {
            sha256 = checksum.value
        } else {
            sha256 = nil
        }
        if let checksum = package.checksums.findChecksum(type: .SHA_512) {
            hashType = "SHA_512"
            hashValue = checksum.value
        } else {
            hashType = nil
            hashValue = nil
        }
        if let pkgSize = package.size {
            size = String(pkgSize)
        } else {
            size = nil
        }

        info = package.info
        notes = package.notes
        osRequirements = package.osRequirements
        indexed = package.indexed
        fillExistingUsers = package.fillExistingUsers
        swu = package.swu
        selfHealNotify = package.selfHealNotify
        selfHealingAction = package.selfHealingAction
        serialNumber = package.serialNumber
        parentPackageId = package.parentPackageId
        basePath = package.basePath
        cloudTransferStatus = package.cloudTransferStatus
        ignoreConflicts = package.ignoreConflicts
        installLanguage = package.installLanguage
        osInstallerVersion = package.osInstallerVersion
        format = package.format
    }
}

struct JsonUapiAddPackageResult: Decodable {
    let id: String
    let href: String?
}

struct JsonCapiPackages: Decodable {
    let packages: [JsonCapiPackage]
}

struct JsonCapiPackage: Decodable {
    let id: Int
    let name: String
}

struct JsonCapiPackageItem: Decodable {
    let package: JsonCapiPackageDetail
}

struct JsonCapiPackageDetail: Decodable {
    var allow_uninstalled: Bool?
    var category: String?
    var filename: String?
    var fill_existing_users: Bool?
    var fill_user_template: Bool?
    var hash_type: String?
    var hash_value: String?
    let id: Int?
    var info: String?
    var install_if_reported_available: String?
    let name: String?
    var notes: String?
    var os_requirements: String?
    var priority: Int?
    var reboot_required: Bool?
    var reinstall_option: String?
    var required_processor: String?
    var send_notification: Bool?
    var switch_with_package: String?
    var triggering_files: [String: String]?
}

struct JsonCloudFile: Decodable {
    let fileName: String?
    let length: Int64?
    let md5: String?
    let regoin: String?
    let sha3: String?
}

struct JsonCloudFileDownload: Decodable {
    let uri: String?
}

struct JsonInitiateUpload: Decodable {
    let accessKeyID: String?
    let expiration: Int?
    let secretAccessKey: String?
    let sessionToken: String?
    let region: String?
    let bucketName: String?
    let path: String?
    let uuid: String?
}

struct JsonJamfProVersion: Decodable {
    let version: String
}
