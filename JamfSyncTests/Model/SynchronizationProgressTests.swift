//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import XCTest

final class SynchronizationProgressTests: XCTestCase {
    var progress: SynchronizationProgress!

    override func setUpWithError() throws {
        progress = SynchronizationProgress()
        progress.printToConsole = true // Avoids MainActor dispatching so calls are synchronous
    }

    // MARK: - fileProgress tests

    func testFileProgress_returnsNil_whenNoCurrentFile() {
        XCTAssertNil(progress.fileProgress())
    }

    func testFileProgress_returnsNil_whenCurrentFileHasNilSize() {
        progress.currentFile = DpFile(name: "test.pkg", size: nil)
        progress.currentFileSizeTransferred = 500
        XCTAssertNil(progress.fileProgress())
    }

    func testFileProgress_returnsNil_whenCurrentFileSizeTransferredIsNil() {
        progress.currentFile = DpFile(name: "test.pkg", size: 1000)
        progress.currentFileSizeTransferred = nil
        XCTAssertNil(progress.fileProgress())
    }

    func testFileProgress_returnsZero_whenNothingTransferred() {
        progress.currentFile = DpFile(name: "test.pkg", size: 1000)
        progress.currentFileSizeTransferred = 0
        XCTAssertEqual(progress.fileProgress(), 0.0)
    }

    func testFileProgress_returnsHalf_whenHalfTransferred() {
        progress.currentFile = DpFile(name: "test.pkg", size: 1000)
        progress.currentFileSizeTransferred = 500
        XCTAssertEqual(try XCTUnwrap(progress.fileProgress()), 0.5, accuracy: 0.001)
    }

    func testFileProgress_returnsOne_whenFullyTransferred() {
        progress.currentFile = DpFile(name: "test.pkg", size: 1000)
        progress.currentFileSizeTransferred = 1000
        XCTAssertEqual(try XCTUnwrap(progress.fileProgress()), 1.0, accuracy: 0.001)
    }

    func testFileProgress_includesOverhead() {
        progress.currentFile = DpFile(name: "test.pkg", size: 900)
        progress.overheadSizePerFile = 100 // effective size = 1000
        progress.currentFileSizeTransferred = 500
        XCTAssertEqual(try XCTUnwrap(progress.fileProgress()), 0.5, accuracy: 0.001)
    }

    func testFileProgress_returnsNil_whenFileSizeIsZero() {
        progress.currentFile = DpFile(name: "test.pkg", size: 0)
        progress.currentFileSizeTransferred = 0
        XCTAssertNil(progress.fileProgress())
    }

    // MARK: - totalProgress tests

    func testTotalProgress_returnsNil_whenTotalSizeIsNil() {
        progress.currentTotalSizeTransferred = 500
        XCTAssertNil(progress.totalProgress())
    }

    func testTotalProgress_returnsNil_whenTotalSizeIsZero() {
        progress.totalSize = 0
        XCTAssertNil(progress.totalProgress())
    }

    func testTotalProgress_returnsZero_whenNothingTransferred() {
        progress.totalSize = 1000
        progress.currentTotalSizeTransferred = 0
        XCTAssertEqual(progress.totalProgress(), 0.0)
    }

    func testTotalProgress_returnsHalf_whenHalfTransferred() {
        progress.totalSize = 1000
        progress.currentTotalSizeTransferred = 500
        XCTAssertEqual(try XCTUnwrap(progress.totalProgress()), 0.5, accuracy: 0.001)
    }

    func testTotalProgress_returnsOne_whenFullyTransferred() {
        progress.totalSize = 1000
        progress.currentTotalSizeTransferred = 1000
        XCTAssertEqual(try XCTUnwrap(progress.totalProgress()), 1.0, accuracy: 0.001)
    }

    // MARK: - initializeFileTransferInfoForFile tests

