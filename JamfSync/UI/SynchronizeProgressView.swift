//
//  Copyright 2024, Jamf
//

import SwiftUI

struct SynchronizeProgressView: View {
    @Environment(\.dismiss) private var dismiss
    var srcDp: DistributionPoint
    var dstDp: DistributionPoint
    var deleteFiles: Bool
    var deletePackages: Bool
    @StateObject var progress = SynchronizationProgress()
    @State var shouldPresentConfirmationSheet = false
    let synchronizeTask = SynchronizeTask()

    // For CrappyButReliableAnimation
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State var leftOffset: CGFloat = -100
    @State var rightOffset: CGFloat = 100

    var body: some View {
        VStack {
            HStack {
                Text("\(srcDp.selectionName())")
                    .padding()

                BackAndForthAnimation(leftOffset: $leftOffset, rightOffset: $rightOffset)

                Text("\(dstDp.selectionName())")
                    .padding()
            }
            .onReceive(timer) { (_) in
                swap(&self.leftOffset, &self.rightOffset)
            }

            if let currentFile = progress.currentFile, let fileProgress = progress.fileProgress()  {
                HStack {
                    if let operation = progress.operation {
                        Text("\(operation)")
                    }
                    Text("\(currentFile.name)")
                    ProgressView(value: fileProgress)
                }
                .padding([.leading, .trailing])
            }

            if let totalProgress = progress.totalProgress() {
                HStack {
                    Text("Overall Progress: ")
                    ProgressView(value: totalProgress)
                }
                .padding()
            }

            Button("Cancel") {
                shouldPresentConfirmationSheet = true
            }
            .padding(.bottom)
            .alert("Are you sure you want to cancel the syncrhonization?", isPresented: $shouldPresentConfirmationSheet) {
                HStack {
                    Button("Yes", role: .destructive) {
                        synchronizeTask.cancel()
                        shouldPresentConfirmationSheet = false
                    }
                    Button("No", role: .cancel) {
                        shouldPresentConfirmationSheet = false
                    }
                }
            }
        }
        .frame(minWidth: 600)
        .onAppear {
            progress.srcDp = srcDp
            progress.dstDp = dstDp
            Task {
                var reloadFiles = false
                DataModel.shared.cancelUpdateListViewModels()
                DataModel.shared.synchronizationInProgress = true
                do {
                    reloadFiles = try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: selectedIdsFromViewModelIds(srcIds: DataModel.shared.selectedDpFiles), jamfProInstance: DataModel.shared.findJamfProInstance(id: dstDp.jamfProInstanceId), forceSync: DataModel.shared.forceSync, deleteFiles: deleteFiles, deletePackages: deletePackages, progress: progress)
                } catch {
                    LogManager.shared.logMessage(message: "Failed to synchronize \(srcDp) to \(dstDp): \(error)", level: .error)
                }
                DataModel.shared.synchronizationInProgress = false
                // Wait a second for the progress bar to catch up and then close
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                    dismiss()
                    DataModel.shared.updateListViewModels(reload: reloadFiles ? .source : .none)
                })
            }
        }
    }

    func selectedIdsFromViewModelIds(srcIds: Set<DpFile.ID>) -> [DpFile] {
        var selectedFiles: [DpFile] = []
        for id in srcIds {
            if let viewModel = DataModel.shared.srcPackageListViewModel.dpFiles.findDpFileViewModel(id: id) {
                selectedFiles.append(viewModel.dpFile)
            }
        }
        return selectedFiles
    }
}

struct SynchronizeProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let srcDp = DistributionPoint(name: "CasperShare")
        let dstDp = DistributionPoint(name: "MyTest")
        @StateObject var progress = SynchronizationProgress()

        SynchronizeProgressView(srcDp: srcDp, dstDp: dstDp, deleteFiles: false, deletePackages: false, progress: progress)
    }
}
