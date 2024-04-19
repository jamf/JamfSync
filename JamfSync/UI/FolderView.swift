//
//  Copyright 2024, Jamf
//

import SwiftUI

struct FolderView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var folderInstance: FolderInstance
    @Binding var canceled: Bool
    @State var name: String = ""
    @State var filePath: String = ""

    var body: some View {
        VStack(spacing: 10) {
            Text("File Folder")
                .font(.title)
                .padding(.bottom)

            HStack {
                Text("Name:")

                TextField(text: $name, prompt: Text("Name:")) {
                    Text("Name")
                }
            }

            HStack {
                Text("Path:")

                TextField(text: $filePath, prompt: Text("Path:")) {
                    Text("Path")
                }
                .disabled(true)

                Button("Choose...")
                {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK, let path = panel.url?.path().removingPercentEncoding {
                        filePath = path
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
                    saveStateVariables()
                    dismiss()
                }
                .disabled(!requiredFieldsFilled())
                .keyboardShortcut(.defaultAction)
                .padding(.top)
                Spacer()
            }
        }
        .onAppear() {
            loadStateVariables()
        }
        .padding()
        .frame(width: 600, height: 200)
    }

    func requiredFieldsFilled() -> Bool {
        return !name.isEmpty && !filePath.isEmpty
    }

    func loadStateVariables() {
        name = folderInstance.name
        filePath = folderInstance.folderDp.filePath
    }

    func saveStateVariables() {
        folderInstance.name = name
        folderInstance.folderDp.name = folderInstance.name
        folderInstance.folderDp.filePath = filePath
    }
}

struct FolderView_Previews: PreviewProvider {
    static var previews: some View {
        @State var folderInstance = FolderInstance()
        @State var canceled: Bool = false
        FolderView(folderInstance: $folderInstance, canceled: $canceled)
    }
}
