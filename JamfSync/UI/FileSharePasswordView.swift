//
//  Copyright 2024, Jamf
//

import SwiftUI

struct FileSharePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var fileShareDp: FileShareDp?
    @Binding var canceled: Bool
    @State var saveInKeychain = true
    @State var password = ""
    let keychainHelper = KeychainHelper()

    var body: some View {
        VStack(spacing: 10) {
            Text("File Share Password")
                .font(.title)
            Text("Enter the password for \(fileShareDp?.selectionName() ?? ""): \(fileShareDp?.address ?? "")")
                .padding(.bottom)

            HStack {
                VStack(alignment: .trailing) {
                    Text("Password:")
                        .frame(height: 16)
                }
                VStack {
                    HStack {
                        SecureField(text: $password, prompt: Text("Password")) {
                            Text("Title")
                        }
                        Toggle(isOn: $saveInKeychain) {
                            Text("Save in Keychain")
                        }
                    }
                    .frame(height: 16)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    canceled = true
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .padding([.top, .trailing])
                Button("OK") {
                    canceled = false
                    fileShareDp?.readWritePassword = password
                    storePasswordInKeychain()
                    UserSettings.shared.saveDistributionPointPwInKeychain = saveInKeychain
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding(.top)
                Spacer()
            }
        }
        .onAppear() {
            saveInKeychain = UserSettings.shared.saveDistributionPointPwInKeychain
            password = fileShareDp?.readWritePassword ?? ""
        }
        .padding()
        .frame(width: 600)
    }

    func storePasswordInKeychain() {
        guard saveInKeychain, let fileShareDp else { return }
        
        if let address = fileShareDp.address, let username = fileShareDp.readWriteUsername, let password = fileShareDp.readWritePassword, !password.isEmpty, let data = password.data(using: String.Encoding.utf8) {
            Task {
                do {
                    let serviceName = keychainHelper.fileShareServiceName(urlString: address)
                    try await keychainHelper.storeInformationToKeychain(serviceName: serviceName, key: username, data: data)
                } catch {
                    LogManager.shared.logMessage(message: "Failed to save the password for \(address) to the keychain: \(error)", level: .error)
                }
            }
        }
        else {
            LogManager.shared.logMessage(message: "Not enough or the correct kind of data was available to save the password for \(fileShareDp.selectionName()) in the keychain.", level: .error)
        }
    }
}


struct FileSharePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        @State var fileShareDp: FileShareDp? = FileShareDp(jamfProId: 1, name: "My Fileshare description that's kind of long", address: "https://myfileshareurl.com", isMaster: true, connectionType: .smb, shareName: "CasperShare", workgroupOrDomain: "", sharePort: 0, readOnlyUsername: nil, readOnlyPassword: nil, readWriteUsername: "admin", readWritePassword: "password")
        @State var canceled: Bool = false
        FileSharePasswordView(fileShareDp: $fileShareDp, canceled: $canceled)
    }
}
