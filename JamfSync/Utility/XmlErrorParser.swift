//
//  Copyright 2024, Jamf
//

import Foundation

enum XmlErrorField {
    case code
    case message
    case proposedSize
    case maxSizeAllowed
    case requestId
    case hostId
}

class XmlErrorParser : NSObject, XMLParserDelegate {
    var field: XmlErrorField?
    var parseError: Error?
    var code: String?
    var message: String?
    var proposedSize: String?
    var maxAllowedSize: String?
    var requestId: String?
    var hostId: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        switch elementName {
        case "Code":
            field = .code
        case "Message":
            field = .message
        case "ProposedSize":
            field = .proposedSize
        case "MaxSizeAllowed":
            field = .maxSizeAllowed
        case "RequestId":
            field = .requestId
        case "HostId":
            field = .hostId
        default:
            field = nil
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if (!value.isEmpty) {
            switch field {
            case .code:
                code = value
            case .message:
                message = value
            case .proposedSize:
                proposedSize = value
            case .maxSizeAllowed:
                maxAllowedSize = value
            case .requestId:
                requestId = value
            case .hostId:
                hostId = value
            default:
                break
            }
        }
    }

    func parser(
        _ parser: XMLParser,
        parseErrorOccurred parseError: Error
    ) {
        self.parseError = parseError
    }
}
