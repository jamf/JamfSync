//
//  Copyright 2024, Jamf
//

import Foundation

class JamfProPackageUApi: JamfProPackageApi {
    fileprivate func getPackagesByPage(jamfProInstance: JamfProInstance, page: Int, pageSize: Int) async throws -> (Int, [Package]) {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }
        
        var packages: [Package] = []
        var totalPackages = 0
        
        let pageParameters = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "page-size", value: "\(pageSize)"), URLQueryItem(name: "sort", value: "id%3Aasc")]
        let packagesUrl = url.appendingPathComponent("/api/v1/packages").appending(queryItems: pageParameters)
        
        let response = try await jamfProInstance.dataRequest(url: packagesUrl, httpMethod: "GET")
        if let data = response.data {
            let decoder = JSONDecoder()
            do {
                if let jsonPackages = try decoder.decode(JsonUapiPackages?.self, from: data) {
                    packages.removeAll()
                    totalPackages = jsonPackages.totalCount
                    LogManager.shared.logMessage(message: "\(jamfProInstance.url?.absoluteString ?? "unknown server") - page \(page) retrieved \(jsonPackages.results.count) of \(jsonPackages.totalCount) packages", level: .debug)
                    for package in jsonPackages.results {
                        if let package = convertToPackage(jsonPackage: package) {
                            packages.append(package)
                        }
                    }
                }
            } catch {
                LogManager.shared.logMessage(message: "Failed to load package info from page \(page): \(error)", level: .error)
            }
        }
        return (totalPackages, packages)
    }
    
    func loadPackages(jamfProInstance: JamfProInstance) async throws -> [Package] {
        guard let _ = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        var packages: [Package] = []
        
        let pageSize = 200
        var totalPackages = 0

        (totalPackages, packages) = try await getPackagesByPage(jamfProInstance: jamfProInstance, page: 0, pageSize: pageSize)
        
        let pages = Int((Double(totalPackages)/Double(pageSize)).rounded(.up))
        for whichPage in 1..<Int(pages) {
            let (_, fetchedPackages) = try await getPackagesByPage(jamfProInstance: jamfProInstance, page: whichPage, pageSize: pageSize)
            packages.append(contentsOf: fetchedPackages)
        }

        return packages
    }

    func addPackage(dpFile: DpFile, jamfProInstance: JamfProInstance) async throws {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        var package = Package(jamfProId: nil, displayName: dpFile.name, fileName: dpFile.name, category: "-1", size: dpFile.size, checksums: dpFile.checksums)
        let packageUrl = url.appendingPathComponent("/api/v1/packages")
        let jsonUapiPackageDetail = JsonUapiPackageDetail(package: package)
        let jsonEncoder = JSONEncoder()
        let jsonData = try jsonEncoder.encode(jsonUapiPackageDetail)
        let response = try await jamfProInstance.dataRequest(url: packageUrl, httpMethod: "POST", httpBody: jsonData, contentType: "application/json")
        if let data = response.data {
            let decoder = JSONDecoder()
            do {
                if let jsonUapiPackageResult = try decoder.decode(JsonUapiAddPackageResult?.self, from: data) {
                    package.jamfProId = Int(jsonUapiPackageResult.id)
                    jamfProInstance.packages.append(package)
                }
            } catch {
                LogManager.shared.logMessage(message: "Failed to add a package for file \(dpFile.name) to Jamf Pro server \(jamfProInstance.displayName()): \(error)", level: .error)
                throw error
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
        
        let packageUrl = url.appendingPathComponent("/api/v1/packages/\(jamfProId)")
        let jsonUapiPackageDetail = JsonUapiPackageDetail(package: package)
        let jsonEncoder = JSONEncoder()
        let jsonData = try jsonEncoder.encode(jsonUapiPackageDetail)
        do {
            _ = try await jamfProInstance.dataRequest(url: packageUrl, httpMethod: "PUT", httpBody: jsonData, contentType: "application/json")
        } catch {
            LogManager.shared.logMessage(message: "Failed to update a package for file \(package.fileName) on Jamf Pro server \(jamfProInstance.displayName()): \(error)", level: .error)
            throw error
        }
    }

    func deletePackage(packageId: Int, jamfProInstance: JamfProInstance) async throws {
        guard let url = jamfProInstance.url else { throw ServerCommunicationError.noJamfProUrl }

        let pathComponent = "/api/v1/packages/\(packageId)"
        let packageUrl = url.appendingPathComponent(pathComponent)
        let _ = try await jamfProInstance.dataRequest(url: packageUrl, httpMethod: "DELETE")
    }

    // MARK: Private functions

    private func createBoundaryForMultipartUpload() -> String {
        let alphNumChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let uniqueStr = String((0..<16).map{ _ in alphNumChars.randomElement()! })

        return "----WebKitFormBoundary\(uniqueStr)"
    }

    private func convertToPackage(jsonPackage: JsonUapiPackageDetail) -> Package? {
        guard let jamfProIdString = jsonPackage.id, let _ = Int(jamfProIdString), let _ = jsonPackage.packageName, let _ = jsonPackage.fileName else { return nil }
        return Package(uapiPackageDetail: jsonPackage)
    }
}
