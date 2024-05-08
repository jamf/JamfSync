//
//  Copyright 2024, Jamf
//

import Foundation

protocol JamfProPackageApi {
    /// Loads packages from Jamf Pro
    /// - Parameters:
    ///     - jamfProInstance: The jamf pro instance to communicate with
    func loadPackages(jamfProInstance: JamfProInstance) async throws -> [Package]

    /// Adds a package to the Jamf Pro instance using the next available id.
    /// - Parameters:
    ///     - dpFile: The file to add as a package
    ///     - jamfProInstance: The jamf pro instance to communicate with
    func addPackage(dpFile: DpFile, jamfProInstance: JamfProInstance) async throws

    /// Update a package in Jamf Pro
    /// - Parameters:
    ///     - package: The package information to update
    ///     - jamfProInstance: The jamf pro instance to communicate with
    func updatePackage(package: Package, jamfProInstance: JamfProInstance) async throws

    /// Delete a package from Jamf Pro
    /// - Parameters:
    ///     - packageId: The id of the package to update
    ///     - jamfProInstance: The jamf pro instance to communicate with
    func deletePackage(packageId: Int, jamfProInstance: JamfProInstance) async throws
}
