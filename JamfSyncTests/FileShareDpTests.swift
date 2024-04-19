//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import XCTest

final class FileShareDpTests: XCTestCase {
    let mockFileManager = MockFileManager()
    var fileShareDp: FileShareDp!

    override func setUpWithError() throws {
        fileShareDp = FileShareDp(jamfProId: 1, name: "FileShareDp", address: "https://file.share/dp", isMaster: true, connectionType: .smb, shareName: "CasperShare", workgroupOrDomain: "Workgroup", sharePort: 139, readOnlyUsername: "casperInstall", readOnlyPassword: "superSecretReadOnlyPassword", readWriteUsername: "casperAdmin", readWritePassword: "superSecretAdminPassword")
        fileShareDp.fileManager = mockFileManager
    }

    // MARK: - Initialization tests

    func test_initWithFullParams() throws {
        // When the fileShareDp created in setUpWithError

        // Then
        XCTAssertEqual(fileShareDp.name, "FileShareDp")
        XCTAssertEqual(fileShareDp.jamfProId, 1)
        XCTAssertEqual(fileShareDp.address, "https://file.share/dp")
        XCTAssertEqual(fileShareDp.isMaster, true)
        XCTAssertEqual(fileShareDp.connectionType, .smb)
        XCTAssertEqual(fileShareDp.shareName, "CasperShare")
        XCTAssertEqual(fileShareDp.workgroupOrDomain, "Workgroup")
        XCTAssertEqual(fileShareDp.sharePort, 139)
        XCTAssertEqual(fileShareDp.readOnlyUsername, "casperInstall")
        XCTAssertEqual(fileShareDp.readOnlyPassword, "superSecretReadOnlyPassword")
        XCTAssertEqual(fileShareDp.readWriteUsername, "casperAdmin")
        XCTAssertEqual(fileShareDp.readWritePassword, "superSecretAdminPassword")
    }

    func test_initWithDefaultJsonDpDetailDefaults() throws {
        // Given
        let jsonDpDetail = JsonDpDetail()

        // When
        let fileShareDp = FileShareDp(JsonDpDetail: jsonDpDetail)

        // Then
        XCTAssertEqual(fileShareDp.name, "")
        XCTAssertEqual(fileShareDp.jamfProId, -1)
        XCTAssertNil(fileShareDp.address)
        XCTAssertEqual(fileShareDp.isMaster, false)
        XCTAssertEqual(fileShareDp.connectionType, .smb)
        XCTAssertNil(fileShareDp.shareName)
        XCTAssertNil(fileShareDp.workgroupOrDomain, "Workgroup")
        XCTAssertNil(fileShareDp.sharePort)
        XCTAssertNil(fileShareDp.readOnlyUsername)
        XCTAssertNil(fileShareDp.readOnlyPassword)
        XCTAssertNil(fileShareDp.readWriteUsername)
        XCTAssertNil(fileShareDp.readWritePassword)
    }

    func test_initWithDefaultJsonDpDetailAllFilled_smb() throws {
        // Given
        var jsonDpDetail = JsonDpDetail()
        jsonDpDetail.connection_type = "SMB"
        jsonDpDetail.name = "FileShareDp"
        jsonDpDetail.id = 1
        jsonDpDetail.ip_address = "https://file.share/dp"
        jsonDpDetail.is_master = true
        jsonDpDetail.read_only_username = "casperInstall"
        jsonDpDetail.read_write_username = "casperAdmin"
        jsonDpDetail.share_name = "CasperShare"
        jsonDpDetail.share_port = 139
        jsonDpDetail.workgroup_or_domain = "Workgroup"

        // When
        let fileShareDp = FileShareDp(JsonDpDetail: jsonDpDetail)

        // Then
        XCTAssertEqual(fileShareDp.name, "FileShareDp")
        XCTAssertEqual(fileShareDp.jamfProId, 1)
        XCTAssertEqual(fileShareDp.address, "https://file.share/dp")
        XCTAssertEqual(fileShareDp.isMaster, true)
        XCTAssertEqual(fileShareDp.connectionType, .smb)
        XCTAssertEqual(fileShareDp.shareName, "CasperShare")
        XCTAssertEqual(fileShareDp.workgroupOrDomain, "Workgroup")
        XCTAssertEqual(fileShareDp.sharePort, 139)
        XCTAssertEqual(fileShareDp.readOnlyUsername, "casperInstall")
        XCTAssertNil(fileShareDp.readOnlyPassword)
        XCTAssertEqual(fileShareDp.readWriteUsername, "casperAdmin")
        XCTAssertNil(fileShareDp.readWritePassword)
    }

