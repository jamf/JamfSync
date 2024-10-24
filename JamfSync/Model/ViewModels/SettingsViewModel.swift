//
//  Copyright 2024, Jamf
//

import Foundation

class SettingsViewModel: ObservableObject {
    let userSettings = UserSettings()
    @Published var allowDeletionsAfterSynchronization = false

    init() {
        loadSettings()
    }

    func loadSettings() {
        allowDeletionsAfterSynchronization = userSettings.allowDeletionsAfterSynchronization
    }

    func saveSettings() {
        userSettings.allowDeletionsAfterSynchronization = allowDeletionsAfterSynchronization
    }
}
