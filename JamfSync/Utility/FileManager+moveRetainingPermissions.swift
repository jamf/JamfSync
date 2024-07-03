//
//  Copyright 2024, Jamf
//

import Foundation

extension FileManager {
    func moveRetainingDestinationPermisssions(at srcURL: URL, to dstURL: URL) throws {
        try "Placeholder file with permissions of containing directory".write(to: dstURL, atomically: false, encoding: .utf8)
        do {
            if let result = try self.replaceItemAt(dstURL, withItemAt: srcURL), result.path() != dstURL.path() {
                // This probably can't happen, but if it does, we should know about it.
                LogManager.shared.logMessage(message: "When moving \(srcURL.path) to \(dstURL.path), the file name was changed to \(result.path)", level: .warning)
            }
        } catch {
            // The above only works when it is a local folder and not a file share. So just copy the file in that case.
            try? self.removeItem(at: dstURL)
            try self.copyItem(at: srcURL, to: dstURL)
        }

        // The replaceItemAt function seems to move the original file, but the name and documentation for the function
        // doesn't imply that so we'll attempt to remove the file but ignore any errors. Also, the copyItem function does
        // not delete it.
        try? self.removeItem(at: srcURL)
    }
}
