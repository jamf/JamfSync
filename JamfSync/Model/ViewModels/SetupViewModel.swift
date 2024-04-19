//
//  Copyright 2024, Jamf
//

import Foundation

class SetupViewModel: ObservableObject {
    @Published var selectedSavableItemId: SavableItem.ID?
    @Published var title: String = ""
    @Published var shouldPresentJamfProServerSheet = false
    @Published var shouldPresentFileFolderSheet = false
    @Published var shouldPresentEditSheet = false
    @Published var shouldPresentConfirmationSheet = false
    @Published var folderInstance = FolderInstance()
    @Published var jamfProInstance = JamfProInstance()
    @Published var canceled = false
}
