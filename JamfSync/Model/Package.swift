//
//  Copyright 2024, Jamf
//

import Foundation

struct Package: Identifiable {
    var id = UUID()
    var jamfProId: Int?
    var displayName: String
    var fileName: String
    var category: String
    var size: Int64?
    var checksums = Checksums()

    init(jamfProId: Int?, displayName: String, fileName: String, category: String, size: Int64?, checksums: Checksums) {
        self.jamfProId = jamfProId
        self.displayName = displayName
        self.fileName = fileName
        self.category = category
        self.size = size
        self.checksums = checksums
    }

    init(packageDetail: JsonCapiPackageDetail) {
        jamfProId = packageDetail.id
        displayName = packageDetail.name ?? ""
        fileName = packageDetail.filename ?? ""
        category = packageDetail.category ?? "None"
        let hashType = packageDetail.hash_type ?? "MD5"
        let hashValue = packageDetail.hash_value
        if let hashValue, !hashValue.isEmpty {
            checksums.updateChecksum(Checksum(type: ChecksumType.fromRawValue(hashType), value: hashValue))
        }
    }
}
