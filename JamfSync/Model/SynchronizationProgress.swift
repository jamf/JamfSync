//
//  Copyright 2024, Jamf
//

import Foundation

class SynchronizationProgress: ObservableObject {
    var totalSize: Int64?
    @Published var operation: String?
    @Published var currentFile: DpFile?
    @Published var currentTotalSizeTransferred: Int64 = 0
    @Published var currentFileSizeTransferred: Int64?
    var overheadSizePerFile: Int = 0
    var printToConsole = false
    var showProgressOnConsole = false
    var printToConsoleInterval: TimeInterval = 1.0
    private var lastValuePrinted = ""
    private var lastPrintedTime = Date.now

    func initializeFileTransferInfoForFile(operation: String?, currentFile: DpFile?, currentTotalSizeTransferred: Int64) {
        if printToConsole, let currentFile {
            // NOTE: MainActor isn't called when processing the command line arguments since no UI is shown yet
            setInitialVars(operation: operation, currentFile: currentFile, currentTotalSizeTransferred: currentTotalSizeTransferred)
            var operationString = ""
            if let operation {
                operationString = "\(operation) "
            }
            print("\(operationString)\(currentFile.name)...")
        } else {
            Task { @MainActor in
                setInitialVars(operation: operation, currentFile: currentFile, currentTotalSizeTransferred: currentTotalSizeTransferred)
            }
        }
    }

    func updateFileTransferInfo(totalBytesTransferred: Int64, bytesTransferred: Int64) {
        if printToConsole {
            // NOTE: MainActor isn't called when processing the command line arguments since no UI is shown yet
            setFileTransferVars(totalBytesTransferred: totalBytesTransferred, bytesTransferred: bytesTransferred, progress: self)
            if showProgressOnConsole {
                printProgressToConsole()
            }
        } else {
            Task { @MainActor in
                setFileTransferVars(totalBytesTransferred: totalBytesTransferred, bytesTransferred: bytesTransferred, progress: self)
            }
        }
    }

    func finalProgressValues(totalBytesTransferred: Int64, currentTotalSizeTransferred: Int64) {
        if printToConsole {
            // NOTE: MainActor isn't called when processing the command line arguments since no UI is shown yet
            setFinalProgressValues(totalBytesTransferred: totalBytesTransferred, currentTotalSizeTransferred: currentTotalSizeTransferred)
            if showProgressOnConsole {
                printProgressToConsole()
            }
        } else {
            Task { @MainActor in
                setFinalProgressValues(totalBytesTransferred: totalBytesTransferred, currentTotalSizeTransferred: currentTotalSizeTransferred)
            }
        }
    }

    func fileProgress() -> Double? {
        if let currentFileSizeTransferred, let currentFile {
            let size = (currentFile.size ?? 0) + Int64(overheadSizePerFile)
            if size > 0 {
                return Double(currentFileSizeTransferred) / Double(size)
            }
        }
        return nil
    }

    func totalProgress() -> Double? {
        if let totalSize, totalSize > 0 {
            return Double(currentTotalSizeTransferred) / Double(totalSize)
        }
        return nil
    }

    // MARK: - Private functions

    private func printProgressToConsole() {
        guard Date.now > lastPrintedTime + printToConsoleInterval || isAt100Percent() else { return }
        var fileProgressString = ""
        var totalProgressString = ""
        if let progress = fileProgress() {
            fileProgressString = "File progress: \(Int(progress * 100.0))%\t"
        }
        if let progress = totalProgress() {
            totalProgressString = "Total progress: \(Int(progress * 100.0))%"
        }
        print("\(fileProgressString)\(totalProgressString)"/*, terminator: "\r"*/) // TODO: It looked like passing "\r" as the terminator would cause it to print the progress on top of itself, but it ended up not showing up at all. See if there is a way to fix this when we get time or inspiration.
        lastPrintedTime = Date.now
    }

    private func setInitialVars(operation: String?, currentFile: DpFile?, currentTotalSizeTransferred: Int64) {
        self.operation = operation
        self.currentFile = currentFile
        if currentFile != nil {
            self.currentFileSizeTransferred = 0
        }
        self.currentTotalSizeTransferred = currentTotalSizeTransferred
    }

    private func setFileTransferVars(totalBytesTransferred: Int64, bytesTransferred: Int64, progress: SynchronizationProgress) {
        if progress.operation == "Downloading" {
            currentFileSizeTransferred = totalBytesTransferred
            if isAt100Percent() {
                currentFileSizeTransferred = 0
            }
        } else {
            if currentFileSizeTransferred == nil {
                currentFileSizeTransferred = 0
            }
            currentFileSizeTransferred? += bytesTransferred
        }
        currentTotalSizeTransferred += bytesTransferred
    }

    private func setFinalProgressValues(totalBytesTransferred: Int64, currentTotalSizeTransferred: Int64) {
        self.currentFileSizeTransferred = totalBytesTransferred
        self.currentTotalSizeTransferred = currentTotalSizeTransferred
    }

    private func isAt100Percent() -> Bool {
        if let progress = fileProgress(), progress >= 1.0 {
            return true
        }
        if let progress = totalProgress(), progress >= 1.0 {
            return true
        }
        return false
    }
}
