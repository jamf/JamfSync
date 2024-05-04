//
//  Copyright 2024, Jamf
//

import SwiftUI

struct HeaderItem: View {
    var title: String

    var body: some View {
        Text(title)
            .fontWeight(.bold)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.bar)
    }
}

struct DataItem: View {
    var text: String

    var body: some View {
        Text(text)
            .fontWeight(.bold)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PackageListView: View {
    var isSrc: Bool
    @ObservedObject var dataModel: DataModel
    @ObservedObject var packageListViewModel: PackageListViewModel
    let stateColumnSize = 35.0
    @State private var sortOrder = [KeyPathComparator(\DpFileViewModel.state), KeyPathComparator(\DpFileViewModel.dpFile.name), KeyPathComparator(\DpFileViewModel.dpFile.size)]
    let publisher = NotificationCenter.default
            .publisher(for: NSNotification.Name(PackageListViewModel.needToSortPackagesNotification))

    var body: some View {
        VStack {
            Table(packageListViewModel.dpFiles.files, selection: $packageListViewModel.selectedDpFiles, sortOrder: $sortOrder) {
                TableColumn("Sync", value: \.state) { item in
                    if let stateImageData = stateImage(fileItem: item) {
                        if let color = stateImageData.color {
                            Image(systemName: stateImageData.systemName)
                                .foregroundColor(color)
                                .help(item.state.rawValue)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack {
                                Image(systemName: stateImageData.systemName)
                                    .help(item.state.rawValue)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }
                .width(ideal: stateColumnSize)

                TableColumn("Name", value: \.dpFile.name)
                .width(ideal: 250)

                TableColumn("Size", value: \.dpFile.sizeString) { item in
                    Text(item.compressedSize())
                        .help(item.dpFile.sizeString)
                }
                .width(ideal: 75)

                TableColumn("Checksum") { item in
                    ChecksumView(packageListViewModel: packageListViewModel, file: item)
                }
                .width(ideal: 200)
            }
            .onChange(of: sortOrder) {
                packageListViewModel.dpFiles.files.sort(using: sortOrder)
                packageListViewModel.objectWillChange.send()
            }
            .alternatingRowBackgrounds(.disabled)

            ZStack {
                if packageListViewModel.showCalcChecksumsButton() {
                    Button {
                        if packageListViewModel.doChecksumCalculation {
                            packageListViewModel.cancelChecksumUpdate()
                        } else {
                            Task {
                                await packageListViewModel.updateChecksums()
                            }
                        }
                    } label: {
                        if packageListViewModel.doChecksumCalculation {
                            ProgressView()
                                .scaleEffect(x: 0.5, y: 0.5, anchor: .center)
                                .frame(width: 16, height: 16, alignment: .center)
                        } else {
                            Text("Calculate Checksums")
                        }
                    }
                    .padding(.bottom)
                }

                HStack {
                    Spacer()

                    Button {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = true
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        if panel.runModal() == .OK {
                            Task {
                                await startFileTransfer(fileUrls: panel.urls)
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!packageListViewModel.enableFileAddButton())
                    .help("Add file(s)")
                    .padding(.bottom)

                    Button {
                        packageListViewModel.shouldPresentConfirmationSheet = true
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(!packageListViewModel.enableFileDeleteButton(selectedDpFiles: packageListViewModel.selectedDpFiles))
                    .help("Remove selected file(s)")
                    .padding([.bottom, .trailing])
                    .sheet(isPresented: $packageListViewModel.shouldPresentConfirmationSheet) {
                        if !packageListViewModel.canceled {
                            packageListViewModel.deleteSelectedFilesFromDp()
                        }
                    } content: {
                        ConfirmationView(promptMessage: "Are you sure you want to delete the selected \(packageListViewModel.selectedDpFiles.count) items?", includeCancelButton: true, canceled: $packageListViewModel.canceled)
                    }
                }
            }
        }
        .onReceive(publisher) { notification in
            packageListViewModel.dpFiles.files.sort(using: sortOrder)
        }
    }

    func stateImage(fileItem: DpFileViewModel?) -> (systemName: String, color: Color?)? {
        guard let fileItem else { return nil }
        var colorWhenIncluded: Color? = .green
        var colorWhenDeleted: Color? = .red
        var colorWhenMismatched: Color? = .yellow
        if packageListViewModel.selectedDpFiles.count > 0 {
            if !packageListViewModel.selectedDpFiles.contains(fileItem.id) {
                colorWhenIncluded = nil
                colorWhenDeleted = nil
                colorWhenMismatched = nil
            }
        }
        switch fileItem.state {
        case .undefined:
            return nil
//            return Image(systemName: "circle.dotted")
        case .matched:
            var color: Color?
            if DataModel.shared.forceSync {
                color = colorWhenIncluded
            }
            return (systemName: "equal.circle.fill", color: color)
        case .mismatched:
            return (systemName: "checkmark.circle.fill", color: colorWhenMismatched)
        case .packageMissing:
            return (systemName: "circle", color: nil)
        case .packageMissingOnSrc:
            return (systemName: "circle", color: colorWhenDeleted)
        case .missingOnSrc:
            return (systemName: "x.circle.fill", color: colorWhenDeleted)
        case .missingOnDst:
            return (systemName: "plus.circle.fill", color: colorWhenIncluded)
        }
    }

    func startFileTransfer(fileUrls: [URL]) async {
        if let dp = packageListViewModel.retrieveSelectedDp() {
            SynchronizeProgressView(srcDp: nil, dstDp: dp, deleteFiles: false, deletePackages: false, processToExecute: { (synchronizeTask, deleteFiles, deletePackages, progress, synchronizationProgressView) in
                transferFiles(fileUrls: fileUrls, dstDp: dp, synchronizeTask: synchronizeTask, progress: progress, synchronizeProgressView: synchronizationProgressView) }).openInNewWindow { window in
                window.title = "Transfer Progress"
            }
        }
    }

    func transferFiles(fileUrls: [URL], dstDp: DistributionPoint, synchronizeTask: SynchronizeTask, progress: SynchronizationProgress, synchronizeProgressView: SynchronizeProgressView) {
        Task {
            DataModel.shared.cancelUpdateListViewModels()
            DataModel.shared.synchronizationInProgress = true
            do {
                try await dstDp.transferLocalFiles(fileUrls: fileUrls, dstDp: dstDp, jamfProInstance: DataModel.shared.findJamfProInstance(id: dstDp.jamfProInstanceId), progress: progress)
            } catch {
                LogManager.shared.logMessage(message: "Failed to transfer to \(dstDp.name): \(error)", level: .error)
            }
            DataModel.shared.synchronizationInProgress = false
            // Wait a second for the progress bar to catch up and then close
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                synchronizeProgressView.dismiss()
                DataModel.shared.updateListViewModels(reload: .none)
            })
        }
    }
}

struct PackageListView_Previews: PreviewProvider {
    static var previews: some View {
        let dataModel = DataModel()
        @StateObject var packageListViewModel = PackageListViewModel(isSrc: true)
        PackageListView(isSrc: true, dataModel: dataModel, packageListViewModel: packageListViewModel)
    }
}
