//
//  Copyright 2024, Jamf
//

import Haversack
import Foundation

enum KeychainHelperError: Error {
    case missingData
}

class KeychainHelper {
    let haversack = Haversack()

    func getInformationFromKeychain(serviceName: String, key: String) async throws -> Data {
        let query = GenericPasswordQuery(service: serviceName)
            .matching(account: key)
        let token = try await haversack.first(where: query)
        guard let data = token.passwordData else {
            throw KeychainHelperError.missingData
        }
        return data
    }

    func storeInformationToKeychain(serviceName: String, key: String, data: Data) async throws {
        let entity = GenericPasswordEntity()
        entity.service = serviceName
        entity.passwordData = data
        entity.account = key
        try await haversack.save(entity, itemSecurity: .standard, updateExisting: true)
    }

    func deleteKeychainItem(serviceName: String, key: String) async throws {
        let query = GenericPasswordQuery(service: serviceName)
            .matching(account: key)
        try await haversack.delete(where: query)
    }

    func jamfProServiceName(urlString: String) -> String {
        return "com.jamfsoftware.JamfSync.jps (\(urlString))"
    }

    func fileShareServiceName(urlString: String) -> String {
        return "com.jamfsoftware.JamfSync.dp (\(urlString))"
    }
}
