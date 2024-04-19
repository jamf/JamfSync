//
//  Copyright 2024, Jamf
//

import Foundation

class VersionInfo {
    func getDisplayVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? ""
        return "Version: \(version) (\(build))"
    }
}