    func test_initWithDefaultJsonDpDetailAllFilled_afp() throws {
        // Given
        var jsonDpDetail = JsonDpDetail()
        jsonDpDetail.connection_type = "AFP"
        jsonDpDetail.name = "FileShareDp"
        jsonDpDetail.id = 1
        jsonDpDetail.ip_address = "https://file.share/dp"
        jsonDpDetail.is_master = true
        jsonDpDetail.read_only_username = "casperInstall"
        jsonDpDetail.read_write_username = "casperAdmin"
        jsonDpDetail.share_name = "CasperShare"
        jsonDpDetail.share_port = 139
        jsonDpDetail.workgroup_or_domain = "Workgroup"

        // When
        let fileShareDp = FileShareDp(JsonDpDetail: jsonDpDetail)

        // Then
        XCTAssertEqual(fileShareDp.name, "FileShareDp")
        XCTAssertEqual(fileShareDp.jamfProId, 1)
        XCTAssertEqual(fileShareDp.address, "https://file.share/dp")
        XCTAssertEqual(fileShareDp.isMaster, true)
        XCTAssertEqual(fileShareDp.connectionType, .afp)
        XCTAssertEqual(fileShareDp.shareName, "CasperShare")
        XCTAssertEqual(fileShareDp.workgroupOrDomain, "Workgroup")
        XCTAssertEqual(fileShareDp.sharePort, 139)
        XCTAssertEqual(fileShareDp.readOnlyUsername, "casperInstall")
        XCTAssertNil(fileShareDp.readOnlyPassword)
        XCTAssertEqual(fileShareDp.readWriteUsername, "casperAdmin")
        XCTAssertNil(fileShareDp.readWritePassword)
    }

    func test_initWithDefaultJsonDpDetailAllFilled_unknownConnectionType() throws {
        // Given
        var jsonDpDetail = JsonDpDetail()
        jsonDpDetail.connection_type = "bolts"
        jsonDpDetail.name = "FileShareDp"
        jsonDpDetail.id = 1
        jsonDpDetail.ip_address = "https://file.share/dp"
        jsonDpDetail.is_master = true
        jsonDpDetail.read_only_username = "casperInstall"
        jsonDpDetail.read_write_username = "casperAdmin"
        jsonDpDetail.share_name = "CasperShare"
        jsonDpDetail.share_port = 139
        jsonDpDetail.workgroup_or_domain = "Workgroup"

        // When
        let fileShareDp = FileShareDp(JsonDpDetail: jsonDpDetail)

        // Then
        XCTAssertEqual(fileShareDp.name, "FileShareDp")
        XCTAssertEqual(fileShareDp.jamfProId, 1)
        XCTAssertEqual(fileShareDp.address, "https://file.share/dp")
        XCTAssertEqual(fileShareDp.isMaster, true)
        XCTAssertEqual(fileShareDp.connectionType, .smb)
        XCTAssertEqual(fileShareDp.shareName, "CasperShare")
        XCTAssertEqual(fileShareDp.workgroupOrDomain, "Workgroup")
        XCTAssertEqual(fileShareDp.sharePort, 139)
        XCTAssertEqual(fileShareDp.readOnlyUsername, "casperInstall")
        XCTAssertNil(fileShareDp.readOnlyPassword)
        XCTAssertEqual(fileShareDp.readWriteUsername, "casperAdmin")
        XCTAssertNil(fileShareDp.readWritePassword)
    }

    // MARK: - prepareDp tests

