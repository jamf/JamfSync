//
//  Copyright 2024, Jamf
//

import Foundation

class UserSettings {
    static let shared = UserSettings()

    private let saveServerPwInKeychainKey = "saveServerPwInKeychain"
    private let saveDistributionPointPwInKeychainKey = "saveDistributionPointPwInKeychain"
    private let firstRunKey = "firstRun"
    private let allowDeletionsAfterSynchronizationKey = "allowDeletionsAfterSynchronization"

    init() {
        UserDefaults.standard.register(defaults: [
            saveServerPwInKeychainKey: true,
            saveDistributionPointPwInKeychainKey: true,
            firstRunKey: true,
            allowDeletionsAfterSynchronizationKey: false
            ])
    }

    var saveServerPwInKeychain: Bool {
        get { return UserDefaults.standard.bool(forKey: saveServerPwInKeychainKey) }
        set(value) { UserDefaults.standard.set(value, forKey: saveServerPwInKeychainKey) }
    }

    var saveDistributionPointPwInKeychain: Bool {
        get { return UserDefaults.standard.bool(forKey: saveDistributionPointPwInKeychainKey) }
        set(value) { UserDefaults.standard.set(value, forKey: saveDistributionPointPwInKeychainKey) }
    }

    var firstRun: Bool {
        get { return UserDefaults.standard.bool(forKey: firstRunKey) }
        set(value) { UserDefaults.standard.set(value, forKey: firstRunKey) }
    }

    var allowDeletionsAfterSynchronization: Bool {
        get { return UserDefaults.standard.bool(forKey: allowDeletionsAfterSynchronizationKey) }
        set(value) { UserDefaults.standard.set(value, forKey: allowDeletionsAfterSynchronizationKey) }
    }
}
