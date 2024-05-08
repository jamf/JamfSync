//
//  Copyright 2024, Jamf
//

import SwiftUI

struct LogView: View {
    @StateObject var logViewModel = LogViewModel()
    @State private var sortOrder = [KeyPathComparator(\LogMessage.date), KeyPathComparator(\LogMessage.logLevel), KeyPathComparator(\LogMessage.message)]
    @State private var selectedItems: Set<LogMessage.ID> = []

    var body: some View {
        VStack {
            Table(logViewModel.logMessages, selection: $selectedItems, sortOrder: $sortOrder) {
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
            if selectedItems.count > 0 {
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(stringForSelectedItems(), forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy selected log messages to the clipboard")
            }

            Button {
                logViewModel.clear()
            } label: {
                Image(systemName: "trash")
            }
            .help("Remove all messages")
        }
    }

    func stringForSelectedItems() -> String {
        var text = ""
        for id in selectedItems {
            if let logMessage = logViewModel.findLogMessage(id: id) {
                text += "\(LogManager.shared.logMessageToString(logMessage))\n"
            }
        }
        return text
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
