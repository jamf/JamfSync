//
//  Copyright 2024, Jamf
//
// Derived from https://stackoverflow.com/questions/74510888/set-boundary-on-urlsession-uploadtask-with-fromfile

import Foundation

enum OutputStreamError: Error {
    case stringConversionFailure
    case bufferFailure
    case writeFailure
    case readFailure(URL)
}

extension OutputStream {
    /// Write `String` to `OutputStream`
    ///
    /// - parameter string:                The `String` to write.
    /// - parameter encoding:              The `String.Encoding` to use when writing the string. This will default to `.utf8`.
    /// - parameter allowLossyConversion:  Whether to permit lossy conversion when writing the string. Defaults to `false`.
    func write(_ string: String, encoding: String.Encoding = .utf8, allowLossyConversion: Bool = false) throws {
        guard let data = string.data(using: encoding, allowLossyConversion: allowLossyConversion) else {
            throw OutputStreamError.stringConversionFailure
        }
        try write(data)
    }

    /// Write `Data` to `OutputStream`
    ///
    /// - parameter data:                  The `Data` to write.
    func write(_ data: Data) throws {
        try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) throws in
            guard let pointer = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw OutputStreamError.bufferFailure
            }

            try write(buffer: pointer, length: buffer.count)
        }
    }

    /// Write contents of local `URL` to `OutputStream`
    ///
    /// - parameter fileURL:                  The `URL` of the file to written to this output stream.
    func write(contentsOf fileURL: URL) throws {
        guard let inputStream = InputStream(url: fileURL) else {
            throw OutputStreamError.readFailure(fileURL)
        }

        inputStream.open()
        defer { inputStream.close() }

        let bufferSize = 65_536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while inputStream.hasBytesAvailable {
            let length = inputStream.read(buffer, maxLength: bufferSize)
            if length < 0 {
                throw OutputStreamError.readFailure(fileURL)
            } else if length > 0 {
                try write(buffer: buffer, length: length)
            }
        }
    }
}

private extension OutputStream {
    /// Writer buffer to output stream.
    ///
    /// This will loop until all bytes are written. On failure, this throws an error
    ///
    /// - Parameters:
    ///   - buffer: Unsafe pointer to the buffer.
    ///   - length: Number of bytes to be written.
    func write(buffer: UnsafePointer<UInt8>, length: Int) throws {
        var bytesRemaining = length
        var pointer = buffer

        while bytesRemaining > 0 {
            let bytesWritten = write(pointer, maxLength: bytesRemaining)
            if bytesWritten < 0 {
                throw OutputStreamError.writeFailure
            }

            bytesRemaining -= bytesWritten
            pointer += bytesWritten
        }
    }
}
