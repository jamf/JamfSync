//
//  Copyright 2024, Jamf
//

import Cocoa
import CryptoKit
import Foundation

class CompleteMultipart: NSObject {
    var partNumber: Int
    var eTag: String
    
    init(partNumber: Int, eTag: String) {
        self.partNumber = partNumber
        self.eTag = eTag
    }
}
var partNumberEtagList = [CompleteMultipart]()

struct Chunk {
    static var all               = 0
    static var size              = 1024 * 1024 * 10
    static var index             = 1
    static var numberOf          = 0
    static var previousSignature = ""
    static var authHeader        = ""
}

func tagValue(xmlString:String, startTag:String, endTag:String, includeTags: Bool) -> String {
    var rawValue = ""
    if let start = xmlString.range(of: startTag),
        let end  = xmlString.range(of: endTag, range: start.upperBound..<xmlString.endIndex) {
        rawValue.append(String(xmlString[start.upperBound..<end.lowerBound]))
    }
    if includeTags {
        return "\(startTag)\(rawValue)\(endTag)"
    } else {
        return rawValue
    }
}
