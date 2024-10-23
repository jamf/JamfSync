//
//  Copyright 2024, Jamf
//

import Foundation
import IOKit.pwr_mgt

class KeepAwake {
    static let shared = KeepAwake()

    var noSleepAssertionID: IOPMAssertionID = 0
    var noDiskIdleAssertionID: IOPMAssertionID = 1
    var sleepDisabled = false
    var idleDiskDisabled = false

    deinit {
        enableSleep()
    }

    public func disableSleep(reason: String) {
        guard !sleepDisabled else { return }
        let status = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &noSleepAssertionID)
        if status == kIOReturnSuccess {
            sleepDisabled = true
        } else {
            LogManager.shared.logMessage(message: "Failed to disable sleep...this could cause the upload to fail.", level: .warning)
        }
    }

    public func disableDiskIdle(reason: String) {
        guard !idleDiskDisabled else { return }
        let status = IOPMAssertionCreateWithName(kIOPMAssertPreventDiskIdle as CFString,IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &noDiskIdleAssertionID)
        if status == kIOReturnSuccess {
            idleDiskDisabled = true
        } else {
            LogManager.shared.logMessage(message: "Failed to disable disk idle...this could cause the upload to fail.", level: .warning)
        }
    }

    public func enableSleep() {
        enableIdleDisk()
        guard sleepDisabled else { return }
        if IOPMAssertionRelease(noSleepAssertionID) == kIOReturnSuccess {
            sleepDisabled = false
        } else {
            LogManager.shared.logMessage(message: "Failed to re-enable sleep...this could affect power consumption.", level: .warning)
        }
    }

    public func enableIdleDisk() {
        guard idleDiskDisabled else { return }
        if IOPMAssertionRelease(noDiskIdleAssertionID) == kIOReturnSuccess {
            idleDiskDisabled = false
        } else {
            LogManager.shared.logMessage(message: "Failed to re-enable disk idle...this could affect power consumption.", level: .warning)
        }
    }
}
