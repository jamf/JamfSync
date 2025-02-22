//
//  Copyright 2024, Jamf
//

import SwiftUI

struct FileShareCredentialsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var fileShareDp: FileShareDp?
    @Binding var canceled: Bool
    @State var saveInKeychain = true
    @State var username = ""
    @State var password = ""
    let keychainHelper = KeychainHelper()

    var body: some View {
        VStack {
            Text("File Share Credentials")
                .font(.title)
            Text("Enter the credentials for \(fileShareDp?.selectionName() ?? ""): \(fileShareDp?.address ?? "")")
                .padding(.bottom)

            HStack {
                Text("Username:")
                TextField("", text: $username, prompt: Text("Username:"))
            }
            .padding(.bottom)

            HStack {
                Text("Password:")
                SecureField(text: $password, prompt: Text("Password")) {
                    Text("Title")
                }
                Toggle(isOn: $saveInKeychain) {
                    Text("Save in Keychain")
                }
            }
            .padding(.bottom)

            HStack {
                Button("Cancel") {
                    canceled = true
                    dismiss()
                }
                Button("OK") {
                    canceled = false
                    fileShareDp?.readWriteUsername = username
                    fileShareDp?.readWritePassword = password
                    storeCredentialsInKeychain()
                    UserSettings.shared.saveDistributionPointPwInKeychain = saveInKeychain
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear() {
            saveInKeychain = UserSettings.shared.saveDistributionPointPwInKeychain
            username = fileShareDp?.readWriteUsername ?? ""
            password = fileShareDp?.readWritePassword ?? ""
        }
        .padding()
        .frame(width: 600)
    }

    func storeCredentialsInKeychain() {
        guard saveInKeychain, let fileShareDp else { return }
        
        if let address = fileShareDp.address, let username = fileShareDp.readWriteUsername, let password = fileShareDp.readWritePassword, !password.isEmpty, let data = password.data(using: String.Encoding.utf8) {
            Task {
                do {
                    let serviceName = keychainHelper.fileShareServiceName(username: username, urlString: address)
                    try await keychainHelper.storeInformationToKeychain(serviceName: serviceName, key: username, data: data)
                } catch {
                    LogManager.shared.logMessage(message: "Failed to save the credentials for \(address) to the keychain: \(error)", level: .error)
                }
            }
        }
        else {
            LogManager.shared.logMessage(message: "Not enough or the correct kind of data was available to save the credentials for \(fileShareDp.selectionName()) in the keychain.", level: .error)
        }
    }
}

struct FileShareCredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        @State var fileShareDp: FileShareDp? = FileShareDp(jamfProId: 1, name: "My Fileshare description that's kind of long", address: "https://myfileshareurl.com", isMaster: true, connectionType: .smb, shareName: "CasperShare", workgroupOrDomain: "", sharePort: 0, readOnlyUsername: nil, readOnlyPassword: nil, readWriteUsername: "admin", readWritePassword: "password")
        @State var canceled: Bool = false
        FileShareCredentialsView(fileShareDp: $fileShareDp, canceled: $canceled)
    }
}
