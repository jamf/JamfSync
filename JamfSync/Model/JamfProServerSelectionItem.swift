//
//  Copyright 2024, Jamf
//

import Foundation

struct JamfProServerSelectionItem: Identifiable {
    var id = UUID()
    var selectionName: String
    var isActive: Bool
    var jamfProInstance: JamfProInstance

    init(jamfProInstance: JamfProInstance) {
        self.jamfProInstance = jamfProInstance
        self.selectionName = "\(jamfProInstance.displayName()) (\(jamfProInstance.displayInfo()))"
        self.isActive = jamfProInstance.isActive
    }
}
