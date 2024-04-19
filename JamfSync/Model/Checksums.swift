//
//  Copyright 2024, Jamf
//

import Foundation

class Checksums: Equatable {
    var checksums: [Checksum] = []

    func updateChecksum(_ checksumToUpdate: Checksum) {
        removeChecksum(type: checksumToUpdate.type)
        checksums.append(checksumToUpdate)
    }

    func hasMatchingChecksumType(checksums: Checksums) -> Bool {
        for checksum in self.checksums {
            if checksums.findChecksum(type: checksum.type) != nil {
                return true
            }
        }
        return false
    }

    @discardableResult func removeChecksum(type: ChecksumType) -> Bool {
        let startingCount = checksums.count
        checksums = checksums.filter { $0.type != type }
        return (startingCount != checksums.count)
    }

    func findChecksum(type: ChecksumType) -> Checksum? {
        return checksums.first { $0.type == type }
    }

    func bestChecksum() -> Checksum? {
        // NOTE: Technically .SHA3_512 is probably better than .SHA_512, but the binary doesn't support SHA3_512 yet
        var checksum = findChecksum(type: .SHA_512)
        if checksum == nil {
            checksum = findChecksum(type: .SHA_256)
        }
        if checksum == nil {
            checksum = findChecksum(type: .MD5)
        }
        return checksum
    }

    static func == (lhs: Checksums, rhs: Checksums) -> Bool {
        if let sha512 = lhs.findChecksum(type: .SHA_512), let sha512ToCompare = rhs.findChecksum(type: .SHA_512) {
            return sha512.value == sha512ToCompare.value
        }
        if let md5 = lhs.findChecksum(type: .MD5), let md5ToCompare = rhs.findChecksum(type: .MD5) {
            return md5.value == md5ToCompare.value
        }

        return false
    }
}
