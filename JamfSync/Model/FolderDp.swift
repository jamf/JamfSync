//
//  Copyright 2024, Jamf
//

import Foundation

class FolderDp: DistributionPoint {
    var filePath: String = ""

    init(name: String, filePath: String, fileManager: FileManager? = nil) {
        super.init(name: name, fileManager: fileManager)
        self.filePath = filePath
    }

    override func showCalcChecksumsButton() -> Bool {
        return true
    }

    override func retrieveFileList(limitFileTypes: Bool = true) async throws {
        try await retrieveLocalFileList(localPath: filePath, limitFileTypes: limitFileTypes)
    }

    override func deleteFile(file: DpFile, progress: SynchronizationProgress) async throws {
        let fileUrl = URL(fileURLWithPath: filePath).appendingPathComponent(file.name)
        try deleteLocal(localUrl: fileUrl, progress: progress)
    }

    override func transferFile(srcFile: DpFile, moveFrom: URL? = nil, progress: SynchronizationProgress) async throws {
        try await transferLocal(localPath: filePath, srcFile: srcFile, moveFrom: moveFrom, progress: progress)
    }
}
