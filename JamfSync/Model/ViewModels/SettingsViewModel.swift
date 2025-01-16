//
//  Copyright 2024, Jamf
//

import Foundation

class SettingsViewModel: ObservableObject {
    let userSettings = UserSettings()

    @Published var allowDeletionsAfterSynchronization: DeletionOptions = .none
    @Published var allowManualDeletions: DeletionOptions = .filesAndAssociatedPackages

    init() {
        loadSettings()
    }

    func loadSettings() {
        allowDeletionsAfterSynchronization = userSettings.allowDeletionsAfterSynchronization
        allowManualDeletions = userSettings.allowManualDeletions
    }

    func saveSettings() {
        userSettings.allowDeletionsAfterSynchronization = allowDeletionsAfterSynchronization
        userSettings.allowManualDeletions = allowManualDeletions
    }
}
