//
//  JamfProPackageClassicApi.swift
//  Jamf Sync
//
//  Created by Harry Strand on 4/9/24.
//

import Foundation

class JamfProPackageClassicApi: JamfProPackageApi {
    func loadPackages(jamfProInstance: JamfProInstance) async throws -> [Package] {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        var packages: [Package] = []
        let packagesUrl = url.appendingPathComponent("JSSResource/packages")

        let response = try await jamfProInstance.dataRequest(url: packagesUrl, httpMethod: "GET")
        if let data = response.data {
            let decoder = JSONDecoder()
            if let jsonPackages = try? decoder.decode(JsonCapiPackages.self, from: data) {
                packages.removeAll()
                for package in jsonPackages.packages {
                    if let package = try await loadPackage(package: package, jamfProInstance: jamfProInstance) {
                        packages.append(package)
                    }
                }
            }
        }

        return packages
    }

    func addPackage(dpFile: DpFile, jamfProInstance: JamfProInstance) async throws {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        var package = Package(jamfProId: 0, displayName: dpFile.name, fileName: dpFile.name, category: "", size: dpFile.size, checksums: dpFile.checksums)
        let packageUrl = url.appendingPathComponent("JSSResource/packages/id/0")
        let body = packageBody(package: package, jamfProPackageId: 0)
        guard let bodyData = body.data(using: .utf8) else { throw ServerCommunicationError.badPackageData }
        let response = try await jamfProInstance.dataRequest(url: packageUrl, httpMethod: "POST", httpBody: bodyData, contentType: "text/xml")
        if let data = response.data {
            if let dataString = String(data: data, encoding: .utf8), let jamfProId = parseAddPackageResult(resultString: dataString) {
                package.jamfProId = jamfProId
                jamfProInstance.packages.append(package)
            } else {
                LogManager.shared.logMessage(message: "Failed to add a package for file \(dpFile.name) to Jamf Pro server \(jamfProInstance.displayName())", level: .error)
                throw ServerCommunicationError.parsingError
            }
        } else {
            LogManager.shared.logMessage(message: "Failed to add a package for file \(dpFile.name) to Jamf Pro server \(jamfProInstance.displayName())", level: .error)
            throw ServerCommunicationError.parsingError
        }
    }

    /// Updates an existing package in the Jamf Pro instance.
    /// - Parameters:
    ///     - package: A Package object to update
    func updatePackage(package: Package, jamfProInstance: JamfProInstance) async throws {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        guard let jamfProId = package.jamfProId else { throw ServerCommunicationError.badPackageData }
        let packageUrl = url.appendingPathComponent("JSSResource/packages/id/\(jamfProId)")
        let body = packageBody(package: package, jamfProPackageId: jamfProId)
        guard let bodyData = body.data(using: .utf8) else { throw ServerCommunicationError.badPackageData }
        let response = try await jamfProInstance.dataRequest(url: packageUrl, httpMethod: "PUT", httpBody: bodyData, contentType: "text/xml")
        if let data = response.data {
            if let dataString = String(data: data, encoding: .utf8), let jamfProId = parseAddPackageResult(resultString: dataString) {
                if let packageJamfProId = package.jamfProId, packageJamfProId != jamfProId {
                    LogManager.shared.logMessage(message: "After updating the \(package.fileName) package, the package id of \(jamfProId) is different than the expected \(packageJamfProId)", level: .warning)
                }
            } else {
                LogManager.shared.logMessage(message: "Failed to update a package for file \(package.fileName) on Jamf Pro server \(jamfProInstance.displayName())", level: .error)
                throw ServerCommunicationError.parsingError
            }
        } else {
            LogManager.shared.logMessage(message: "Failed to update a package for file \(package.fileName) on Jamf Pro server \(jamfProInstance.displayName())", level: .error)
            throw ServerCommunicationError.parsingError
        }
    }

    func deletePackage(packageId: Int, jamfProInstance: JamfProInstance) async throws {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        let packageUrl = url.appendingPathComponent("JSSResource/packages/id/\(packageId)")
        let _ = try await jamfProInstance.dataRequest(url: packageUrl, httpMethod: "DELETE")
    }

    // MARK: Private functions

    private func loadPackage(package: JsonCapiPackage, jamfProInstance: JamfProInstance) async throws -> Package? {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        let packageUrl = url.appendingPathComponent("JSSResource/packages/id/\(package.id)")
        let response = try await jamfProInstance.dataRequest(url: packageUrl, httpMethod: "GET")
        if let data = response.data {
            let decoder = JSONDecoder()
            let jsonPackage = try decoder.decode(JsonCapiPackageItem.self, from: data)
            return Package(packageDetail: jsonPackage.package)
        }
        return nil
    }

    private func packageBody(package: Package, jamfProPackageId: Int) -> String {
        let checksum = package.checksums.bestChecksum()
        var checksumTypeString = "MD5"
        if let checksumType = checksum?.type {
            checksumTypeString = String(describing: checksumType)
        }

        var category = package.category
        if category == "No category assigned" {
            category = ""
        }

        return """
<?xml version="1.0" encoding="UTF-8"?>
  <package>
    <id>\(jamfProPackageId)</id>
    <name>\(package.displayName)</name>
    <category>\(category)</category>
    <filename>\(package.fileName)</filename>
    <info/>
    <notes/>
    <priority>10</priority>
    <reboot_required>false</reboot_required>
    <fill_user_template>false</fill_user_template>
    <fill_existing_users>false</fill_existing_users>
    <allow_uninstalled>false</allow_uninstalled>
    <os_requirements/>
    <required_processor>None</required_processor>
    <hash_type>\(checksumTypeString)</hash_type>
    <hash_value>\(checksum?.value ?? "")</hash_value>
    <switch_with_package>Do Not Install</switch_with_package>
    <install_if_reported_available>false</install_if_reported_available>
    <reinstall_option>Do Not Reinstall</reinstall_option>
    <triggering_files/>
    <send_notification>false</send_notification>
  </package>
"""
    }

    private func parseAddPackageResult(resultString: String) -> Int? {
        if let match = resultString.range(of: "(?<=<id>)[^<\\/id>]+", options: .regularExpression) {
            let idValue = resultString[match]
            if let id = Int(idValue) {
                return id
            } else {
                LogManager.shared.logMessage(message: "Failed to convert the returned package id to an integer: \(idValue)", level: .warning)
                return nil
            }
        }
        LogManager.shared.logMessage(message: "Could not parse the package id from the returned data: \(resultString)", level: .warning)
        return nil
    }

}
