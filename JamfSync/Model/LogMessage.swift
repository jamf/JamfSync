//
//  Copyright 2024, Jamf
//

import Foundation

enum LogLevel: String, Comparable {
    case debug = "DEBUG"
    case verbose = "VERBOSE"
    case warning = "WARNING"
    case error = "ERROR"
    case info = "INFO"

    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

struct LogMessage: Identifiable {
    let id = UUID()
    var date: Date
    var logLevel: LogLevel
    var message: String

    init(logLevel: LogLevel, message: String) {
        self.date = Date()
        self.logLevel = logLevel
        self.message = message
    }

    func showToUser() -> Bool {
        return logLevel == .error || logLevel == .warning || logLevel == .info || logLevel == .verbose
    }

    func showOnMainScreen() -> Bool {
        return logLevel == .error || logLevel == .warning || logLevel == .info
    }
}
