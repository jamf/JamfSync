//
//  Copyright 2024, Jamf
//

import Foundation

enum ServerCommunicationError: Error {
    case noToken
    case noJamfProUrl
    case badUsernameOrPasswordData
    case parsingError
    case badPackageData
    case forbidden
    case contentTooLarge
    case invalidCredentials
    case couldNotAccessServer
    case dataRequestFailed(statusCode: Int, message: String? = nil)
    case uploadFailed(statusCode: Int, message: String? = nil)
    case notSupported
    case prepareForUploadFailed
}

class JamfProInstance: SavableItem {
    let tokenExpirationBuffer = 5 // If the token will expire in 5 seconds, just get another one
    var url: URL?
    var useClientApi = false
    var packageApi: JamfProPackageApi?
    var usernameOrClientId: String = ""
    var passwordOrClientSecret: String = ""
    var cloudDp: DistributionPoint?
    var fileShares: [FileShareDp] = []
    var packages: [Package] = []
    var token: String? = nil
    var tokenExpires: Date? = nil
    var loaded = false
    var error: Error?
    var urlSession = URLSession(configuration: URLSessionConfiguration.default)
    var jamfProVersion: String?
    static let iconName = "icloud"
    static let normalTimeoutValue = 60.0
    static let uploadTimeoutValue = 3600.0

    init(name: String = "", url: URL? = nil, useClientApi: Bool = false, usernameOrClientId: String = "", passwordOrClientSecret: String = "") {
        self.url = url
        self.useClientApi = useClientApi
        self.usernameOrClientId = usernameOrClientId
        self.passwordOrClientSecret = passwordOrClientSecret
        super.init(name: name)
        self.iconName = Self.iconName
    }

    // MARK: SavableItem functions

    override init(item: SavableItem, copyId: Bool = true) {
        super.init(item: item, copyId: copyId)
        if let srcJamfProInstance = item as? JamfProInstance {
            self.url = srcJamfProInstance.url
            self.useClientApi = srcJamfProInstance.useClientApi
            self.usernameOrClientId = srcJamfProInstance.usernameOrClientId
            self.passwordOrClientSecret = srcJamfProInstance.passwordOrClientSecret
            self.cloudDp = srcJamfProInstance.cloudDp
        }
        self.iconName = Self.iconName
    }

    override init(item: SavableItemData) {
        super.init(item: item)
        if let srcJamfProInstance = item as? JamfProInstanceData {
            self.url = srcJamfProInstance.url
            self.useClientApi = srcJamfProInstance.useClientApi
            self.usernameOrClientId = srcJamfProInstance.usernameOrClientId ?? ""
        }
        self.iconName = Self.iconName
    }

    override func copyToCoreStorageObject(_ item: SavableItemData) {
        super.copyToCoreStorageObject(item)
        if let srcJamfProInstanceData = item as? JamfProInstanceData {
            srcJamfProInstanceData.url = url
            srcJamfProInstanceData.useClientApi = useClientApi
            srcJamfProInstanceData.usernameOrClientId = usernameOrClientId
        }
    }

    override func copy(source: SavableItem, copyId: Bool = true) {
        super.copy(source: source, copyId: copyId)
        if let srcJamfProInstance = source as? JamfProInstance {
            self.url = srcJamfProInstance.url
            self.useClientApi = srcJamfProInstance.useClientApi
            self.usernameOrClientId = srcJamfProInstance.usernameOrClientId
            self.passwordOrClientSecret = srcJamfProInstance.passwordOrClientSecret
            self.urlSession = srcJamfProInstance.urlSession
            self.cloudDp = srcJamfProInstance.cloudDp
        }
    }

    func displayName() -> String {
        return name
    }

    override func displayInfo() -> String {
        return url?.absoluteString ?? ""
    }

    override func getDps() -> [DistributionPoint] {
        var dps: [DistributionPoint] = []
        if let cloudDp {
            dps.append(cloudDp)
        }
        dps.append(contentsOf: fileShares)
        return dps
    }

    override func loadDps() async throws {
        guard !usernameOrClientId.isEmpty, !passwordOrClientSecret.isEmpty else { return }
        jamfProVersion = try? await retrieveJamfProVersion()
        await determinePackageApi()
        try await loadPackages()
        try await loadCloudDp()
        try await loadFileShares()
    }


    override func jamfProId() -> UUID? {
        return id
    }

    override func jamfProPackages() -> [Package]? {
        return packages
    }

    // MARK: Public functions

    /// Adds a package to the Jamf Pro instance using the next available id.
    /// - Parameters:
    ///     - package: A Package object to add
    func addPackage(dpFile: DpFile) async throws {
        guard let packageApi else { throw DistributionPointError.programError }
        try await packageApi.addPackage(dpFile: dpFile, jamfProInstance: self)
    }

