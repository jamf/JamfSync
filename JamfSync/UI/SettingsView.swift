//
//  Copyright 2024, Jamf
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    var body: some View {
        VStack(alignment: .trailing) {
            Toggle("Allow deletions after synchronization", isOn: $settingsViewModel.allowDeletionsAfterSynchronization)
                .onChange(of: settingsViewModel.allowDeletionsAfterSynchronization, initial: false) {
                    settingsViewModel.saveSettings()
                    DataModel.shared.updateListViewModels()
                }
                .toggleStyle(SwitchToggleStyle())
                .padding()
            Spacer()
        }
        .frame(height: 60)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var settingsViewModel = SettingsViewModel()
        SettingsView(settingsViewModel: settingsViewModel)
    }
}
