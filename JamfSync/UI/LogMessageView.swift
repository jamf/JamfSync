//
//  Copyright 2024, Jamf
//

import SwiftUI

struct LogMessageView: View {
    @StateObject var logViewModel = LogViewModel()

    var body: some View {
        if let messageToShow =  logViewModel.messageToShow {
            ZStack {
                logLevelColor(logLevel: messageToShow.logLevel)
                Text(messageToShow.message).background(logLevelColor(logLevel: messageToShow.logLevel))
            }
            .frame(height: 24)
            .padding([.top, .bottom, .leading])
        }
    }

    func logLevelColor(logLevel: LogLevel) -> Color {
        switch logLevel {
        case .error:
            return .red
        case .warning:
            return .yellow
        case .info:
            return .green
        default:
            return .gray
        }
    }
}

struct LogMessageView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var logViewModel = LogViewModel()
        LogMessageView(logViewModel: logViewModel)
    }
}
