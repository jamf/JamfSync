//
//  Copyright 2024, Jamf
//

class UploadTime {
    var start: Int
    var end: Int

    init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    func total() -> String {
        let totalSeconds = end - start
        var totalTime = ""
        if totalSeconds >= 3600 {
            let hours = totalSeconds / 3600
            let unit = (hours == 1 ) ? "hour ":"hours "
            totalTime = "\(hours) \(unit)"
        }
        if totalSeconds >= 60 {
            let minutes = (totalSeconds % 3600) / 60
            let unit = (minutes == 1 ) ? "minute ":"minutes "
            totalTime = totalTime + "\(minutes) \(unit)"
        }
        if totalSeconds >= 0 {
            let seconds = (totalSeconds % 3600) % 60
            let unit = (seconds == 1 ) ? "second":"seconds"
            totalTime = totalTime + "\(seconds) \(unit)"
        }
        return totalTime
    }
}
