//
//  Copyright 2024, Jamf
//

import Foundation
import CryptoKit

actor FileHash {
    static var shared: FileHash = FileHash()

    func createSHA512Hash(filePath: String) throws -> String? {
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }

        if let input = InputStream(fileAtPath: filePath) {
            defer {
                input.close()
            }
            input.open()
            var hasher = SHA512()
            while input.hasBytesAvailable {
                let read = input.read(buffer, maxLength: bufferSize)
                if read < 0 {
                    //Stream error occured
                    throw input.streamError!
                } else if read == 0 {
                    //EOF
                    break
                }
                var data = Data()
                data.append(buffer, count: read)
                hasher.update(data: data)
            }
            let hash = hasher.finalize()
            return Data(hash).hexEncodedString()
        }
        return nil
    }
}

extension Data {
    func hexEncodedString() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
}
