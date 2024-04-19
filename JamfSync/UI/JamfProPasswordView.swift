//
//  Copyright 2024, Jamf
//

import SwiftUI

struct JamfProPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var jamfProInstances: [JamfProInstance]
    @Binding var canceled: Bool
    @State var saveInKeychain = true
    @State var password = ""
    let keychainHelper = KeychainHelper()

    var body: some View {
        VStack(spacing: 10) {
            if jamfProInstances.count > 0 {
                Text("Jamf Pro Password")
                    .font(.title)
                Text("Enter the password for \(jamfProInstances[0].name) (\(jamfProInstances[0].url?.absoluteString ?? ""))")
                    .padding(.bottom)

                HStack {
                    VStack(alignment: .trailing) {
                        Text("\(passwordClientSecretPrompt(jamfProInstance: jamfProInstances[0])):")
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
                    jamfProInstances[0].passwordOrClientSecret = password
                    storePasswordInKeychain(jamfProInstance: jamfProInstances[0])
                    UserSettings.shared.saveServerPwInKeychain = saveInKeychain
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding(.top)
                Spacer()
            }
        }
        .onAppear() {
            saveInKeychain = UserSettings.shared.saveServerPwInKeychain
            password = jamfProInstances[0].passwordOrClientSecret
        }
        .padding()
        .frame(width: 600)
    }

    func storePasswordInKeychain(jamfProInstance: JamfProInstance) {
        guard saveInKeychain else { return }

        if let address = jamfProInstance.url?.host {
            let username = jamfProInstance.usernameOrClientId
            let password = jamfProInstance.passwordOrClientSecret
            if !password.isEmpty, let data = password.data(using: String.Encoding.utf8) {
                Task {
                    do {
                        let serviceName = keychainHelper.jamfProServiceName(urlString: address)
                        try await keychainHelper.storeInformationToKeychain(serviceName: serviceName, key: username, data: data)
                    } catch {
                        LogManager.shared.logMessage(message: "Failed to save the password for \(address) to the keychain: \(error)", level: .error)
                    }
                }
            }
        }
        else {
            LogManager.shared.logMessage(message: "Not enough or the correct kind of data was available to save the password for \(jamfProInstance.name) in the keychain.", level: .error)
        }
    }

    func passwordClientSecretPrompt(jamfProInstance: JamfProInstance) -> String {
        return jamfProInstance.useClientApi ? "Client Secret" : "Password"
    }
}

struct JamfProPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        @State var jamfProInstances: [JamfProInstance] = [JamfProInstance(name: "My Test Server", url: URL(string: "https://mytest01.jamfcloud.com"))]
        @State var canceled: Bool = false
        JamfProPasswordView(jamfProInstances: $jamfProInstances, canceled: $canceled)
    }
}
