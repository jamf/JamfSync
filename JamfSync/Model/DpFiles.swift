//
//  Copyright 2024, Jamf
//

import Foundation

class DpFiles {
    var files: [DpFile] = []

    func findDpFile(id: UUID) -> DpFile? {
        return files.first { $0.id == id }
    }

    func findDpFile(name: String) -> DpFile? {
        return files.first { $0.name == name }
    }

    func removeAll() {
        files.removeAll()
    }
}
