//
//  Copyright 2024, Jamf
//

import SwiftUI
import Combine

enum ReloadFiles {
    case none
    case source
    case destination
    case sourceAndDestination

    func shouldReloadSource() -> Bool {
        return self == .source || self == .sourceAndDestination
    }

    func shouldReloadDestination() -> Bool {
        return self == .destination || self == .sourceAndDestination
    }
}

class DataModel: ObservableObject {
    static let noSelection = UUID()
    static let shared = DataModel()
    @Published var settingsViewModel = SettingsViewModel()
    @Published var srcPackageListViewModel = PackageListViewModel(isSrc: true)
    @Published var dstPackageListViewModel = PackageListViewModel(isSrc: false)
    @Published var savableItems: SavableItems = SavableItems()
    @Published var dpsForSource: [DistributionPoint] = []
    @Published var dpsForDestination: [DistributionPoint] = []
    @Published var selectedSrcDpId = DataModel.noSelection
    @Published var selectedDstDpId = DataModel.noSelection
    @Published var forceSync = false
    @Published var dryRun = false
    @Published var showSpinner = false
    @Published var shouldPromptForDpPassword = false
    @Published var dpToPromptForPassword: FileShareDp?
    @Published var shouldPromptForJamfProPassword = false
    @Published var shouldPresentSetupSheet = false
    @Published var shouldPresentServerSelectionSheet = false
    @Published var synchronizationInProgress = false
    private var dps: [DistributionPoint] = []
    var firstLoad = true
    var promptedForJamfProInstances = false
    var jamfProServersToPromptForPassword: [JamfProInstance] = []
    var loadingInProgressGroup: DispatchGroup?
    private var updateListViewModelsTask: Task<Void, Error>?
    private var updateChecksumsTask: Task<Void, Error>?

    func load(dataPersistence: DataPersistence) {
        savableItems = dataPersistence.loadSavableItems()
        if firstLoad && !promptedForJamfProInstances && settingsViewModel.promptForJamfProInstances {
            shouldPresentServerSelectionSheet = true
            promptedForJamfProInstances = true
        } else {
            loadDps()
        }
    }

    func loadDps() {
        loadingInProgressGroup?.enter()
        Task {
            if loadingInProgressGroup == nil {
                await MainActor.run {
                    showSpinner = true
                    dps.removeAll()
                    dps.append(DistributionPoint(name: "--", id: DataModel.noSelection))
                }
            }
            jamfProServersToPromptForPassword.removeAll()

            if firstLoad {
                firstLoad = false
                if savableItems.items.count == 0 {
                    Task { @MainActor in
                        shouldPresentSetupSheet = true
                        showSpinner = false
                    }
                    return
                }
            }

            for savableItem in savableItems.items {
                do {
                    var loadDps = true
                    if let jamfProInstance = savableItem as? JamfProInstance {
                        await jamfProInstance.loadKeychainData()
                        if !jamfProInstance.usernameOrClientId.isEmpty, jamfProInstance.passwordOrClientSecret.isEmpty {
                            jamfProServersToPromptForPassword.append(jamfProInstance)
                            loadDps = false
                        }
                    }
                    if loadDps {
                        var serverInfo = ""
                        if let jamfProInstance = savableItem as? JamfProInstance {
                            serverInfo = "\(jamfProInstance.displayName()) (\(jamfProInstance.url?.absoluteString ?? ""))"
                        }
                        do {
                            try await savableItem.loadDps()
                        } catch ServerCommunicationError.forbidden {
                            LogManager.shared.logMessage(message: "Bad credentials or access \(serverInfo)", level: .error)
                        } catch ServerCommunicationError.couldNotAccessServer {
                            LogManager.shared.logMessage(message: "Failed to access \(serverInfo)", level: .error)
                        } catch ServerCommunicationError.invalidCredentials {
                            if let jamfProInstance = savableItem as? JamfProInstance {
                                jamfProServersToPromptForPassword.append(jamfProInstance)
                                jamfProInstance.passwordOrClientSecret = ""
                            }
                        }
                    }
                } catch {
                    LogManager.shared.logMessage(message: "Failed to load data from the \(savableItem.displayInfo()): \(error)", level: .error)
                }

                dps.append(contentsOf: savableItem.getDps())
                Task { @MainActor in
                    // This is just so the selection items will be updated as items are loaded
                    updateDpsForSourceAndDestination()
                }
            }
            loadingInProgressGroup?.leave()
            Task { @MainActor in
                if !jamfProServersToPromptForPassword.isEmpty {
                    shouldPromptForJamfProPassword = true
                }
                showSpinner = false
                updateDpsForSourceAndDestination()
                verifySelectedItemsStillExist()
            }
        }
    }

    func findDp(id: UUID?) -> DistributionPoint? {
        return dps.first { $0.id == id }
    }

    func findSrcDp(id: UUID?) -> DistributionPoint? {
        return dpsForSource.first { $0.id == id }
    }

