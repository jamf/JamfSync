//
//  Copyright 2024, Jamf
//

import Foundation

class CommandLineProcessing {
    let dataModel: DataModel
    let dataPersistence: DataPersistence

    init(dataModel: DataModel, dataPersistence: DataPersistence) {
        self.dataModel = dataModel
        self.dataPersistence = dataPersistence
    }

    func process(argumentParser: ArgumentParser) -> Bool {
        guard let srcDpName = argumentParser.srcDp, let dstDpName = argumentParser.dstDp else {
            print("Both a source and a destination must be specified")
            return false
        }

        print("Loading distribution points")
        dataModel.loadingInProgressGroup = DispatchGroup()
        dataModel.load(dataPersistence: dataPersistence, isProcessingCommandLine: true)
        dataModel.loadingInProgressGroup?.wait()

        guard let srcDp = dataModel.findDpByCombinedName(name: srcDpName) else {
            print("Couldn't find the source distribution point or folder: \(srcDpName)")
            return false
        }
        guard let dstDp = dataModel.findDpByCombinedName(name: dstDpName) else {
            print("Couldn't find the destination distribution point or folder: \(dstDpName)")
            return false
        }

        dataModel.synchronizationInProgress = true
        let synchronizeTask = SynchronizeTask()
        let synchronizationInProgressGroup = DispatchGroup()
        synchronizationInProgressGroup.enter()
        let progress = SynchronizationProgress()
        progress.printToConsole = true
        progress.showProgressOnConsole = argumentParser.showProgress
        Task {
            do {
                _ = try await synchronizeTask.synchronize(srcDp: srcDp, dstDp: dstDp, selectedItems: [], jamfProInstance: self.dataModel.findJamfProInstance(id: dstDp.jamfProInstanceId), forceSync: argumentParser.forceSync, deleteFiles: argumentParser.removeFilesNotOnSrc, deletePackages: argumentParser.removePackagesNotOnSrc, progress: progress, dryRun: argumentParser.dryRun)
            } catch {
                LogManager.shared.logMessage(message: "Failed to synchronize \(srcDp) to \(dstDp): \(error)", level: .error)
                return false
            }
            self.dataModel.synchronizationInProgress = false
            synchronizationInProgressGroup.leave()
            return true
        }
        synchronizationInProgressGroup.wait()
        return true
    }
}
