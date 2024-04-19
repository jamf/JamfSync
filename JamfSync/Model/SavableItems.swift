//
//  Copyright 2024, Jamf
//

import Foundation

class SavableItems: ObservableObject {
    @Published var items: [SavableItem] = []

    /// Create an exact duplicate that can be sent to the Setup view so if they cancel, the changes can be discarded
    func duplicate(copyId: Bool = true) -> SavableItems {
        let newSavableItems = SavableItems()

        for item in items {
            if item is JamfProInstance {
                newSavableItems.items.append(JamfProInstance(item: item, copyId: copyId))
            } else if item is FolderInstance {
                newSavableItems.items.append(FolderInstance(item: item, copyId: copyId))
            } else {
                // This shouldn't normally be possible unless there is a programming error
                LogManager.shared.logMessage(message: "Unknown type for \(item.name)", level: .error)
            }
        }

        return newSavableItems
    }

    /// Replace the contents with the contents of the object passed in. This is used to accept the changes from the Setup view
    func replace(savableItems: SavableItems, copyId: Bool = true) {
        items.removeAll()

        for item in savableItems.items {
            if item is JamfProInstance {
                items.append(JamfProInstance(item: item, copyId: copyId))
            } else if item is FolderInstance {
                items.append(FolderInstance(item: item, copyId: copyId))
            } else {
                // This shouldn't normally be possible unless there is a programming error
                LogManager.shared.logMessage(message: "Unknown type for \(item.name)", level: .error)
            }
        }
    }

    func findSavableItem(id: UUID?) -> SavableItem? {
        guard let id else { return nil }
        for item in items {
            if item.id == id {
                return item
            }
        }
        return nil
    }

    func findSavableItemWithDpId(id: UUID?) -> SavableItem? {
        guard let id else { return nil }
        for item in items {
            for dp in item.getDps() {
                if dp.id == id {
                    return item
                }
            }
        }
        return nil
    }

    func addJamfProInstance(jamfProInstance: JamfProInstance) {
        items.append(JamfProInstance(item: jamfProInstance, copyId: false))
    }

    func addFolderInstance(folderInstance: FolderInstance) {
        items.append(FolderInstance(item: folderInstance, copyId: false))
    }

    @discardableResult func updateSavableItem(item: SavableItem) -> Bool {
        guard let itemFound = findSavableItem(id: item.id) else { return false }
        // Copy data from the item passed in to the item that's already in the list.
        if let jamfProInstanceFound = itemFound as? JamfProInstance, let jamfProInstance = item as? JamfProInstance {
            jamfProInstanceFound.copy(source: jamfProInstance)
        } else if let folderInstanceFound = itemFound as? FolderInstance, let folderInstance = item as? FolderInstance {
            folderInstanceFound.copy(source: folderInstance)
        }
        objectWillChange.send() // Changing the item in the list won't cause the views to redraw
        return true
    }

    @discardableResult func deleteSavableItem(id: UUID) -> Bool {
        guard let itemFound = findSavableItem(id: id),
                let index = items.firstIndex(where: { $0 === itemFound }) else { return false }
        items.remove(at: index)
        return true
    }
}
