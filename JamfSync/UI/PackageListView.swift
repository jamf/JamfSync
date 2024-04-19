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
            Table(packageListViewModel.dpFiles.files, selection: $dataModel.selectedDpFiles, sortOrder: $sortOrder) {
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
            .onChange(of: dataModel.selectedDpFiles) {
                dataModel.adjustSelectedItems()
            }

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
                .padding([.bottom])
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
        if dataModel.selectedDpFiles.count > 0 {
            if !dataModel.selectedDpFiles.contains(fileItem.id) {
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
}

struct PackageListView_Previews: PreviewProvider {
    static var previews: some View {
        let dataModel = DataModel()
        @StateObject var packageListViewModel = PackageListViewModel(isSrc: true)
        PackageListView(isSrc: true, dataModel: dataModel, packageListViewModel: packageListViewModel)
    }
}