    func findDstDp(id: UUID?) -> DistributionPoint? {
        return dpsForDestination.first { $0.id == id }
    }

    func findDpByCombinedName(name: String) -> DistributionPoint? {
        let nameParts = name.components(separatedBy: ":")
        guard nameParts.count > 0 else { return nil }
        if nameParts.count == 1 {
            return findDp(name: name)
        }
        let name = nameParts[0]
        let serverName = nameParts[1]
        return findDp(name: name, jamfProInstanceName: serverName)
    }

    func updateListViewModels(doChecksumCalculation: Bool = false, checksumUpdateInProgress: Bool = false, reload: ReloadFiles = .none) {
        if updateListViewModelsTask == nil {
            updateListViewModelsTask = Task {
                // NOTE: Need to update the destination first so that the files are present.
                // This ensures that the icons for the source are updated properly.
                // Then the destination needs to be re-updated after the source files are present.
                if !checksumUpdateInProgress && dstPackageListViewModel.needsToLoadFiles(srcDpId: selectedSrcDpId, dstDpId: selectedDstDpId, reload: reload.shouldReloadDestination()) {
                    await updateDstListViewModel(checksumUpdateInProgress: checksumUpdateInProgress, reload: reload.shouldReloadDestination())
                }
                await updateSrcListViewModel(checksumUpdateInProgress: checksumUpdateInProgress, reload: reload.shouldReloadSource())
                await updateDstListViewModel(checksumUpdateInProgress: checksumUpdateInProgress, reload: false)
                updateListViewModelsTask = nil
            }
        }
    }

    func cancelUpdateListViewModels() {
        srcPackageListViewModel.cancelUpdate()
        dstPackageListViewModel.cancelUpdate()
        updateListViewModelsTask?.cancel()
        updateListViewModelsTask = nil
    }

    func findJamfProInstance(id: UUID?) -> JamfProInstance? {
        guard let id else { return nil }
        return savableItems.items.first { $0.id == id } as? JamfProInstance
    }

    func cleanup() async throws {
        for dp in dps {
            try await dp.cleanupDp()
        }
    }

    func synchronizationDisabled() -> Bool {
        return synchronizationInProgress || selectedSrcDpId == DataModel.noSelection || selectedDstDpId == DataModel.noSelection || selectedSrcDpId == selectedDstDpId
    }

    func verifySelectedItemsStillExist() {
        verifySrcSelectedItemsStillExist()
        verifyDstSelectedItemsStillExist()
    }

    func selectedDpFilesFromSelectionIds(packageListViewModel: PackageListViewModel) -> [DpFile] {
        var selectedFiles: [DpFile] = []
        for id in packageListViewModel.selectedDpFiles {
            if let viewModel = packageListViewModel.dpFiles.findDpFileViewModel(id: id) {
                selectedFiles.append(viewModel.dpFile)
            }
        }
        return selectedFiles
    }

    // MARK: Private functions

    private func updateDpsForSourceAndDestination() {
        dpsForSource.removeAll()
        dpsForDestination.removeAll()
        for dp in dps {
            if dp.readWrite.readSupported() {
                dpsForSource.append(dp)
            }
            if dp.readWrite.writeSupported() {
                dpsForDestination.append(dp)
            }
        }
    }

    private func verifySrcSelectedItemsStillExist() {
        if selectedSrcDpId != DataModel.noSelection && findSrcDp(id: selectedSrcDpId) == nil {
            selectedSrcDpId = DataModel.noSelection
        }
    }

    private func verifyDstSelectedItemsStillExist() {
        if selectedDstDpId != DataModel.noSelection && findDstDp(id: selectedDstDpId) == nil {
            selectedDstDpId = DataModel.noSelection
        }
    }

    private func findDp(name: String, jamfProInstanceName: String? = nil) -> DistributionPoint? {
        if let jamfProInstanceName {
            return dps.first { $0.name == name && $0.jamfProInstanceName == jamfProInstanceName }
        }
        return dps.first { $0.name == name }
    }

    private func updateSrcListViewModel(checksumUpdateInProgress: Bool = false, reload: Bool = false) async {
        do {
            try await srcPackageListViewModel.update(srcDpId: selectedSrcDpId, dstDpId: selectedDstDpId, checksumUpdateInProgress: checksumUpdateInProgress, reload: reload)
        } catch {
            LogManager.shared.logMessage(message: "Failed to update the view for the source: \(error)", level: .error)
        }
    }

    private func updateDstListViewModel(doChecksumCalculation: Bool = false, checksumUpdateInProgress: Bool = false, reload: Bool = false) async {
        do {
            try await dstPackageListViewModel.update(srcDpId: selectedSrcDpId, dstDpId: selectedDstDpId, checksumUpdateInProgress: checksumUpdateInProgress, reload: reload)
        } catch {
            LogManager.shared.logMessage(message: "Failed to update the view for the destination: \(error)", level: .error)
        }
    }
}
