//
//  Copyright 2024, Jamf
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    var body: some View {
        VStack {
            Picker("Allow deletions after synchronization:", selection: $settingsViewModel.allowDeletionsAfterSynchronization) {
                ForEach(DeletionOptions.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .onChange(of: settingsViewModel.allowDeletionsAfterSynchronization, initial: false) {
                settingsViewModel.saveSettings()
                DataModel.shared.updateListViewModels()
            }
            .padding()

            Picker("Allow manual deletions:", selection: $settingsViewModel.allowManualDeletions) {
                ForEach(DeletionOptions.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .onChange(of: settingsViewModel.allowManualDeletions, initial: false) {
                settingsViewModel.saveSettings()
                DataModel.shared.updateListViewModels()
            }
            .padding([.leading, .trailing, .bottom])

            Toggle("Prompt for Jamf Pro instances on startup", isOn: $settingsViewModel.promptForJamfProInstances)
                .onChange(of: settingsViewModel.promptForJamfProInstances, initial: false) {
                    settingsViewModel.saveSettings()
                    DataModel.shared.updateListViewModels()
                }
                .toggleStyle(SwitchToggleStyle())
                .padding([.leading, .trailing, .bottom])
        }
        .padding()
        .frame(width: 500)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var settingsViewModel = SettingsViewModel()
        SettingsView(settingsViewModel: settingsViewModel)
    }
}
