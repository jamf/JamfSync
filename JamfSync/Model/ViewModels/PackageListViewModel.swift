//
//  Copyright 2024, Jamf
//

import Foundation

class PackageListViewModel: ObservableObject {
    @Published var dpFiles = DpFilesViewModel()
    @Published var doChecksumCalculation = false
    @Published var selectedDpFiles: Set<DpFile.ID> = []
    @Published var shouldPresentConfirmationSheet = false
    @Published var canceled = false
    var isSrc: Bool
    private var updateTask: Task<Void, Error>?
    static let needToSortPackagesNotification = "com.jamfsoftware.jamfsync.needToSortPackages"

    init(isSrc: Bool) {
        self.isSrc = isSrc
    }

    /// Gets the files for the source and destination dps if not already done, calculates checksums, and then determines the state of each file.
    /// - Parameters:
    ///     - srcDpId: The id of the selected source dp.
    ///     - dstDpId: The id of the selected source dp.
    ///     - reload: Reload all the files and recalculate checksums.
    func update(srcDpId: UUID?, dstDpId: UUID?, checksumUpdateInProgress: Bool, reload: Bool) async throws {
        let dataModel = DataModel.shared
        let selectedSrcDp = dataModel.findDp(id: dataModel.selectedSrcDpId)
        let selectedDstDp = dataModel.findDp(id: dataModel.selectedDstDpId)
        let dp = retrieveSelectedDp()
        if !checksumUpdateInProgress, let dp {
            if reload, let jamfProInstanceId = dp.jamfProInstanceId, let jamfProInstance = dp.findJamfProInstance(id: jamfProInstanceId) {
                try await jamfProInstance.loadPackages()
            }
            await updateDpFiles(dp: dp, reload: reload)
        }

        updateTask = Task { @MainActor in
            dpFiles.removeAll()
            selectedDpFiles.removeAll()
            
            if let dp {
                for dpFile in dp.dpFiles.files {
                    let newDpFile = DpFileViewModel(dpFile: dpFile)
                    newDpFile.state = determineState(srcDp: selectedSrcDp, dstDp: selectedDstDp, dpFile: dpFile)
                    dpFiles.files.append(newDpFile)
                }
            }

            let packages = packagesForSelectedDps(dp: dp)
            dpFiles.addMissingPackages(packages: packages, isSrc: isSrc, srcDp: selectedSrcDp, dstDp: selectedDstDp)
            updateTask = nil
            NotificationCenter.default.post(name: Notification.Name(PackageListViewModel.needToSortPackagesNotification), object: self)
        }
    }

    func updateChecksums() async {
        Task { @MainActor in
            doChecksumCalculation = true
        }
        await dpFiles.updateChecksums()
        Task { @MainActor in
            doChecksumCalculation = false
        }
    }

    func cancelChecksumUpdate() {
        dpFiles.cancelChecksumUpdate = true
        doChecksumCalculation = false
    }

    func showCalcChecksumsButton() -> Bool {
        let selectedDp = retrieveSelectedDp()
        guard let selectedDp else { return false }

        return selectedDp.showCalcChecksumsButton()
    }

    func enableFileAddButton() -> Bool {
        let selectedDp = retrieveSelectedDp()
        guard let selectedDp, selectedDp.id != DataModel.noSelection else { return false }

        return true
    }

    func enableFileDeleteButton(selectedDpFiles: Set<DpFile.ID>) -> Bool {
        let selectedDp = retrieveSelectedDp()
        guard let selectedDp, selectedDp.id != DataModel.noSelection, selectedDpFiles.count > 0 else { return false }

        return true
    }

    func retrieveSelectedDp() -> DistributionPoint? {
        let dataModel = DataModel.shared
        let selectedDp: DistributionPoint?
        if isSrc {
            selectedDp = dataModel.findDp(id: dataModel.selectedSrcDpId)
        } else {
            selectedDp = dataModel.findDp(id: dataModel.selectedDstDpId)
        }

        return selectedDp
    }

    func cancelUpdate() {
        let dataModel = DataModel.shared
        if let selectedSrcDp = dataModel.findDp(id: dataModel.selectedSrcDpId) {
            selectedSrcDp.cancel()
        }
        if let selectedDstDp = dataModel.findDp(id: dataModel.selectedDstDpId) {
            selectedDstDp.cancel()
        }
        updateTask?.cancel()
        updateTask = nil
    }

