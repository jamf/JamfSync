//
//  Copyright 2024, Jamf
//

import Foundation

extension FileManager {
    func moveRetainingDestinationPermisssions(at srcURL: URL, to dstURL: URL) throws {
        try "Placeholder file with permissions of containing directory".write(to: dstURL, atomically: false, encoding: .utf8)
        if let result = try self.replaceItemAt(dstURL, withItemAt: srcURL), result.path() != dstURL.path() {
            // This probably can't happen, but if it does, we should know about it.
            LogManager.shared.logMessage(message: "When moving \(srcURL.path) to \(dstURL.path), the file name was changed to \(result.path)", level: .warning)
        }

        // The replaceItemAt function seems to move the original file, but the name and documentation for the function
        // doesn't imply that so we'll attempt to remove the file but ignore any errors.
        try? self.removeItem(at: srcURL)
    }
}
