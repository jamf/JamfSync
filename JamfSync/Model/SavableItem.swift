//
//  Copyright 2024, Jamf
//

import Foundation

class SavableItem: Identifiable {
    var id = UUID()
    var name: String = ""
    var iconName: String = ""
    var urlOrFolder: String {
        get {
            return self.displayInfo()
        }
    }

    init(name: String) {
        self.name = name
    }

    init(item: SavableItem, copyId: Bool = true) {
        if copyId {
            id = item.id
        }
        name = item.name
    }

    init(item: SavableItemData) {
        if let id = item.id {
            self.id = id
        }
        self.name = item.name ?? ""
    }

    /// Copies the data from this object to a core storage object
    /// - Parameters:
    ///     - item: A SavableItemData object to copy the data to
    func copyToCoreStorageObject(_ item: SavableItemData) {
        item.name = name
    }

    /// Copies data from another SavableItem object. This should be overridden by child classes although it should also call super.copy(source:, copyid:)
    /// - Parameters:
    ///     - source: A SavableItem object to copy the data from
    ///     - copyId: Whether to copy the id from the source
    func copy(source: SavableItem, copyId: Bool = true) {
        if copyId {
            self.id = source.id
        }
        self.name = source.name
    }

    /// Gets a string for use with a selection list. This should be overridden by child classes.
    /// - Returns: Returns a string that represents the object in a selection list.
    func displayInfo() -> String {
        // This should be overridden
        return ""
    }

    /// Gets a list of distribution points associated with this object. This should be overridden by child classes.
    /// - Returns: Returns an array of DistributionPoint objects
    func getDps() -> [DistributionPoint] {
        // This should be overridden
        return []
    }

    /// Loads information for the associated distribution points. This should be overridden by child classes that need to do something in order to know which distribution points are associated with it.
    func loadDps() async throws {
        // This should be overridden if any loading needs to be done
    }

    /// Returns the Jamf Pro Id of an associated Jamf Pro instance, otherwise it returns nil. This should be overridden by child classes that are associated with a Jamf Pro instance.
    /// - Returns: A UUID of the Jamf Pro instance, or nil if it's not associated with a Jamf Pro instance
    func jamfProId() -> UUID? {
        // This should be overridden if applicable
        return nil
    }

    /// Returns a list of packages that are associated with Jamf Pro instance, otherwise it returns nil. This should be overridden by child classes that are associated with a Jamf Pro instance.
    /// - Returns: A list of Package objects that are associated with a Jamf Pro instance, otherwise nil.
    func jamfProPackages() -> [Package]? {
        // This should be overridden if applicable
        return nil
    }
}