    /// Updates an existing package in the Jamf Pro instance.
    /// - Parameters:
    ///     - package: A Package object to update
    func updatePackage(package: Package) async throws {
        guard let packageApi else { throw DistributionPointError.programError }
        try await packageApi.updatePackage(package: package, jamfProInstance: self)
    }

    /// Removes files from this destination distribution point that are not on thie source distribution point.
    /// - Parameters:
    ///     - srcDp: The destination distribution point to search and delete packages that are missing.
    ///     - progress: The progress object that should be updated as the deletion progresses.
    func deletePackagesNotOnSource(srcDp: DistributionPoint, progress: SynchronizationProgress) async throws {
        guard let packageApi else { throw DistributionPointError.programError }
        let packagesToRemove = packagesToRemove(srcDp: srcDp)
        for package in packagesToRemove {
            if let jamfProId = package.jamfProId {
                LogManager.shared.logMessage(message: "Deleting package \(package.fileName) from \(displayName())", level: .verbose)
                try await packageApi.deletePackage(packageId: jamfProId, jamfProInstance: self)
                packages.removeAll(where: { $0.fileName == package.fileName })
            }
        }
    }

    /// Finds a package by name.
    /// - Parameters:
    ///     - name: Name of the package to search for
    /// - Returns: The Package object if found, otherwise nil.
    func findPackage(name: String) -> Package? {
        for package in packages {
            if package.fileName == name {
                return package
            }
        }
        return nil
    }

    /// Gets the next available package id.
    /// - Returns: An integer with an available Jamf Pro id
    func availablePackageId() -> Int {
        var largestId = 0
        for package in packages {
            guard let jamfProPackageId = package.jamfProId else { continue }
            if jamfProPackageId > largestId {
                largestId = jamfProPackageId
            }
        }
        return largestId + 1 // The next largest id
    }

    /// Creates a data request for communicating with the UAPI or CAPI.
    /// - Parameters:
    ///     - url: URL to contact
    ///     - httpMethod: The method to use (GET, POST, etc.)
    ///     - httpBody: The body data, if needed, otherwise nil.
    /// - Returns: Returns a tuple with the data retruned and the URLResponse.
    func dataRequest(url: URL, httpMethod: String, httpBody: Data? = nil, contentType: String = "application/json", acceptType: String? = nil, throwHttpError: Bool = true, timeout: Double = JamfProInstance.normalTimeoutValue) async throws -> (data: Data?, response: URLResponse?) {
        try await retrieveToken(username: usernameOrClientId, password: passwordOrClientSecret)
        guard let token else { throw ServerCommunicationError.noToken }

        let headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "\(contentType)",
            "Accept": "\(acceptType ?? contentType)"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.timeoutInterval = timeout
        request.httpBody = httpBody
        request.allHTTPHeaderFields = headers

        let (data, response) = try await urlSession.data(for: request)

        if throwHttpError, let response = response as? HTTPURLResponse {
            if !(200...299).contains(response.statusCode) {
                let responseDataString = String(data: data, encoding: .utf8)
                throw ServerCommunicationError.dataRequestFailed(statusCode: response.statusCode, message: responseDataString)
            }
        }
        return (data: data, response: response)
    }

    /// Loads data from the keychain
    func loadKeychainData() async {
        guard let urlHost = url?.host(), !usernameOrClientId.isEmpty else { return }
        let keychainHelper = KeychainHelper()
        let serviceName = keychainHelper.jamfProServiceName(urlString: urlHost)
        do {
            let data = try await keychainHelper.getInformationFromKeychain(serviceName: serviceName, key: usernameOrClientId)
            passwordOrClientSecret = String(decoding: data, as: UTF8.self)
        }
        catch {
            // If it fails for any reason, just assume it's not available in the keychain. The user will need to go in and edit the password.
            LogManager.shared.logMessage(message: "Failed to get a keychain item \(serviceName): \(error)", level: .verbose)
        }
    }

    /// Loads or reloads packages
    func loadPackages() async throws {
        guard let packageApi else { throw DistributionPointError.programError }
        packages.removeAll()
        packages = try await packageApi.loadPackages(jamfProInstance: self)
    }

    /// Checks to see which packages on the Jamf Pro server are not in the source DP
    ///  - Parameters:
    ///     - srcDp: The source distribution point to check for missing files.
    ///   - Returns: Returns a list of packages that are on this Jamf Pro server but not on the source distribution point.
    func packagesToRemove(srcDp: DistributionPoint) -> [Package] {
        var filesToRemove: [Package] = []
        for package in packages {
            if srcDp.dpFiles.findDpFile(name: package.fileName) == nil {
                filesToRemove.append(package)
            }
        }
        return filesToRemove
    }

