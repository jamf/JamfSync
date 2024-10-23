//
//  Copyright 2024, Jamf
//

import Foundation

extension FileManager {
    func moveRetainingDestinationPermisssions(at srcURL: URL, to dstURL: URL) throws {
        LogManager.shared.logMessage(message: "Moving file from \(srcURL) to \(dstURL) while retaining permissions", level: .debug)
        try "Placeholder file with permissions of containing directory".write(to: dstURL, atomically: false, encoding: .utf8)
        do {
            if let result = try self.replaceItemAt(dstURL, withItemAt: srcURL), result.path() != dstURL.path() {
                // This probably can't happen, but if it does, we should know about it.
                LogManager.shared.logMessage(message: "When moving \(srcURL.path) to \(dstURL.path), the file name was changed to \(result.path)", level: .warning)
            }
        } catch {
            // The above only works when it is a local folder and not a file share. So just copy the file in that case.
            LogManager.shared.logMessage(message: "Failed to replace the temporary file when moving \(srcURL) to \(dstURL) while retaining permissions. Just copying it without permissions now.", level: .debug)
            try? self.removeItem(at: dstURL)
            try self.copyItem(at: srcURL, to: dstURL)
        }
        
        let fileAttributes: [FileAttributeKey: Any] = [
            .posixPermissions: 0o644
        ]
        try self.setAttributes(fileAttributes, ofItemAtPath: dstURL.path())

        // The replaceItemAt function seems to move the original file, but the name and documentation for the function
        // doesn't imply that so we'll attempt to remove the file but ignore any errors. Also, the copyItem function does
        // not delete it.
        try? self.removeItem(at: srcURL)
    }
}
