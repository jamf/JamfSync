//
//  Copyright 2024, Jamf
//
// From https://stackoverflow.com/questions/41561853/couldnt-encode-plus-character-in-url-swift

import Foundation

extension CharacterSet {
    static let rfc3986Unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
