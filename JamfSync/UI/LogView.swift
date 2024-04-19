//
//  Copyright 2024, Jamf
//

import SwiftUI

struct LogView: View {
    @StateObject var logViewModel = LogViewModel()
    @State private var sortOrder = [KeyPathComparator(\LogMessage.date), KeyPathComparator(\LogMessage.logLevel), KeyPathComparator(\LogMessage.message)]

    var body: some View {
        VStack {
            Table(logViewModel.logMessages, sortOrder: $sortOrder) {
                TableColumn("Date & Time", value: \.date) { logMessage in
                    Text(LogManager.shared.dateToLogDateString(logMessage.date))
                }
                .width(ideal: 120)
                TableColumn("Type", value: \.logLevel) { logMessage in
                    Text(logMessage.logLevel.rawValue)
                }
                .width(ideal: 50)
                TableColumn("Message", value: \.message)
                    .width(ideal: 2000)
            }
            .onChange(of: sortOrder) {
                logViewModel.logMessages.sort(using: sortOrder)
            }
            .padding()
        }
        .frame(minWidth: 650)        
        .toolbar {
            Button {
                logViewModel.clear()
            } label: {
                Image(systemName: "trash")
            }
            .help("Remove all messages")
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
