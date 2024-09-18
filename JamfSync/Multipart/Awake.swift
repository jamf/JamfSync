//
//  Awake.swift
//
//  Copyright 2024 jamf. All rights reserved.
//

import Foundation
import IOKit.pwr_mgt

var noSleepAssertionID: IOPMAssertionID = 0
var noDiskIdleAssertionID: IOPMAssertionID = 1
var noSleepReturn: IOReturn?
var noDiskIdleReturn: IOReturn?

public func disableSleep(reason: String) -> Bool? {
    guard noSleepReturn == nil else { return nil }
    noSleepReturn = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &noSleepAssertionID)
    return noSleepReturn == kIOReturnSuccess
}

public func disableDiskIdle(reason: String) -> Bool? {
    guard noDiskIdleReturn == nil else { return nil }
    noDiskIdleReturn = IOPMAssertionCreateWithName(kIOPMAssertPreventDiskIdle as CFString,IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &noDiskIdleAssertionID)
    return noDiskIdleReturn == kIOReturnSuccess
}

public func enableSleep() -> Bool {
    _ = enableIdleDisk()
    if noSleepReturn != nil {
        _ = IOPMAssertionRelease(noSleepAssertionID) == kIOReturnSuccess
        noSleepReturn = nil
        return true
    }
    return false
}

public func enableIdleDisk() -> Bool {
    if noDiskIdleReturn != nil {
        _ = IOPMAssertionRelease(noDiskIdleAssertionID) == kIOReturnSuccess
        noDiskIdleReturn = nil
        //WriteToLog.shared.message(stringOfText: "allow external disk(s) to become idle")
        return true
    }
    return false
}
