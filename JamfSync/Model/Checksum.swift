//
//  Copyright 2024, Jamf
//

import Foundation

enum ChecksumType: String {
    case SHA3_512 = "SHA3-512"
    case SHA_512 = "SHA-512"
    case SHA_256 = "SHA-256"
    case MD5 = "MD5"

    static func fromRawValue(_ rawValue: String) -> ChecksumType {
        switch rawValue {
        case String(describing: ChecksumType.SHA_512):
            return .SHA_512
        case String(describing: ChecksumType.SHA_256):
            return .SHA_256
        default:
            return .MD5
        }
    }
}

struct Checksum: Equatable, Identifiable {
    let id = UUID()
    var type: ChecksumType
    var value: String
}
