//
//  Copyright 2024, Jamf
//

import Foundation

class FolderInstance: SavableItem, ObservableObject {
    var folderDp: FolderDp
    static let iconName = "folder"

    init(name: String = "", filePath: String = "") {
        self.folderDp = FolderDp(name: name, filePath: filePath)
        super.init(name: name)
        self.iconName = Self.iconName
    }

    override init(item: SavableItem, copyId: Bool = true) {
        if let srcFolderInstance = item as? FolderInstance {
            self.folderDp = FolderDp(name: srcFolderInstance.folderDp.name, filePath: srcFolderInstance.folderDp.filePath)
        } else {
            self.folderDp = FolderDp(name: item.name, filePath: "")
        }
        super.init(item: item, copyId: copyId)
        self.iconName = Self.iconName
    }

    override init(item: SavableItemData) {
        if let srcFolderInstance = item as? FolderInstanceData {
            self.folderDp = FolderDp(name: srcFolderInstance.name ?? "", filePath: srcFolderInstance.filePath ?? "")
        } else {
            self.folderDp = FolderDp(name: item.name ?? "", filePath: "")
        }
        super.init(item: item)
        self.iconName = Self.iconName
    }

    override func copyToCoreStorageObject(_ item: SavableItemData) {
        super.copyToCoreStorageObject(item)
        if let srcFolderInstanceData = item as? FolderInstanceData {
            srcFolderInstanceData.filePath = folderDp.filePath
        }
    }

    override func copy(source: SavableItem, copyId: Bool = true) {
        super.copy(source: source, copyId: copyId)
        if let srcFolderInstance = source as? FolderInstance {
            self.folderDp = FolderDp(name: srcFolderInstance.folderDp.name, filePath: srcFolderInstance.folderDp.filePath)
        }
    }

    // MARK: - SavableItem functions

    override func displayInfo() -> String {
        return folderDp.filePath
    }

    override func getDps() -> [DistributionPoint] {
        return [folderDp]   // The wonderful thing about FolderDp...I'm the only one
    }

    override func jamfProId() -> UUID? {
        return nil
    }

    override func jamfProPackages() -> [Package]? {
        return nil
    }
}

extension FolderInstanceData {
    func initialize(from folderInstance: FolderInstance) {
        self.id = folderInstance.id
        self.name = folderInstance.name
        self.filePath = folderInstance.folderDp.filePath
    }
}