    func testInitializeFileTransferInfo_setsOperation() {
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: "Uploading", currentFile: file, currentTotalSizeTransferred: 0)
        XCTAssertEqual(progress.operation, "Uploading")
    }

    func testInitializeFileTransferInfo_setsCurrentFile() {
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: "Uploading", currentFile: file, currentTotalSizeTransferred: 0)
        XCTAssertEqual(progress.currentFile?.name, "test.pkg")
    }

    func testInitializeFileTransferInfo_setsTotalSizeTransferred() {
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: "Uploading", currentFile: file, currentTotalSizeTransferred: 250)
        XCTAssertEqual(progress.currentTotalSizeTransferred, 250)
    }

    func testInitializeFileTransferInfo_resetsFileSizeTransferred() {
        progress.currentFileSizeTransferred = 999
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: "Uploading", currentFile: file, currentTotalSizeTransferred: 0)
        XCTAssertEqual(progress.currentFileSizeTransferred, 0)
    }

    func testInitializeFileTransferInfo_nilOperation() {
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: nil, currentFile: file, currentTotalSizeTransferred: 0)
        XCTAssertNil(progress.operation)
    }

    // MARK: - updateFileTransferInfo tests

    func testUpdateFileTransferInfo_uploading_accumulatesBytesTransferred() {
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: "Uploading", currentFile: file, currentTotalSizeTransferred: 0)
        progress.updateFileTransferInfo(totalBytesTransferred: 300, bytesTransferred: 300)
        progress.updateFileTransferInfo(totalBytesTransferred: 600, bytesTransferred: 300)
        XCTAssertEqual(progress.currentFileSizeTransferred, 600)
    }

    func testUpdateFileTransferInfo_uploading_incrementsTotalTransferred() {
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: "Uploading", currentFile: file, currentTotalSizeTransferred: 100)
        progress.updateFileTransferInfo(totalBytesTransferred: 500, bytesTransferred: 500)
        XCTAssertEqual(progress.currentTotalSizeTransferred, 600)
    }

    func testUpdateFileTransferInfo_downloading_usesTotalBytesTransferred() {
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: "Downloading", currentFile: file, currentTotalSizeTransferred: 0)
        progress.updateFileTransferInfo(totalBytesTransferred: 400, bytesTransferred: 400)
        XCTAssertEqual(progress.currentFileSizeTransferred, 400)
    }

    func testUpdateFileTransferInfo_downloading_resetsFileSizeAt100Percent() {
        let file = DpFile(name: "test.pkg", size: 1000)
        progress.initializeFileTransferInfoForFile(operation: "Downloading", currentFile: file, currentTotalSizeTransferred: 0)
        // Transfer 100% — isAt100Percent() returns true, so currentFileSizeTransferred should reset to 0
        progress.updateFileTransferInfo(totalBytesTransferred: 1000, bytesTransferred: 1000)
        XCTAssertEqual(progress.currentFileSizeTransferred, 0)
    }

    // MARK: - finalProgressValues tests

    func testFinalProgressValues_setsFileSizeTransferred() {
        progress.finalProgressValues(totalBytesTransferred: 1000, currentTotalSizeTransferred: 5000)
        XCTAssertEqual(progress.currentFileSizeTransferred, 1000)
    }

    func testFinalProgressValues_setsTotalSizeTransferred() {
        progress.finalProgressValues(totalBytesTransferred: 1000, currentTotalSizeTransferred: 5000)
        XCTAssertEqual(progress.currentTotalSizeTransferred, 5000)
    }

    func testFinalProgressValues_overwritesPreviousValues() {
        progress.currentFileSizeTransferred = 100
        progress.currentTotalSizeTransferred = 200
        progress.finalProgressValues(totalBytesTransferred: 1000, currentTotalSizeTransferred: 5000)
        XCTAssertEqual(progress.currentFileSizeTransferred, 1000)
        XCTAssertEqual(progress.currentTotalSizeTransferred, 5000)
    }
}