    func determineDpForThisPackageList(srcDpId: UUID?, dstDpId: UUID?) -> DistributionPoint? {
        let dataModel = DataModel.shared
        let selectedSrcDp = dataModel.findDp(id: dataModel.selectedSrcDpId)
        let selectedDstDp = dataModel.findDp(id: dataModel.selectedDstDpId)
        return determineDpForThisPackageList(srcDp: selectedSrcDp, dstDp: selectedDstDp)
    }

    func determineDpForThisPackageList(srcDp: DistributionPoint?, dstDp: DistributionPoint?) -> DistributionPoint? {
        if isSrc, let srcDp {
            return srcDp
        }
        if !isSrc, let dstDp {
            return dstDp
        }
        return nil
    }

    func needsToLoadFiles(srcDpId: UUID?, dstDpId: UUID?, reload: Bool) -> Bool {
        let dp = determineDpForThisPackageList(srcDpId: srcDpId, dstDpId: dstDpId)
        return needsToLoadFiles(dp: dp, reload: reload)
    }

    func needsToLoadFiles(dp: DistributionPoint?, reload: Bool) -> Bool {
        if let dp, dp.id != DataModel.noSelection, !dp.filesLoaded || reload {
            return true
        }
        return false
    }

    func deleteSelectedFilesFromDp(packagesToo: Bool) {
        guard let selectedDp = retrieveSelectedDp() else {
            LogManager.shared.logMessage(message: "Failed to retrieve the distribution point", level: .error)
            return
        }
        Task {
            var jamfProInstance: JamfProInstance?
            if let jamfProInstanceId = selectedDp.jamfProInstanceId, let instance = selectedDp.findJamfProInstance(id: jamfProInstanceId) {
                jamfProInstance = instance
            }

            let progress = SynchronizationProgress()
            let selectedDpFiles = DataModel.shared.selectedDpFilesFromSelectionIds(packageListViewModel: self)
            for dpFile in selectedDpFiles {
                do {
                    if let jamfProInstance, let packageApi = jamfProInstance.packageApi, selectedDp.deleteByRemovingPackage {
                        if let package = jamfProInstance.findPackage(name: dpFile.name), let jamfProId = package.jamfProId {
                            try await packageApi.deletePackage(packageId: jamfProId, jamfProInstance: jamfProInstance)
                        }
                    } else {
                        try await selectedDp.deleteFile(file: dpFile, progress: progress)
                    }
                    LogManager.shared.logMessage(message: "Deleted \(dpFile.name) from \(selectedDp.selectionName())", level: .info)
                } catch {
                    LogManager.shared.logMessage(message: "Failed to deleted \(dpFile.name) from \(selectedDp.selectionName()): \(error)", level: .error)
                }
            }
            DataModel.shared.updateListViewModels(reload: isSrc ? .source : .destination)
        }
    }

    // MARK: - Private functions

    private func determineState(srcDp: DistributionPoint?, dstDp: DistributionPoint?, dpFile: DpFile) -> FileState {
        guard let srcDp, srcDp.id != DataModel.noSelection, let dstDp, dstDp.id != DataModel.noSelection else { return .undefined }
        if isSrc {
            if let fileFound = dstDp.dpFiles.findDpFile(name: dpFile.name) {
                return fileFound == dpFile ? .matched : .mismatched
            } else {
                return .missingOnDst
            }
        } else {
            if let fileFound = srcDp.dpFiles.findDpFile(name: dpFile.name) {
                return fileFound == dpFile ? .matched : .mismatched
            } else {
                return .missingOnSrc
            }
        }
    }

    private func updateDpFiles(dp: DistributionPoint?, reload: Bool) async {
        guard let dp, needsToLoadFiles(dp: dp, reload: reload) else { return }
        let dataModel = DataModel.shared
        if dp.needsToPromptForPassword(), let fileShareDp = dp as? FileShareDp {
            Task { @MainActor in
                dataModel.dpToPromptForPassword = fileShareDp
                dataModel.shouldPromptForDpPassword = true
            }
        } else {
            do {
                try await dp.retrieveFileList()
            } catch {
                LogManager.shared.logMessage(message: "Failed to load the \(dp.selectionName()) distribution point: \(error)", level: .error)
            }
        }
    }

    private func packagesForSelectedDps(dp: DistributionPoint?) -> [Package]? {
        guard let dp else { return nil }
        let dataModel = DataModel.shared
        let savableItem = dataModel.savableItems.findSavableItemWithDpId(id: dp.id)
        return savableItem?.jamfProPackages()
    }
}
