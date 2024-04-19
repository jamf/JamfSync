//
//  Copyright 2024, Jamf
//

import Foundation
import OSLog

class LogManager: ObservableObject {
    static let shared = LogManager()
    static let logMessageNotification = "com.jamfsoftware.jamfsync.logMessageNotification"
    var logMessages: [LogMessage] = []
    let log = OSLog(subsystem: "com.jamf.jamfsync", category: "JamfSync")
    let logger = Logger(subsystem: "com.jamf.jamfsync", category: "JamfSync")

    func logMessage(message: String, level: LogLevel) {
        let logMessage = LogMessage(logLevel: level, message: message)
        let logMessageString = logMessageToString(logMessage)
        writeSystemLog(message: message, level: level)

        if logMessage.showToUser() {
            writeMessageToConsole(logMessageString)
            logMessages.append(logMessage)
            NotificationCenter.default.post(name: Notification.Name(LogManager.logMessageNotification), object: logMessage)
        }
    }

    func writeMessageToConsole(_ message: String) {
        print("\(message)")
    }

    func writeSystemLog(message: String, level: LogLevel) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .private)")
        case .verbose:
            logger.trace("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        }
    }

    func logMessageToString(_ logMessage: LogMessage) -> String {
        let dateString = dateToLogDateString(logMessage.date)
        return "\(dateString)-\(logMessage.logLevel.rawValue): \(logMessage.message)"
    }

    func dateToLogDateString(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YY/MM/dd HH:mm:ss"
        return dateFormatter.string(from: date)
    }
}