    /// Cancels anything that is currently happening and creates a new session.
    func cancel() {
        urlSession.invalidateAndCancel()
        urlSession = URLSession(configuration: URLSessionConfiguration.default)
    }

    // MARK: Private functions
   
    private func retrieveJamfProVersion() async throws -> String? {
        guard let url = url else { throw ServerCommunicationError.noJamfProUrl }

        let jamfProVersionUrl = url.appendingPathComponent("/api/v1/jamf-pro-version")
        let response = try await dataRequest(url: jamfProVersionUrl, httpMethod: "GET")
        if let data = response.data {
            let decoder = JSONDecoder()
            if let jsonVersion = try? decoder.decode(JsonJamfProVersion.self, from: data) {
                return jsonVersion.version
            }
        }
        return nil
    }

    private func determinePackageApi() async {
        guard packageApi == nil else { return }
        if let hasUapiInterface = try? await hasUapiPackagesInterface(), hasUapiInterface {
            packageApi = JamfProPackageUApi()
        } else {
            packageApi = JamfProPackageClassicApi()
        }
    }

    private func retrieveToken(username: String, password: String) async throws {
        if tokenIsStillValid() { return }

        guard let url = url else { throw ServerCommunicationError.noToken }
        let tokenUrl: URL
        if useClientApi {
            tokenUrl = url.appendingPathComponent("api/oauth/token")
        } else {
            tokenUrl = url.appendingPathComponent("api/v1/auth/token")
        }
        guard let basicCred = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() else { throw ServerCommunicationError.badUsernameOrPasswordData }
        let headers: [String: String]

        if useClientApi {
            headers = [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json",
                "User-Agent": userAgent()]
        } else {
            headers = [
                "Authorization": "Basic \(basicCred)",
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": userAgent()]
        }

        var request = URLRequest(url: tokenUrl)
        if useClientApi {
            let clientString = "grant_type=client_credentials&client_id=\(username)&client_secret=\(password)"
            request.httpBody = clientString.data(using: .utf8)
        }
        request.httpMethod = "POST"
        request.timeoutInterval = JamfProInstance.normalTimeoutValue
        request.allHTTPHeaderFields = headers

        let response: (data: Data?, response: URLResponse?) = try await urlSession.data(for: request)
        if let httpResponse = response.response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw ServerCommunicationError.invalidCredentials
            case 403:
                throw ServerCommunicationError.forbidden
            default:
                throw ServerCommunicationError.couldNotAccessServer
            }
        }
        if let data = response.data {
            if useClientApi {
                retrieveOauthTokenFromData(data: data)
            } else {
                retrieveTokenFromData(data: data)
            }
        }
    }

    private func tokenIsStillValid() -> Bool {
        guard let tokenExpires else { return false }
        if Date.now + TimeInterval(tokenExpirationBuffer) > tokenExpires {
            return false
        }
        return true
    }

    private func retrieveTokenFromData(data: Data) {
        let jsonToken = try? JSONDecoder().decode(JsonToken.self, from: data)
        token = jsonToken?.token
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let expires = jsonToken?.expires {
            tokenExpires = dateFormatter.date(from: expires)
        }
        if token == nil {
            LogManager.shared.logMessage(message: "Failed to get the token. The token was nil.", level: .error)
        }
    }

    private func retrieveOauthTokenFromData(data: Data) {
        let jsonToken = try? JSONDecoder().decode(JsonOauthToken.self, from: data)
        token = jsonToken?.access_token
        if let expiresIn = jsonToken?.expires_in {
            tokenExpires = Date() + TimeInterval(expiresIn)
        }
        if token == nil {
            LogManager.shared.logMessage(message: "Failed to get the OAuth token. The token was nil.", level: .error)
        }
    }

    private func userAgent() -> String {
        return "\(Bundle.main.bundleURL.deletingPathExtension().lastPathComponent)/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
    }

    private func loadCloudDp() async throws {
        fileShares.removeAll()
        if try await supportsJcds2() {
            cloudDp = Jcds2Dp(jamfProInstanceId: id, jamfProInstanceName: name)
        } else if try await supportsGeneralCloudDp() {
            cloudDp = GeneralCloudDp(jamfProInstanceId: id, jamfProInstanceName: name)
        }
    }

    private func supportsJcds2() async throws -> Bool {
        guard let url = url else { throw ServerCommunicationError.noJamfProUrl }

        // Try to get the information for a non-existent file. If it returns a 500, then JCDS2 is not supported. If it returns 404, then it's good.
        let cloudFileUrl = url.appendingPathComponent("/api/v1/jcds/files/nonexistentfile")

        let response = try await dataRequest(url: cloudFileUrl, httpMethod: "GET", throwHttpError: false)
        if let httpResponse = response.response as? HTTPURLResponse {
            return httpResponse.statusCode != 500
        }
        return false
    }

    private func supportsGeneralCloudDp() async throws -> Bool {
        if try await isUploadCapable() {
            return try await hasUapiPackagesInterface()
        }
        return false
    }

    private func isUploadCapable() async throws -> Bool {
        guard let url = url else { throw ServerCommunicationError.noJamfProUrl }

        // Try to get the information for a non-existent file. If it returns a 500, then JCDS2 is not supported. If it returns 404, then it's good.
        let cloudUploadCapabilityUrl = url.appendingPathComponent("/api/v1/cloud-distribution-point/upload-capability")

        let response = try await dataRequest(url: cloudUploadCapabilityUrl, httpMethod: "GET")
        if let data = response.data {
            let decoder = JSONDecoder()
            if let jsonCloudDpUploadCapability = try? decoder.decode(JsonCloudDpUploadCapability.self, from: data) {
                return jsonCloudDpUploadCapability.principalDistributionTechnology == true
            }
        }
        return false
    }

    private func hasUapiPackagesInterface() async throws -> Bool {
        guard let jamfProVersion else { return false }
        // If it's version 11.5 or greater, then it's supported
        let versionParts = jamfProVersion.split(separator: ".")
        if versionParts.count >= 2 {
            if let majorVersion = Int(versionParts[0]), let minorVersion = Int(versionParts[1]) {
                if majorVersion > 11 {
                    return true
                } else if majorVersion == 11 && minorVersion >= 5 {
                    return true
                }
            }
        }
        return false
    }

    private func loadFileShares() async throws {
        guard let url = url else { throw ServerCommunicationError.noJamfProUrl }
        let fileSharesUrl = url.appendingPathComponent("JSSResource/distributionpoints")

        fileShares.removeAll()
        do {
            let response = try await dataRequest(url: fileSharesUrl, httpMethod: "GET")
            if let data = response.data {
                let decoder = JSONDecoder()
                if let jsonDps = try? decoder.decode(JsonDps.self, from: data) {
                    for fileShare in jsonDps.distribution_points {
                        try await loadFileShare(fileShare: fileShare)
                    }
                }
            }
        } catch let error {
            LogManager.shared.logMessage(message: "Failed to get fileshare information from \(name): \(error)", level: .error)
            throw error
        }
    }

    private func loadFileShare(fileShare: JsonDp) async throws {
        guard let url = url else { throw ServerCommunicationError.noJamfProUrl }
        let fileShareUrl = url.appendingPathComponent("JSSResource/distributionpoints/id/\(fileShare.id)")
        do {
            let response = try await dataRequest(url: fileShareUrl, httpMethod: "GET")
            if let data = response.data {
                do {
                    let decoder = JSONDecoder()
                    let jsonFileShare = try decoder.decode(JsonDpItem.self, from: data)
                    let fileShare = FileShareDp(JsonDpDetail: jsonFileShare.distribution_point)
                    fileShare.jamfProInstanceId = id
                    fileShare.jamfProInstanceName = name
                   fileShares.append(fileShare)
                } catch let DecodingError.dataCorrupted(context) {
                    LogManager.shared.logMessage(message: "Failed to parse data from \(displayInfo()). Data was corrupted: \(context)", level: .verbose)
                    throw ServerCommunicationError.parsingError
                } catch let DecodingError.keyNotFound(key, context) {
                    LogManager.shared.logMessage(message: "Failed to parse data from \(displayInfo()). Key '\(key)' not found: \(context.debugDescription), codingPath: \(context.codingPath)", level: .verbose)
                    throw ServerCommunicationError.parsingError
                } catch let DecodingError.valueNotFound(value, context) {
                    LogManager.shared.logMessage(message: "Failed to parse data from \(displayInfo()). Value '\(value)' not found: \(context.debugDescription), codingPath: \(context.codingPath)", level: .verbose)
                    throw ServerCommunicationError.parsingError
                } catch let DecodingError.typeMismatch(type, context)  {
                    LogManager.shared.logMessage(message: "Failed to parse data from \(displayInfo()). Type '\(type)' mismatch: \(context.debugDescription), codingPath: \(context.codingPath)", level: .verbose)
                    throw ServerCommunicationError.parsingError
                } catch {
                    LogManager.shared.logMessage(message: "Failed to parse data from \(displayInfo()). \(error)", level: .verbose)
                    throw ServerCommunicationError.parsingError
                }
            }
        }
    }
}

extension JamfProInstanceData {
    func initialize(from instance: JamfProInstance) {
        self.id = instance.id
        self.name = instance.name
        self.url = instance.url
        self.useClientApi = instance.useClientApi
        self.usernameOrClientId = instance.usernameOrClientId
    }
}
