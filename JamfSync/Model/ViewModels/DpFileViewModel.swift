//
//  Copyright 2024, Jamf
//

import Foundation

enum FileState: String, Comparable {
    case undefined = "Haven't done any checking of the source or destination yet"
    case matched = "Exists on both the source and destination, and they match (checksums and/or size)"
    case mismatched = "Exists on both the source and destination, but they do not match (checksums and/or size)"
    case packageMissing = "Present as a package on the Jamf Pro Server but missing on both the source and destination"
    case packageMissingOnSrc = "Present as a package on the Jamf Pro Server but missing on the source"
    case missingOnSrc = "Missing on the source but present on the destination"
    case missingOnDst = "Present on the source but missing on the destination"

    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class DpFileViewModel: ObservableObject, Identifiable {
    var id = UUID()
    @Published var state: FileState = .undefined
    @Published var showChecksumSpinner = false
    var dpFile: DpFile

    init(dpFile: DpFile, state: FileState = .undefined) {
        self.state = state
        self.dpFile = dpFile
    }

    func compressedSize() -> String {
        guard let size = dpFile.size else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: size)
    }
}
