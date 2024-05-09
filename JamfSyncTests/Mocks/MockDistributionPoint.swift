//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import Foundation

struct TransferItem {
    var srcFile: DpFile
    var moveFrom: URL?
}

/// Mock for a DistributionPoint object that requires most functions to be tested
class MockDistributionPoint: DistributionPoint {
    var errors: [Error?] = []
    var errorIdx = 0
    var transferItems: [TransferItem] = []
    var filesDeleted: [DpFile] = []
    var cancelSync = false

    override func calculateTotalTransferSize(filesToSync: [DpFile]) -> Int64 {
        if cancelSync {
            cancel()
        }
        return super.calculateTotalTransferSize(filesToSync: filesToSync)
    }

    override func transferFile(srcFile: DpFile, moveFrom: URL? = nil, progress: SynchronizationProgress) async throws {
        if cancelSync {
            cancel()
            return
        }
        if errorIdx < errors.count, let error = errors[errorIdx] {
            throw error
        }
        errorIdx += 1

        transferItems.append(TransferItem(srcFile: srcFile, moveFrom: moveFrom))
    }
    
    override func deleteFile(file: DpFile, progress: SynchronizationProgress) async throws {
        filesDeleted.append(file)
    }
}
