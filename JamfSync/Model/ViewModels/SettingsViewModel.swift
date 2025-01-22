//
//  Copyright 2024, Jamf
//

import Foundation

class SettingsViewModel: ObservableObject {
    let userSettings = UserSettings()

    @Published var allowDeletionsAfterSynchronization: DeletionOptions = .none
    @Published var allowManualDeletions: DeletionOptions = .filesAndAssociatedPackages
    @Published var promptForJamfProInstances = false

    init() {
        loadSettings()
    }

    func loadSettings() {
        allowDeletionsAfterSynchronization = userSettings.allowDeletionsAfterSynchronization
        allowManualDeletions = userSettings.allowManualDeletions
        promptForJamfProInstances = userSettings.promptForJamfProInstances
    }

    func saveSettings() {
        userSettings.allowDeletionsAfterSynchronization = allowDeletionsAfterSynchronization
        userSettings.allowManualDeletions = allowManualDeletions
        userSettings.promptForJamfProInstances = promptForJamfProInstances
    }
}
