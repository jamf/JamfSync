//
//  Copyright 2024, Jamf
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    var body: some View {
        VStack(alignment: .trailing) {
            Picker("Allow deletions after synchronization:", selection: $settingsViewModel.allowDeletionsAfterSynchronization) {
                ForEach(DeletionOptions.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .onChange(of: settingsViewModel.allowDeletionsAfterSynchronization, initial: false) {
                settingsViewModel.saveSettings()
                DataModel.shared.updateListViewModels()
            }

            Picker("Allow manual deletions:", selection: $settingsViewModel.allowManualDeletions) {
                ForEach(DeletionOptions.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .onChange(of: settingsViewModel.allowManualDeletions, initial: false) {
                settingsViewModel.saveSettings()
                DataModel.shared.updateListViewModels()
            }
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
