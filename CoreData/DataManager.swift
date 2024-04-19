//
//  Copyright 2024, Jamf
//

import CoreData
import Foundation

/// Main data manager for the SavableItems (Jamf Pro or Follder instances)
class DataManager: NSObject, ObservableObject {
    @Published var savableItems: [SavableItemData] = []

    /// Add the Core Data container with the model name
    let container: NSPersistentContainer = NSPersistentContainer(name: "StoredSettings")


    /// Default init method. Load the Core Data container
    override init() {
        super.init()
        container.loadPersistentStores { _, _ in }
    }

}
