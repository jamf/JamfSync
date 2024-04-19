//
//  Copyright 2024, Jamf
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        HStack(alignment: .top) {
            Image("JamfSync_64")
            VStack(alignment: .leading) {
                Text("Jamf Sync")
                    .font(.title)
                Text("\(VersionInfo().getDisplayVersion())")

                Text("Jamf Sync helps synchronize content to Jamf Pro distribution points.\n\nCopyright 2024, Jamf")
                    .padding([.top])
            }
        }
        .padding()
        .frame(minWidth: 530, minHeight: 150)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
