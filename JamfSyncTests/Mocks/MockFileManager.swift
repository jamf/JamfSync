//
//  Copyright 2024, Jamf
//

import Foundation

class MockFileManager: FileManager {
    var directoryContents: [URL] = []
    var fileAttributes: [ String: [FileAttributeKey : Any] ] = [:]
    var contentsOfDirectoryError: Error?
    var removeItemError: Error?
    var copyError: Error?
    var moveError: Error?
    var itemRemoved: URL?
    var srcItemMoved: URL?
    var dstItemMoved: URL?
    var srcItemCopied: URL?
    var dstItemCopied: URL?
    var unmountedMountPoint: URL?
    var fileExistsResponse = true
    var fileExistsResponseProvider: ((String, UnsafeMutablePointer<ObjCBool>?) -> Bool)?
    var directoryCreated: URL?
    var createDirectoryError: Error?
    var attributesSet: [String: [FileAttributeKey: Any]] = [:]

    override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        if let contentsOfDirectoryError {
            throw contentsOfDirectoryError
        }
        return directoryContents
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        if let attributes = fileAttributes[path] {
            return attributes
        }
        return [:]
    }

    override func removeItem(at URL: URL) throws {
        if let removeItemError {
            throw removeItemError
        }
        itemRemoved = URL
    }
    
    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if let moveError {
            throw moveError
        }
        srcItemMoved = srcURL
        dstItemMoved = dstURL
    }
    
    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        if let copyError {
            throw copyError
        }
        srcItemCopied = srcURL
        dstItemCopied = dstURL
    }

    override func unmountVolume(at url: URL, options mask: FileManager.UnmountOptions = []) async throws {
        unmountedMountPoint = url
    }

    override func fileExists(atPath path: String) -> Bool {
        if let provider = fileExistsResponseProvider {
            return provider(path, nil)
        }
        return fileExistsResponse
    }

    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        if let provider = fileExistsResponseProvider {
            return provider(path, isDirectory)
        }

        // Default behavior
        if let isDirectory {
            isDirectory.pointee = false
        }
        return fileExistsResponse
    }

    override func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        if let createDirectoryError {
            throw createDirectoryError
        }
        directoryCreated = url
    }

    override func setAttributes(_ attributes: [FileAttributeKey : Any], ofItemAtPath path: String) throws {
        attributesSet[path] = attributes
    }
}
