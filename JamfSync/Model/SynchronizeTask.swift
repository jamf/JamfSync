//
//  Copyright 2024, Jamf
//

import Foundation

class SynchronizeTask {
    var activeDp: DistributionPoint?

    /// Loops through the files to synchronize to calculate the total size of files to be transferred.
    /// - Parameters:
    ///     - srcDp: The destination distribution point to copy the files from
    ///     - dstDp: The destination distribution point to copy the files to\
    ///     - selectedItems: The selected items to synchronize. If the selection list is empty, it will synchronize all files from the source distribution point
    ///     - jamfProInstance: The Jamf Pro instance of the destination distribution point, if it is associated with one
    ///     - forceSync: Set to true if it should copy files even if they are the same on both the source and destination
    ///     - deleteFiles: Set to true if it should delete files from the destination that are not on the source
    ///     - deletePackages: Set to true if it should delete packages from the Jamf Pro instance associated with the destination distribution point
    ///     - progress: The progress object that should be updated as the synchronization progresses
    /// - Returns: Returns true if the file lists need to reload files, otherwise false
    func synchronize(srcDp: DistributionPoint, dstDp: DistributionPoint, selectedItems: [DpFile], jamfProInstance: JamfProInstance?, forceSync: Bool, deleteFiles: Bool, deletePackages: Bool, progress: SynchronizationProgress) async throws -> Bool {
        activeDp = srcDp
        try await srcDp.prepareDp()
        try await srcDp.retrieveFileList()
        try await dstDp.prepareDp()
        try await dstDp.retrieveFileList()
        try await srcDp.copyFiles(selectedItems: selectedItems, dstDp: dstDp, jamfProInstance: jamfProInstance, forceSync: forceSync, progress: progress)
        if !srcDp.isCanceled && selectedItems.count == 0 {
            if deleteFiles {
                try await dstDp.deleteFilesNotOnSource(srcDp: srcDp, progress: progress)
            }
            if let jamfProInstance, deletePackages {
                try await jamfProInstance.deletePackagesNotOnSource(srcDp: srcDp, progress: progress)
            }
        }
        activeDp = nil
        return srcDp.filesWereZipped
    }

    func cancel() {
        activeDp?.cancel()
    }
}
