//
//  Copyright 2024, Jamf
//

import Foundation

struct TestingUtility {
    static var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               NSClassFromString("XCTestCase") != nil
    }
}
