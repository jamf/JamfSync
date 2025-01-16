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
        .alert(deletionMessage(), isPresented: $promptForSynchronizationOptions) {
            HStack {
                let dp = dataModel.findDp(id: dataModel.selectedDstDpId)
                if dp?.jamfProInstanceId == nil {
                    Button("Yes", role: .destructive) {
                        Task {
                            await startSynchronize(deleteFiles: true, deletePackages: false)
                        }
                    }
                } else {
                    if includeFilesAndAssociatedPackagesOption(dp: dp) {
                        Button("Files and associated package records", role: .destructive) {
                            Task {
                                await startSynchronize(deleteFiles: true, deletePackages: true)
                            }
                        }
                    }
                    if includeFilesOnlyOption(dp: dp) {
                        Button("Files only", role: .destructive) {
                            Task {
                                await startSynchronize(deleteFiles: true, deletePackages: false)
                            }
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

    func includeFilesAndAssociatedPackagesOption(dp: DistributionPoint?) -> Bool {
        if let dp, dp.deleteByRemovingPackage {
            return dataModel.settingsViewModel.allowDeletionsAfterSynchronization != .none
        }
        return dataModel.settingsViewModel.allowDeletionsAfterSynchronization == .filesAndAssociatedPackages
    }

    func includeFilesOnlyOption(dp: DistributionPoint?) -> Bool {
        if let dp, dp.deleteByRemovingPackage {
            return false
        }
        return dataModel.settingsViewModel.allowDeletionsAfterSynchronization != .none
    }

    func deletionMessage() -> String {
        var message = "Do you want to delete items from the destination that are not on the source?"
        var warning = " WARNING: Deletions cannot be undone!"
        if let dstDp = dataModel.findDp(id: dataModel.selectedDstDpId), let srcDp = dataModel.findDp(id: dataModel.selectedSrcDpId) {
            let filesToRemove = dstDp.filesToRemove(srcDp: srcDp)
            message += " There are \(filesToRemove.count) files "
            if filesToRemove.count == dstDp.dpFiles.files.count {
                warning = " WARNING: This is all of the files on the destination! Deletions cannot be undone!"
            }
            warning += packageDeletionWarning(dp: dstDp)
            if let jamfProInstance = DataModel.shared.findJamfProInstance(id: dstDp.jamfProInstanceId) {
                let packagesToRemove = jamfProInstance.packagesToRemove(srcDp: srcDp)
                message += "and \(packagesToRemove.count) package records "
            }
            message += "that can be removed.\(warning)"
        }

        return message
    }

    func packageDeletionWarning(dp: DistributionPoint?) -> String {
        if let dp, dp.deleteByRemovingPackage, dataModel.settingsViewModel.allowDeletionsAfterSynchronization == .filesOnly {
            return "\n\nNOTE: \"Allow deletions after synchronization\" in Settings is set to \"Files Only\", however, for the \"\(dp.selectionName())\" distribution point, files cannot be deleted without also deleting the associated package records."
        }
        return ""
    }

    func startSynchronize(deleteFiles: Bool, deletePackages: Bool) async {
        if let srcDp = dataModel.findDp(id: dataModel.selectedSrcDpId), let dstDp = dataModel.findDp(id: dataModel.selectedDstDpId) {
            SynchronizeProgressView(srcDp: srcDp, dstDp: dstDp, deleteFiles: deleteFiles, deletePackages: deletePackages, processToExecute: { (synchronizeTask, deleteFiles, deletePackages, progress, synchronizationProgressView) in
                    synchronize(srcDp: srcDp, dstDp: dstDp, synchronizeTask: synchronizeTask, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress, synchronizeProgressView: synchronizationProgressView) })
                .openInNewWindow { window in
                window.title = "Synchronization Progress"
            }
        }
    }

    func synchronize(srcDp: DistributionPoint?, dstDp: DistributionPoint, synchronizeTask: SynchronizeTask, deleteFiles: Bool, deletePackages: Bool, progress: SynchronizationProgress, synchronizeProgressView: SynchronizeProgressView) {
        Task {
            var reloadFiles = false
            DataModel.shared.cancelUpdateListViewModels()
            DataModel.shared.synchronizationInProgress = true
            do {
                guard let srcDp else { throw DistributionPointError.programError }
                
                reloadFiles = try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: DataModel.shared.selectedDpFilesFromSelectionIds(packageListViewModel: DataModel.shared.srcPackageListViewModel), jamfProInstance: DataModel.shared.findJamfProInstance(id: dstDp.jamfProInstanceId), forceSync: DataModel.shared.forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)
            } catch {
                LogManager.shared.logMessage(message: "Failed to synchronize \(srcDp?.name ?? "nil") to \(dstDp.name): \(error)", level: .error)
            }
            DataModel.shared.synchronizationInProgress = false
            // Wait a second for the progress bar to catch up and then close
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                synchronizeProgressView.dismiss()
                DataModel.shared.updateListViewModels(reload: reloadFiles ? .source : .none)
            })
        }
    }

    func showLog() {
        LogView().openInNewWindow { window in
            window.title = "Activity and Error Log"
        }
    }

    func promptForDeletion() -> Bool {
        if dataModel.settingsViewModel.allowDeletionsAfterSynchronization == .none {
            return false
        }
        if dataModel.srcPackageListViewModel.selectedDpFiles.count == 0 {
            if let srcDp = dataModel.findDp(id: dataModel.selectedSrcDpId), let dstDp = dataModel.findDp(id: dataModel.selectedDstDpId) {
                // If there are any packages on the destination Jamf Pro server that would be removed, then prompt
                if let jamfProInstance = DataModel.shared.findJamfProInstance(id: dstDp.jamfProInstanceId) {
                    if jamfProInstance.packagesToRemove(srcDp: srcDp).count > 0 {
                        return dataModel.settingsViewModel.allowDeletionsAfterSynchronization != .none
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
