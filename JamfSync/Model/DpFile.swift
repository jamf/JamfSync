//
//  Copyright 2024, Jamf
//

import Foundation

// NOTE: This is a class instead of a struct so it can be passed by reference since they need to be stored in a list and later found and modified
class DpFile: Identifiable {
    var id = UUID()
    var name: String
    var fileUrl: URL?
    var sizeString: String { return size == nil ? "--" : String(size!) }
    var size: Int64?
    var checksums = Checksums()

    init(name: String, fileUrl: URL? = nil, size: Int64?, checksums: Checksums? = nil) {
        self.name = name
        self.fileUrl = fileUrl
        self.size = size
        if let checksums {
            self.checksums = checksums
        }
    }

    init(dpFile: DpFile) {
        id = dpFile.id
        name = dpFile.name
        fileUrl = dpFile.fileUrl
        size = dpFile.size
        checksums = dpFile.checksums
    }

    static func == (lhs: DpFile, rhs: DpFile) -> Bool {
        if lhs.checksums.hasMatchingChecksumType(checksums: rhs.checksums) {
            return lhs.checksums == rhs.checksums
        } else {
            return lhs.size == rhs.size
        }
    }
}
