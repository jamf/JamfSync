//
//  Copyright 2024, Jamf
//

import SwiftUI

struct ConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    var promptMessage = "Are you sure?"
    var includeCancelButton = true
    @Binding var canceled: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(promptMessage)
                .font(.title)

            HStack {
                Spacer()
                if includeCancelButton {
                    Button("Cancel") {
                        canceled = true
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .padding([.top, .trailing])
                }
                Button("OK") {
                    canceled = false
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding(.top)
                Spacer()
            }
        }
        .onAppear() {
            canceled = false
        }
        .padding()
    }
}

struct ConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        @State var canceled = false
        ConfirmationView(canceled: $canceled)
    }
}
