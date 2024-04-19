//
//  Copyright 2024, Jamf
//

import SwiftUI

class DataPersistence: ObservableObject {
    let dataManager: DataManager
    let viewContext: NSManagedObjectContext

    init(dataManager: DataManager) {
        self.dataManager = dataManager
        self.viewContext = dataManager.container.viewContext
    }

    func loadSavableItems() -> SavableItems {
        let savableItems = SavableItems()
        let fetchRequest = NSFetchRequest<SavableItemData>(entityName: "SavableItemData")
        do {
            let items = try dataManager.container.viewContext.fetch(fetchRequest)
            for item in items {
                if let folderInstanceData = item as? FolderInstanceData {
                    savableItems.items.append(FolderInstance(item: folderInstanceData))
                } else if let jamfProInstanceData = item as? JamfProInstanceData {
                    savableItems.items.append(JamfProInstance(item: jamfProInstanceData))
                } else {
                    // This shouldn't normally be possible unless there is a programming error
                    LogManager.shared.logMessage(message: "A saved item wasn't one of the allowable types", level: .error)
                }
            }
        } catch {
            LogManager.shared.logMessage(message: "Failed to get items from core data: \(error)", level: .error)
        }
        return savableItems
    }

    func saveFolderInCoreData(instance: FolderInstance) {
        let newItem = FolderInstanceData(context: viewContext)
        newItem.initialize(from: instance)
        do {
            try viewContext.save()
        } catch {
            LogManager.shared.logMessage(message: "Failed to save new folder item \(instance.name)", level: .error)
        }
    }

    func updateInCoreData(instance: SavableItem) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SavableItemData")
        fetchRequest.predicate = NSPredicate(format: "id = %@", instance.id as CVarArg)

        do {
            let fetchResults = try viewContext.fetch(fetchRequest)
            if fetchResults.count != 0 {
                if let managedObject = fetchResults[0] as? SavableItemData {
                    instance.copyToCoreStorageObject(managedObject)
                    try viewContext.save()
                } else {
                    LogManager.shared.logMessage(message: "The fetched results were not of the expected type", level: .error)
                }
            }
        } catch {
            LogManager.shared.logMessage(message: "Failed to save \(instance.name): \(error)", level: .error)
        }
    }

    func deleteCoreDataItem(id: UUID) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SavableItemData")
        fetchRequest.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        do {
            let fetchResults = try viewContext.fetch(fetchRequest)
            if fetchResults.count != 0, let savableItemData = fetchResults[0] as? SavableItemData {
                viewContext.delete(savableItemData)
                try viewContext.save()
            }
        } catch {
            LogManager.shared.logMessage(message:"Failed to delete item with id \(id): \(error)", level: .error)
        }

    }

    func saveJamfProInCoreData(instance: JamfProInstance) {
        let newItem = JamfProInstanceData(context: viewContext)
        newItem.initialize(from: instance)
        do {
            try viewContext.save()
        } catch {
            LogManager.shared.logMessage(message: "Failed to save new folder item \(instance.name)", level: .error)
        }
    }
}
