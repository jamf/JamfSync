//
//  Copyright 2024, Jamf
//

import Foundation

enum TemporaryFilesError: Error {
    case failedToCreateTempDirectory
}

class TemporaryFiles {
    let jamfSyncDirectoryName = "JamfSync"
    var tempDirectory: URL?
    let fileManager = FileManager.default

    deinit {
        guard let tempDirectory else { return }

        // Attempt to clean up the directory, but don't sweat it if it fails.
        try? fileManager.removeItem(at: tempDirectory)
    }

    func moveToTemporaryDirectory(src: URL, dstName: String) throws -> URL {
        try createTemporaryDirectory()
        guard let tempDirectory else { throw TemporaryFilesError.failedToCreateTempDirectory }

        let dstFileUrl = tempDirectory.appending(component: dstName)
        try fileManager.moveItem(at: src, to: dstFileUrl)
        return dstFileUrl
    }

    func jamfSyncTempDirectory() throws -> URL {
        try createTemporaryDirectory()
        guard let tempDirectory else { throw TemporaryFilesError.failedToCreateTempDirectory }
        return tempDirectory
    }

    // MARK - Private functions

    private func createTemporaryDirectory() throws {
        guard tempDirectory == nil else { return }
        let newTempDirectory = URL.temporaryDirectory.appending(component: jamfSyncDirectoryName)
        var isDirectory : ObjCBool = true
        let exists = FileManager.default.fileExists(atPath: newTempDirectory.path(), isDirectory: &isDirectory)
        if exists {
            if isDirectory.boolValue {
                tempDirectory = newTempDirectory
                return
            } else {
                try fileManager.removeItem(at: newTempDirectory)
            }
        }
        try fileManager.createDirectory(at: newTempDirectory, withIntermediateDirectories: true)
        tempDirectory = newTempDirectory
    }
}
