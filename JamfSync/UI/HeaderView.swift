//
//  Copyright 2024, Jamf
//

import SwiftUI

struct HeaderView: View {
    var dataPersistence: DataPersistence
    @StateObject var dataModel = DataModel.shared
    @State var changesMade = false
    @State var promptForSynchronizationOptions = false
    @State var canceled = false

    var body: some View {
        HStack {
            Image("JamfSync_64")
                .padding([.trailing])

            Text("Jamf Sync")
                .font(.title)

            Spacer()

            Button {
                if promptForDeletion() {
                    promptForSynchronizationOptions = true
                } else {
                    Task {
                        await startSynchronize(deleteFiles: false, deletePackages: false)
                    }
                }
            } label: {
                Text("Synchronize")
                    .font(.title2)
                    .padding()
            }
            .keyboardShortcut(.defaultAction)
            .padding([.trailing])
            .disabled(dataModel.synchronizationDisabled())

            Toggle(isOn: $dataModel.forceSync) {
                Text("Force Sync")
            }
            .toggleStyle(.checkbox)
            .onChange(of: dataModel.forceSync) {
                dataModel.updateListViewModels()
            }
        }
        .alert("Do you want to delete items from the destination that are not on the source?", isPresented: $promptForSynchronizationOptions) {
            HStack {
                if dataModel.findDp(id: dataModel.selectedDstDpId)?.jamfProInstanceId == nil {
                    Button("Yes", role: .destructive) {
                        Task {
                            await startSynchronize(deleteFiles: true, deletePackages: false)
                        }
                    }
                } else {
                    Button("Files and associated packages", role: .destructive) {
                        Task {
                            await startSynchronize(deleteFiles: true, deletePackages: true)
                        }
                    }
                    Button("Files only", role: .destructive) {
                        Task {
                            await startSynchronize(deleteFiles: true, deletePackages: false)
                        }
                    }
                }
                Button("Only Add or Update", role: .none) {
                    Task {
                        await startSynchronize(deleteFiles: false, deletePackages: false)
                    }
                }
                Button("Cancel", role: .cancel) {
                }
            }
        }
    }

    func startSynchronize(deleteFiles: Bool, deletePackages: Bool) async {
        if let srcDp = dataModel.findDp(id: dataModel.selectedSrcDpId), let dstDp = dataModel.findDp(id: dataModel.selectedDstDpId) {
            SynchronizeProgressView(srcDp: srcDp, dstDp: dstDp, deleteFiles: deleteFiles, deletePackages: deletePackages).openInNewWindow { window in
                window.title = "Synchronization Progress"
            }
        }
    }

    func showLog() {
        LogView().openInNewWindow { window in
            window.title = "Activity and Error Log"
        }
    }

    func promptForDeletion() -> Bool {
        if dataModel.selectedDpFiles.count == 0 {
            if let srcDp = dataModel.findDp(id: dataModel.selectedSrcDpId), let dstDp = dataModel.findDp(id: dataModel.selectedDstDpId) {
                // If there are any packages on the destination Jamf Pro server that would be removed, then prompt
                if let jamfProInstance = DataModel.shared.findJamfProInstance(id: dstDp.jamfProInstanceId) {
                    if jamfProInstance.packagesToRemove(srcDp: srcDp).count > 0 {
                        return true
                    }
                }

                // Or if there are any files on the destination distribution point that would be deleted, then prompt
                if dstDp.filesToRemove(srcDp: srcDp).count > 0 {
                    return true
                }
            }
        }
        return false
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var dataPersistence = DataPersistence(dataManager: DataManager())
        @StateObject var dataModel = DataModel()
        HeaderView(dataPersistence: dataPersistence, dataModel: dataModel)
    }
}
