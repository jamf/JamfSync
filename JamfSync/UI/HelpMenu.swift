//
//  Copyright 2024, Jamf
//

import SwiftUI
import QuickLook

struct HelpMenu: View {
    @State var userGuideUrl: URL?

    var body: some View {
        Group {
            Button("Jamf Sync User Guide") {
                userGuideUrl = Bundle.main.url(forResource: "Jamf Sync User Guide", withExtension: "pdf")
            }
            .quickLookPreview($userGuideUrl)
        }
    }
}
