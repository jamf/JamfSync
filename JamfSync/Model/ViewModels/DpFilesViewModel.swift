//
//  Copyright 2024, Jamf
//

import Foundation

class DpFilesViewModel: ObservableObject {
    @Published var files: [DpFileViewModel] = []
    var cancelChecksumUpdate = false

    func removeAll() {
        self.files.removeAll()
    }

    func showChecksumSpinner(dpFile: DpFileViewModel, show: Bool) {
       Task { @MainActor in
           dpFile.showChecksumSpinner = show
       }
    }

    func addMissingPackages(packages: [Package]?, isSrc: Bool, srcDp: DistributionPoint?, dstDp: DistributionPoint?) {
        guard let packages else { return }
        for package in packages {
            let fileState = determineStateForPackage(package: package, isSrc: isSrc, srcDp: srcDp, dstDp: dstDp)
            if fileState != .undefined {
                files.append(DpFileViewModel(dpFile: DpFile(name: package.fileName, size: package.size, checksums: package.checksums), state: fileState))
            }
        }
    }

    func determineStateForPackage(package: Package, isSrc: Bool, srcDp: DistributionPoint?, dstDp: DistributionPoint?) -> FileState {
        var fileState: FileState = .undefined
        // If this is the source, then just set as missing if it's not found on the source files
        if isSrc {
            if srcDp?.dpFiles.findDpFile(name: package.fileName) == nil {
                fileState = .packageMissing
            }
        } else {
            if let dstDp {
                if let srcDp, srcDp.id != DataModel.noSelection {
                    if srcDp.dpFiles.findDpFile(name: package.fileName) == nil && dstDp.dpFiles.findDpFile(name: package.fileName) == nil {
                        fileState = .packageMissingOnSrc
                    }
                } else {
                    if dstDp.dpFiles.findDpFile(name: package.fileName) == nil {
                        fileState = .packageMissing
                    }
                }
            }
        }
        return fileState
    }

    func updateChecksums() async {
        cancelChecksumUpdate = false
        for file in files {
            guard !cancelChecksumUpdate else { return }
            guard file.dpFile.checksums.findChecksum(type: .SHA_512) == nil else { continue }
            if let fileUrl = file.dpFile.fileUrl, !fileUrl.isDirectory, let filePath = fileUrl.path().removingPercentEncoding {
                showChecksumSpinner(dpFile: file, show: true)
                do {
                    let hashValue = try await FileHash.shared.createSHA512Hash(filePath: filePath)
                    if let hashValue {
                        let checksum = Checksum(type: .SHA_512, value: hashValue)
                        file.dpFile.checksums.updateChecksum(checksum)
                   }
                } catch {
                    LogManager.shared.logMessage(message: "Failed to calculated the checksum for file \(file.dpFile.fileUrl?.path ?? ""): \(error)", level: .error)
                }
                DataModel.shared.updateListViewModels(checksumUpdateInProgress: true)
                showChecksumSpinner(dpFile: file, show: false)
            }
        }
    }

    func findDpFileViewModel(id: UUID) -> DpFileViewModel? {
        return files.first { $0.id == id }
    }

    func findDpFile(id: UUID) -> DpFileViewModel? {
        return files.first { $0.dpFile.id == id }
    }

    func findDpFile(name: String) -> DpFileViewModel? {
        return files.first { $0.dpFile.name == name }
    }
}
