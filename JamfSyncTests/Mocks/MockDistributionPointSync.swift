//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import Foundation

/// Mock for a DistributionPoint object that mocks out calls made by SyncrhonizationTask
class MockDistributionPointSync: DistributionPoint {
    var prepareDpCalled = false
    var retrieveFileListCalled = false
    var copyFilesCalled = false
    var deleteFilesNotOnSourceCalled = false
    var prepareDpError: Error?
    var retrieveFileListError: Error?
    var copyFilesError: Error?
    var deleteFilesNotOnSourceError: Error?

    override func prepareDp() async throws {
        if let prepareDpError {
            throw prepareDpError
        }
        prepareDpCalled = true
    }

    override func retrieveFileList(limitFileTypes: Bool = true) async throws {
        if let retrieveFileListError {
            throw retrieveFileListError
        }
        retrieveFileListCalled = true
    }

    override func copyFiles(selectedItems: [DpFile], dstDp: DistributionPoint, jamfProInstance: JamfProInstance?, forceSync: Bool, progress: SynchronizationProgress) async throws {
        if let copyFilesError {
            throw copyFilesError
        }
        copyFilesCalled = true
    }

    override func deleteFilesNotOnSource(srcDp: DistributionPoint, progress: SynchronizationProgress) async throws {
        if let deleteFilesNotOnSourceError {
            throw deleteFilesNotOnSourceError
        }
        deleteFilesNotOnSourceCalled = true
    }
}
