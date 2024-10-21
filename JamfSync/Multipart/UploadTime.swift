//
//  Copyright 2024, Jamf
//

import Foundation

class UploadTime {
    var start: TimeInterval = 0.0
    var end: TimeInterval = 0.0

    func total() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: end - start) ?? ""
    }
}
