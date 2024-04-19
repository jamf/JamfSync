//
//  Copyright 2024, Jamf
//

import SwiftUI

struct ChecksumView: View {
    @ObservedObject var packageListViewModel: PackageListViewModel
    @ObservedObject var file: DpFileViewModel

    var body: some View {
        ZStack {
            if file.showChecksumSpinner {
                ProgressView()
                    .scaleEffect(x: 0.5, y: 0.5, anchor: .center)
                    .frame(width: 16, height: 16, alignment: .leading)
            } else {
                Text(checksumString(fileItem: file.dpFile))
                    .help(checksumHelpString(fileItem: file.dpFile))
            }
        }
    }

    func checksumString(fileItem: DpFile) -> String {
        if fileItem.checksums.checksums.count == 0 {
            return "--"
        } else {
            var checksumString = ""
            for (idx, checksum) in fileItem.checksums.checksums.enumerated() {
                checksumString += checksum.type.rawValue
                if idx < fileItem.checksums.checksums.count - 1 {
                    checksumString += ", "
                }
            }
            return checksumString
        }
    }

    func checksumHelpString(fileItem: DpFile) -> String {
        var helpString = ""
        var firstLine = true
        for checksum in fileItem.checksums.checksums {
            if !firstLine {
                helpString += "     " // There doesn't seem to be a way to do a newline in help text
            }
            helpString += "\(checksum.type.rawValue): \(checksum.value)"
            firstLine = false
        }
        return helpString
    }
}

struct ChecksumView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var packageListViewModel = PackageListViewModel(isSrc: true)
        ChecksumView(packageListViewModel: packageListViewModel, file: DpFileViewModel(dpFile: DpFile(name: "Test.pkg", size: 123456)))
    }
}
