//
//  Copyright 2024, Jamf
//

import Foundation

enum DeletionOptions: String, CaseIterable {
    case none = "None"
    case filesOnly = "Files Only"
    case filesAndAssociatedPackages = "Files and Associated Packages"

    static func optionFromString(_ string: String) -> DeletionOptions? {
        return DeletionOptions.allCases.first { $0.rawValue == string }
    }
}

class UserSettings {
    static let shared = UserSettings()

    private let saveServerPwInKeychainKey = "saveServerPwInKeychain"
    private let saveDistributionPointPwInKeychainKey = "saveDistributionPointPwInKeychain"
    private let firstRunKey = "firstRun"
    private let allowDeletionsAfterSynchronizationKey = "allowDeletionsAfterSynchronization"
    private let allowManualDeletionsKey = "allowManualDeletions"
    private let promptForJamfProInstancesKey = "promptForJamfProInstances"
    private let distributionPointUsernamesKey = "distributionPointUsernames"

    init() {
        UserDefaults.standard.register(defaults: [
            saveServerPwInKeychainKey: true,
            saveDistributionPointPwInKeychainKey: true,
            firstRunKey: true,
            allowDeletionsAfterSynchronizationKey: DeletionOptions.none.rawValue,
            allowManualDeletionsKey: DeletionOptions.filesAndAssociatedPackages.rawValue,
            promptForJamfProInstancesKey: false,
            distributionPointUsernamesKey: [:]
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

    var allowDeletionsAfterSynchronization: DeletionOptions {
        get {
            if let stringValue = UserDefaults.standard.string(forKey: allowDeletionsAfterSynchronizationKey), let deleteOption = DeletionOptions.optionFromString(stringValue) {
                return deleteOption
            } else {
                return DeletionOptions.none
            }
        }

        set(value) {
            UserDefaults.standard.set(value.rawValue, forKey: allowDeletionsAfterSynchronizationKey)
        }
    }

    var allowManualDeletions: DeletionOptions {
        get {
            if let stringValue = UserDefaults.standard.string(forKey: allowManualDeletionsKey), let deleteOption = DeletionOptions.optionFromString(stringValue) {
                return deleteOption
            } else {
                return DeletionOptions.filesAndAssociatedPackages
            }
        }

        set(value) {
            UserDefaults.standard.set(value.rawValue, forKey: allowManualDeletionsKey)
        }
    }

    var promptForJamfProInstances: Bool {
        get { return UserDefaults.standard.bool(forKey: promptForJamfProInstancesKey) }
        set(value) { UserDefaults.standard.set(value, forKey: promptForJamfProInstancesKey) }
    }

    var distributionPointUsernames: [String: String] {
        get { return UserDefaults.standard.object(forKey: distributionPointUsernamesKey) as? [String: String] ?? [:] }
        set(value) { UserDefaults.standard.set(value, forKey: distributionPointUsernamesKey) }
    }
}
