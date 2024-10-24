//
//  Copyright 2024, Jamf
//

import SwiftUI

struct JamfProServerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var jamfProInstance: JamfProInstance
    @Binding var canceled: Bool
    @State var name = ""
    @State var usernameOrClientId = ""
    @State var passwordOrClientSecret = ""
    @State var urlString = ""
    @State var useClientApi = false
    @State var saveInKeychain = true
    @State var showTestAlert = false
    @State var testResultMessage = ""
    @State var testInProgress = false
    let keychainHelper = KeychainHelper()
    let recommendedClientApiPrivileges = "Update Packages, Jamf Packages Action, Read Cloud Services Settings, Read Jamf Content Distribution Server Files, Create Packages, Delete Packages, Read Cloud Distribution Point, Update Cloud Distribution Point, Create Jamf Content Distribution Server Files, Read Distribution Points, Read Packages, Delete Jamf Content Distribution Server Files"
    let recommendedCapiPrivileges = "Packages (Create, Read, Update, Delete), Categories (Read), File share distribution points (Read), Jamf Content Distribution Server Files (Create, Read, Delete)"

    var body: some View {
        VStack(spacing: 10) {
            Text("Jamf Pro Server")
                .font(.title)
                .padding(.bottom)

            HStack {
                VStack(alignment: .trailing) {
                    Text("Name:")
                        .frame(height: 16)
                        .padding(.bottom)
                    Text("URL:")
                        .frame(height: 16)
                        .padding(.bottom)
                    Text("\(usernameClientIdPrompt()):")
                        .frame(height: 16)
                        .padding(.bottom)
                    Text("\(passwordClientSecretPrompt()):")
                        .frame(height: 16)
                }
                VStack {
                    TextField("Name", text: $name)
                        .frame(height: 16)
                        .padding(.bottom)
                    TextField("https://jamfproserver.com", text: $urlString)
                        .frame(height: 16)
                        .padding(.bottom)
                    TextField("", text: $usernameOrClientId, prompt: Text(usernameClientIdPrompt()))
                        .frame(height: 16)
                        .padding(.bottom)
                    HStack {
                        SecureField(text: $passwordOrClientSecret, prompt: Text(passwordClientSecretPrompt())) {
                            Text("Title")
                        }
                        Toggle(isOn: $saveInKeychain) {
                            Text("Save in Keychain")
                        }
                    }
                    .frame(height: 16)
                }
            }

            Toggle(isOn: $useClientApi) {
                Text("Use Client API")
            }
            .toggleStyle(.checkbox)

            HStack {
                Text("Recommended privileges: \(useClientApi ? recommendedClientApiPrivileges : recommendedCapiPrivileges)")
                    .frame(height: useClientApi ? 90 : 50)
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(useClientApi ? recommendedClientApiPrivileges : recommendedCapiPrivileges, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                }
            }

            HStack {
                Spacer()
                ZStack {
                    Button {
                        testResultMessage = "Success!"
                        let jamfProInstance = JamfProInstance(name: name, url: URL(string: urlString), useClientApi: useClientApi, usernameOrClientId: usernameOrClientId, passwordOrClientSecret: passwordOrClientSecret)
                        testInProgress = true
                        Task {
                            do {
                                try await jamfProInstance.loadDps()
                            } catch {
                                testResultMessage = "Failed: \(error)"
                            }
                            showTestAlert = true
                            testInProgress = false
                        }
                    } label: {
                        if testInProgress {
                            ProgressView()
                                .scaleEffect(x: 0.5, y: 0.5, anchor: .center)
                                .frame(width: 16, height: 16, alignment: .center)
                        } else {
                            Text("Test")
                        }
                    }
                    .disabled(testInProgress)
                }
                .disabled(!requiredFieldsFilled())
                .padding([.top, .trailing])

                Button("Cancel") {
                    canceled = true
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .padding([.top, .trailing])
                Button("OK") {
                    canceled = false
                    saveStateVariables()
                    storePasswordInKeychain()
                    dismiss()
                }
                .disabled(!requiredFieldsFilled())
                .keyboardShortcut(.defaultAction)
                .padding(.top)
                Spacer()
            }
            .alert("\(testResultMessage)", isPresented: $showTestAlert) {
                HStack {
                    Button("OK") {
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .onAppear() {
            loadStateVariables()
        }
            .padding()
            .frame(width: 600)
    }

    func usernameClientIdPrompt() -> String {
        return useClientApi ? "Client Id" : "Username"
    }

    func passwordClientSecretPrompt() -> String {
        return useClientApi ? "Client Secret" : "Password"
    }

    func storePasswordInKeychain() {
        guard saveInKeychain else {
            deleteKeychainItem()
            return
        }

        if let urlHost = URL(string: urlString)?.host(), let data = jamfProInstance.passwordOrClientSecret.data(using: .utf8), !jamfProInstance.passwordOrClientSecret.isEmpty, !jamfProInstance.usernameOrClientId.isEmpty {
            Task {
                let serviceName = keychainHelper.jamfProServiceName(urlString: urlHost)
                do {
                    try await keychainHelper.storeInformationToKeychain(serviceName: serviceName, key: jamfProInstance.usernameOrClientId, data: data)
                } catch {
                    LogManager.shared.logMessage(message: "Failed to save the password for \(urlHost) to the keychain: \(error)", level: .error)
                }
            }
        }
        else {
            LogManager.shared.logMessage(message: "Not enough or the correct kind of data was available to save the password in the keychain.", level: .error)
        }
    }

    func deleteKeychainItem() {
        if let urlHost = URL(string: urlString)?.host() {
            Task {
                let serviceName = keychainHelper.jamfProServiceName(urlString: urlHost)
                do {
                    try await keychainHelper.deleteKeychainItem(serviceName: serviceName, key: jamfProInstance.usernameOrClientId)
                } catch {
                    LogManager.shared.logMessage(message: "Failed to remove the password for \(urlHost) from the keychain: \(error)", level: .error)
                }
            }
        }
    }

    func requiredFieldsFilled() -> Bool {
        return !name.isEmpty && !urlString.isEmpty && !usernameOrClientId.isEmpty && !passwordOrClientSecret.isEmpty
    }

    func loadStateVariables() {
        name = jamfProInstance.name
        usernameOrClientId = jamfProInstance.usernameOrClientId
        passwordOrClientSecret = jamfProInstance.passwordOrClientSecret
        urlString = jamfProInstance.url?.absoluteString ?? ""
        useClientApi = jamfProInstance.useClientApi
        saveInKeychain = UserSettings.shared.saveServerPwInKeychain
    }

    func saveStateVariables() {
        jamfProInstance.name = name
        jamfProInstance.usernameOrClientId = usernameOrClientId
        jamfProInstance.passwordOrClientSecret = passwordOrClientSecret
        jamfProInstance.url = URL(string: urlString)
        jamfProInstance.useClientApi = useClientApi
        UserSettings.shared.saveServerPwInKeychain = saveInKeychain
    }
}


struct JamfProServerView_Previews: PreviewProvider {
    static var previews: some View {
        @State var jamfProInstance: JamfProInstance = JamfProInstance(name: "MyServer", url: URL(string: "https://my.server.com")!, useClientApi: true, usernameOrClientId: "admin", passwordOrClientSecret: "password")
        @State var canceled: Bool = false
        JamfProServerView(jamfProInstance: $jamfProInstance, canceled: $canceled)
    }
}