    func test_prepareDp_happyPath() throws {
        // Given
        let type: ConnectionType = .smb
        let address = "https://mount.point"
        let shareName = "CasperShare"
        let username = "casperadmin"
        let password = "supersecretpassword"
        let mountPoint = "/Volumes/CasperShare"
        fileShareDp.connectionType = type
        fileShareDp.address = address
        fileShareDp.shareName = shareName
        fileShareDp.readWriteUsername = username
        fileShareDp.readWritePassword = password

        let expectationCompleted = XCTestExpectation()
        Task {
            await FileShares.shared.alreadyMounted(type: .smb, address: address, shareName: shareName, username: username, password: password, mountPoint: mountPoint)

            // When
            try await fileShareDp.prepareDp()

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(fileShareDp.localPath, "\(mountPoint)/Packages/")
    }

    func test_prepareDp_noPackagesDirectory() throws {
        // Given
        let type: ConnectionType = .smb
        let address = "https://mount.point"
        let shareName = "CasperShare"
        let username = "casperadmin"
        let password = "supersecretpassword"
        let mountPoint = "/Volumes/CasperShare"
        fileShareDp.connectionType = type
        fileShareDp.address = address
        fileShareDp.shareName = shareName
        fileShareDp.readWriteUsername = username
        fileShareDp.readWritePassword = password
        mockFileManager.fileExistsResponse = false

        let expectationCompleted = XCTestExpectation()
        Task {
            await FileShares.shared.alreadyMounted(type: .smb, address: address, shareName: shareName, username: username, password: password, mountPoint: mountPoint)

            // When
            try await fileShareDp.prepareDp()

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(fileShareDp.localPath, "\(mountPoint)/Packages/")
        XCTAssertEqual(mockFileManager.directoryCreated, URL(filePath: mountPoint).appending(component: "Packages/"))
    }

    func test_prepareDp_packagesDirectoryCreationFailed() throws {
        // Given
        let type: ConnectionType = .smb
        let address = "https://mount.point"
        let shareName = "CasperShare"
        let username = "casperadmin"
        let password = "supersecretpassword"
        let mountPoint = "/Volumes/CasperShare"
        fileShareDp.connectionType = type
        fileShareDp.address = address
        fileShareDp.shareName = shareName
        fileShareDp.readWriteUsername = username
        fileShareDp.readWritePassword = password
        mockFileManager.fileExistsResponse = false
        mockFileManager.createDirectoryError = TestErrors.SomethingWentHaywire

        let expectationCompleted = XCTestExpectation()
        Task {
            await FileShares.shared.alreadyMounted(type: .smb, address: address, shareName: shareName, username: username, password: password, mountPoint: mountPoint)

            // When
            do {
                try await fileShareDp.prepareDp()

                // Then
                XCTFail("Should have thrown an exception")
            } catch TestErrors.SomethingWentHaywire {
                // All good
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_prepareDp_noAddress() throws {
        // Given
        fileShareDp.connectionType = .smb
        fileShareDp.address = nil
        fileShareDp.shareName = "CasperShare"
        fileShareDp.readWriteUsername = "casperadmin"
        fileShareDp.readWritePassword = "supersecretpassword"

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await fileShareDp.prepareDp()

                // Then
                XCTFail("Should have thrown a FileShareMountFailure.addressMissing exception")
            } catch FileShareMountFailure.addressMissing {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_prepareDp_noShareName() throws {
        // Given
        fileShareDp.connectionType = .smb
        fileShareDp.address = "https://mount.point"
        fileShareDp.shareName = nil
        fileShareDp.readWriteUsername = "casperadmin"
        fileShareDp.readWritePassword = "supersecretpassword"

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await fileShareDp.prepareDp()

                // Then
                XCTFail("Should have thrown a FileShareMountFailure.shareNameMissing exception")
            } catch FileShareMountFailure.shareNameMissing {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_prepareDp_noUsername() throws {
        // Given
        fileShareDp.connectionType = .smb
        fileShareDp.address = "https://mount.point"
        fileShareDp.shareName = "CasperShare"
        fileShareDp.readWriteUsername = nil
        fileShareDp.readWritePassword = "supersecretpassword"

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await fileShareDp.prepareDp()

                // Then
                XCTFail("Should have thrown a FileShareMountFailure.addressMissing exception")
            } catch FileShareMountFailure.noUsername {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_prepareDp_noPassword() throws {
        // Given
        fileShareDp.connectionType = .smb
        fileShareDp.address = "https://mount.point"
        fileShareDp.shareName = "CasperShare"
        fileShareDp.readWriteUsername = "casperadmin"
        fileShareDp.readWritePassword = nil

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await fileShareDp.prepareDp()

                // Then
                XCTFail("Should have thrown a FileShareMountFailure.addressMissing exception")
            } catch FileShareMountFailure.noPassword {
                // All good
            }

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - cleanupDp tests

    func test_cleanupDp() throws {
        // Given
        let type: ConnectionType = .smb
        let address = "https://mount.point"
        let shareName = "CasperShare"
        let username = "casperadmin"
        let password = "supersecretpassword"
        let mountPoint = "/Volumes/CasperShare/"
        fileShareDp.connectionType = type
        fileShareDp.address = address
        fileShareDp.shareName = shareName
        fileShareDp.readWriteUsername = username
        fileShareDp.readWritePassword = password
        fileShareDp.fileShare = FileShare(type: type, address: address, shareName: shareName, username: username, password: password, mountPoint: mountPoint, fileManager: mockFileManager)

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await fileShareDp.cleanupDp()

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(mockFileManager.unmountedMountPoint, URL(fileURLWithPath: mountPoint))
    }


    // MARK: - retrieveFileList tests

    func test_retrieveFileList_happyPath() throws {
        // Given
        let type: ConnectionType = .smb
        let address = "https://mount.point"
        let shareName = "CasperShare"
        let username = "casperadmin"
        let password = "supersecretpassword"
        let mountPoint = "/Volumes/CasperShare"
        fileShareDp.connectionType = type
        fileShareDp.address = address
        fileShareDp.shareName = shareName
        fileShareDp.readWriteUsername = username
        fileShareDp.readWritePassword = password
        let path = "\(mountPoint)/Packages/"
        let happyFunPackage = "HappyFunPackage.pkg"
        let notSoGoodToUploadFile = "NotSoGoodToUpload.file"
        let superSadDmg = "SuperSad.dmg"
        mockFileManager.directoryContents = [URL(fileURLWithPath: path + happyFunPackage), URL(fileURLWithPath: path + notSoGoodToUploadFile), URL(fileURLWithPath: path + superSadDmg)]
        mockFileManager.fileAttributes = [path + happyFunPackage : [.size : Int64(12345678)], path + superSadDmg : [.size : Int64(456)]]

        let expectationCompleted = XCTestExpectation()
        Task {
            await FileShares.shared.alreadyMounted(type: .smb, address: address, shareName: shareName, username: username, password: password, mountPoint: mountPoint)

            // When
            try await fileShareDp.retrieveFileList()

            // Then
            XCTAssertTrue(fileShareDp.filesLoaded)
            XCTAssertEqual(fileShareDp.dpFiles.files.count, 2)
            if fileShareDp.dpFiles.files.count == 2 {
                XCTAssertEqual(fileShareDp.dpFiles.files[0].name, happyFunPackage)
                XCTAssertEqual(fileShareDp.dpFiles.files[0].size, 12345678)
                XCTAssertEqual(fileShareDp.dpFiles.files[1].name, superSadDmg)
                XCTAssertEqual(fileShareDp.dpFiles.files[1].size, 456)
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_retrieveFileList_notMounted() throws {
        // Given
        guard let address = fileShareDp.address, let shareName = fileShareDp.shareName, let username = fileShareDp.readWriteUsername, let password = fileShareDp.readWritePassword else { throw TestErrors.SomethingWentHaywire }

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                await FileShares.shared.alreadyMounted(type: fileShareDp.connectionType, address: address, shareName: shareName, username: username, password: password, mountPoint: nil)

                // When
                try await fileShareDp.retrieveFileList()

                // Then
                XCTFail("It should have failed with a DistributionPointError.cannotGetFileList exception")
            } catch DistributionPointError.cannotGetFileList {
                // All good
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - transferFile tests

    func test_transferFile() throws {
        // Given
        let localPath = "/dst/path"
        fileShareDp.localPath = localPath
        let fileName = "fileName.pkg"
        let srcFile = DpFile(name: fileName, fileUrl: URL(fileURLWithPath: "/src/path/fileName.pkg"), size: 123456789)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // So it will update before the test is over
        synchronizationProgress.currentTotalSizeTransferred = 1234

        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await fileShareDp.transferFile(srcFile: srcFile, moveFrom: nil, progress: synchronizationProgress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(mockFileManager.itemRemoved, URL(fileURLWithPath: "/dst/path/fileName.pkg"))
        XCTAssertEqual(mockFileManager.srcItemCopied, URL(fileURLWithPath: "/src/path/fileName.pkg"))
        XCTAssertEqual(mockFileManager.dstItemCopied, URL(fileURLWithPath: "/dst/path/fileName.pkg"))
        XCTAssertEqual(synchronizationProgress.currentFileSizeTransferred, 123456789)
        XCTAssertEqual(synchronizationProgress.currentTotalSizeTransferred, 123458023)
    }

    func test_transferFile_notMounted() throws {
        // Given
        fileShareDp.localPath = nil
        let fileName = "fileName.pkg"
        let srcFile = DpFile(name: fileName, fileUrl: URL(fileURLWithPath: "/src/path/fileName.pkg"), size: 123456789)
        let synchronizationProgress = SynchronizationProgress()
        synchronizationProgress.printToConsole = true // So it will update before the test is over
        synchronizationProgress.currentTotalSizeTransferred = 1234

        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await fileShareDp.transferFile(srcFile: srcFile, moveFrom: nil, progress: synchronizationProgress)

                // Then
                XCTFail("It should have failed with a DistributionPointError.cannotGetFileList exception")
            } catch DistributionPointError.cannotGetFileList {
                // All good
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - deleteFile tests

    func test_deleteFile_succeeded()  throws {
        // Given
        let fileName = "fileName"
        let fileUrl = URL(fileURLWithPath: "/Source/Path/\(fileName)")
        let dpFile = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(123456), checksums: nil)
        let synchronizationProgress = SynchronizationProgress()
        fileShareDp.localPath = "/Volumes/CasperShare/Packages"
        let expectationCompleted = XCTestExpectation()
        Task {
            // When
            try await fileShareDp.deleteFile(file: dpFile, progress: synchronizationProgress)

            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)

        // Then
        XCTAssertEqual(mockFileManager.itemRemoved, URL(fileURLWithPath: fileShareDp.localPath!).appendingPathComponent(fileName))
    }

    func test_deleteFile_failedNoLocalPath()  throws {
        // Given
        let fileName = "fileName"
        let fileUrl = URL(fileURLWithPath: "/Source/Path/\(fileName)")
        let dpFile = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(123456), checksums: nil)
        let synchronizationProgress = SynchronizationProgress()
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await fileShareDp.deleteFile(file: dpFile, progress: synchronizationProgress)

                // Then
                XCTFail("It should have thrown an exception")
            } catch DistributionPointError.cannotGetFileList {
                // All is well
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    func test_deleteFile_failedDeleteFailed()  throws {
        // Given
        let fileName = "fileName"
        let fileUrl = URL(fileURLWithPath: "/Source/Path/\(fileName)")
        let dpFile = DpFile(name: fileName, fileUrl: fileUrl, size: Int64(123456), checksums: nil)
        let synchronizationProgress = SynchronizationProgress()
        fileShareDp.localPath = "/Volumes/CasperShare"
        mockFileManager.removeItemError = TestErrors.SomethingWentHaywire
        let expectationCompleted = XCTestExpectation()
        Task {
            do {
                // When
                try await fileShareDp.deleteFile(file: dpFile, progress: synchronizationProgress)

                // Then
                XCTFail("It should have thrown an exception")
            } catch TestErrors.SomethingWentHaywire {
                // All is well
            }
            expectationCompleted.fulfill()
        }
        wait(for: [expectationCompleted], timeout: 5)
    }

    // MARK: - needsToPromptForPassword tests

    func test_needsToPromptForPassword_withPassword() {
        // Given it has a password, which setUpWithError() set

        // When
        let result = fileShareDp.needsToPromptForPassword()

        // Then
        XCTAssertFalse(result)
    }

    func test_needsToPromptForPassword_withNilPassword() {
        // Given
        fileShareDp.readWritePassword = nil

        // When
        let result = fileShareDp.needsToPromptForPassword()

        // Then
        XCTAssertTrue(result)
    }
}
