//
//  AmazonS3.swift
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

struct Chunk {
    static var all               = 0
    static var size              = 1024*1024*10       //  1024*1024 = 1 MB
    static var index             = 1
    static var numberOf          = 0
    static var previousSignature = ""
    static var authHeader        = ""
}

// for aws uri encoding
//var myCharacterSet = CharacterSet()
var partNumberEtagList = [CompleteMultipart]()

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

/*
class AmazonS3: NSObject, URLSessionDelegate {
    
    static let shared = AmazonS3()
    private override init() {
        // character set for asw header uri encoding
//        myCharacterSet.formUnion(.alphanumerics)
//        myCharacterSet.insert(charactersIn: "/-._~")
    }
    
    let theFetchQ    = OperationQueue() // queue to fetch package info
        
    func awsSignatureV4(securityToken: String, httpMethod: String, date: String, accessKeyId: String, secretAccessKey: String, bucketName: String, scope: String, region: String, key: String, hashedPayload: String, contentType: String, currentDate: String) -> String {
//        print("[awsSignatureV4] date: \(date)")
        
//        let hashData = Data(hashedPayload.utf8)
//        let hexOfHash = hashData.compactMap{ String(format: "%02x", $0) }.joined()
//        print("[awsSignatureV4] hashedPayload: \(hashedPayload)")
//        print("[awsSignatureV4]     hexOfHash: \(hexOfHash)")
        
        var requestHeaders = [String:String]()
//        requestHeaders["content-type"] = "\(contentType)"
        requestHeaders["date"] = currentDate
//        requestHeaders["host"] = "d16vpbjriqjkeo.cloudfront.net"
        requestHeaders["host"] = "\(bucketName).s3.amazonaws.com"
        requestHeaders["x-amz-content-sha256"] = ( httpMethod == "GET" || httpMethod == "HEAD" ) ? "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855":"UNSIGNED-PAYLOAD"
//        requestHeaders["x-amz-content-sha256"] = hashedPayload
        requestHeaders["x-amz-date"] = date
        if (httpMethod != "GET" && httpMethod != "HEAD") {
            requestHeaders["x-amz-security-token"] = securityToken
        }
        
        var sortedHeaders = ""
        var signedHeaders = ""
        for (key, value) in requestHeaders.sorted(by: { $0.0 < $1.0 }) {
            sortedHeaders.append("\(key.lowercased()):\(value)\n")
            signedHeaders.append("\(key.lowercased());")
        }
        sortedHeaders = String(sortedHeaders.dropLast())
        signedHeaders = String(signedHeaders.dropLast())
//        print("[awsSignatureV4] \(#line) key: \(key)")
        var canonicalURI = key.removingPercentEncoding
        canonicalURI = canonicalURI?.addingPercentEncoding(withAllowedCharacters: myCharacterSet) ?? ""
//        print("[awsSignatureV4] \(#line) canonicalURI: \(canonicalURI ?? "")")
        
        // CANONICAL REQUEST //
        let canonicalRequest = """
        \(httpMethod.uppercased())
        /\(canonicalURI ?? "")
        
        \(sortedHeaders)
        
        \(signedHeaders)
        \(requestHeaders["x-amz-content-sha256"] ?? "UNSIGNED-PAYLOAD")
        """
        
        let canonicalRequestData = Data(canonicalRequest.utf8)
        let canonicalRequestDataHashed = SHA256.hash(data: canonicalRequestData)
        let canonicalRequestString = canonicalRequestDataHashed.compactMap { String(format: "%02x", $0) }.joined()
        
//        print("[awsSignatureV4]   canonicalRequestString: \(canonicalRequestString)")
        
        let scope = "\(date.prefix(8))/\(region)/s3/aws4_request"
        // STRING TO SIGN
        let stringToSign = """
            AWS4-HMAC-SHA256
            \(date)
            \(scope)
            \(canonicalRequestString)
            """

//        print("\n[awsSignature] stringToSign: \n\(stringToSign)\n")
//        print("[awsSignatureV4] canonicalRequest: \n\(canonicalRequest)")
        
        let hexOfFinalSignature = hmac_sha256(date: "\(date.prefix(8))", secretAccessKey: secretAccessKey, region: region, stringToSign: stringToSign)
        
        return hexOfFinalSignature
    }
    
    func hmac_sha256(date: String, secretAccessKey: String, region: String, stringToSign: String) -> String {
       
        let aws4SecretKey = Data("AWS4\(secretAccessKey)".utf8)
        let dateStampData = Data(date.utf8)
        let regionNameData = Data(region.utf8)
        let serviceNameData = Data("s3".utf8)
        let aws4_requestData = Data("aws4_request".utf8)
        let stringToSignData = Data(stringToSign.utf8)
        
        var symmetricKey = SymmetricKey(data: aws4SecretKey)
        let dateKey = HMAC<SHA256>.authenticationCode(for: dateStampData, using: symmetricKey)

        symmetricKey = SymmetricKey(data: Data(dateKey))
        let dateRegionKey = HMAC<SHA256>.authenticationCode(for: regionNameData, using: symmetricKey)

        symmetricKey = SymmetricKey(data: Data(dateRegionKey))
        let dateRegionServiceKey = HMAC<SHA256>.authenticationCode(for: serviceNameData, using: symmetricKey)

        symmetricKey = SymmetricKey(data: Data(dateRegionServiceKey))
        let signingKey = HMAC<SHA256>.authenticationCode(for: aws4_requestData, using: symmetricKey)
        
        symmetricKey = SymmetricKey(data: Data(signingKey))
        let finalSigningSHA256 = HMAC<SHA256>.authenticationCode(for: stringToSignData, using: symmetricKey)
        let hmac_sha256String = Data(finalSigningSHA256).map { String(format: "%02x", $0) }.joined()
        
//        print("[awsSignature] hmac_sha256String: \(hmac_sha256String)")
        
        return hmac_sha256String
        
    }
    
    /*
    func location(whichServer: String, theRegion: String = "", completion: @escaping (_ returnInfo: String) -> Void) {
        
        var region          = (theRegion == "") ? "x":theRegion
        
        let bucketName      = JamfProServer.bucket[whichServer] ?? ""
        let accessKeyId     = JamfProServer.accessKey[whichServer] ?? ""
        let secretAccessKey = JamfProServer.secret[whichServer] ?? ""
        
//        let hostString = "d16vpbjriqjkeo.cloudfront.net"
        let hostString = "\(bucketName).s3.amazonaws.com"
        
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: currentDate)
        
        let scope = "\(dateString.prefix(8))/\(region)/s3/aws4_request"
        
        let session: URLSession = URLSession(configuration: .default,
                                             delegate: self,
                                             delegateQueue: theFetchQ)
        var request = URLRequest(url: URL(string: "https://\(hostString)")!,
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        
        request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
        request.addValue(hostString, forHTTPHeaderField: "Host")
        request.addValue("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", forHTTPHeaderField: "x-amz-content-sha256")
        request.addValue(dateString, forHTTPHeaderField: "x-amz-date")

        let signatureProvided = "\(awsSignatureV4(securityToken: "", httpMethod: "GET", date: dateString, accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucketName, scope: scope, region: region, key: "", hashedPayload: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", contentType: "", currentDate: "\(currentDate)"))"
        
        request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(scope),SignedHeaders=date;host;x-amz-content-sha256;x-amz-date,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")
        
        request.httpMethod = "GET"
//        print("[location] all headers \(request.allHTTPHeaderFields ?? [:])")
        
        URLCache.shared.removeAllCachedResponses()

        WriteToLog.shared.message(stringOfText: "[listFiles] file list for Amazon S3.")
        
        let task = session.dataTask(with: request) { (data, response, error) in
            
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                print("[listFiles] status code: \(httpResponse.statusCode)")
//                if httpSuccess.contains(httpResponse.statusCode) {
                    if let error = error {
                        print("[listFiles] Error: \(error)")
                        
                        WriteToLog.shared.message(stringOfText: "[listFiles] list error: \(error)")
                    } else if let data = data {
                        let responseString = String(data: data, encoding: .utf8) ?? ""
                        region = tagValue(xmlString: responseString, startTag: "<Region>", endTag: "</Region>", includeTags: false)
//                        print("[listFiles] list response: \(region)")
                    }
//                }
            }
            JamfProServer.bucket[whichServer] = bucketName
            JamfProServer.accessKey[whichServer] = accessKeyId
            JamfProServer.secret[whichServer] = secretAccessKey
            JamfProServer.region[whichServer] = region
            if region != "x" {
                completion(region)
            } else {
                // prompt for region
                print("[bucket location] prompt for")
            }
        }
        task.resume()
    }
    */
    
    /*
     // uses core datalistFiles(which
    func listFiles(whichServer: String, displayName: String, completion: @escaping (_ result: (Int,[jcds2PackageInfo])) -> Void) {
        
        if let theIndex = s3dps.firstIndex(where: { $0.displayName == displayName }) {
            let theBucket = s3dps[theIndex]
            let region = theBucket.region ?? ""
            
            var statusCode      = 0
            let bucketName      = theBucket.bucketName ?? ""
            let accessKeyId     = theBucket.accessKey ?? ""
            var secretAccessKey = ""
            
            (_, secretAccessKey) = credentialsCheck(path: "\(bucketName).s3.amazonaws.com", account: accessKeyId)
            JamfProServer.bucket[whichServer]    = theBucket.bucketName ?? ""
            JamfProServer.accessKey[whichServer] = theBucket.accessKey ?? ""
            JamfProServer.secret[whichServer]    = secretAccessKey
            JamfProServer.region[whichServer]    = region
            
            //        let hostString = "d16vpbjriqjkeo.cloudfront.net"
            let hostString = "\(bucketName).s3.amazonaws.com"
            
//            print("[listFiles]  hostString: \(hostString)")
//            print("[listFiles]  bucketName: \(bucketName)")
//            print("[listFiles] accessKeyId: \(accessKeyId)")
//            print("[listFiles]      secret: \(secretAccessKey)")
            
            let currentDate = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            let dateString = dateFormatter.string(from: currentDate)
            
            let scope = "\(dateString.prefix(8))/\(region)/s3/aws4_request"
            
            var listJcds2PackageInfo = [jcds2PackageInfo]()
            
            let session: URLSession = URLSession(configuration: .default,
                                                 delegate: self,
                                                 delegateQueue: theFetchQ)
            var request = URLRequest(url: URL(string: "https://\(hostString)")!,
                                     cachePolicy: .reloadIgnoringLocalCacheData)
            
            request.addValue("\(currentDate)", forHTTPHeaderField: "Date")
            request.addValue(hostString, forHTTPHeaderField: "Host")
            request.addValue("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", forHTTPHeaderField: "x-amz-content-sha256")
            request.addValue(dateString, forHTTPHeaderField: "x-amz-date")
            
            let signatureProvided = "\(awsSignatureV4(securityToken: "", httpMethod: "GET", date: dateString, accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucketName, scope: scope, region: region, key: "", hashedPayload: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", contentType: "", currentDate: "\(currentDate)"))"
            
            request.addValue("AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(dateString.prefix(8))/\(region)/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date,Signature=\(signatureProvided)", forHTTPHeaderField: "Authorization")
            
            request.httpMethod = "GET"
//            print("[listFiles] all headers \(request.allHTTPHeaderFields ?? [:])")
            
            URLCache.shared.removeAllCachedResponses()
            
            WriteToLog.shared.message(stringOfText: "[listFiles] file list for Amazon S3.")
            
            let task = session.dataTask(with: request) { (data, response, error) in
                
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    print("[listFiles] status code: \(httpResponse.statusCode)")
                    statusCode = httpResponse.statusCode
                }
                if let error = error {
                    print("[listFiles] Error: \(error)")
                    
                    WriteToLog.shared.message(stringOfText: "[listFiles] list error: \(error)")
                } else if let data = data {
                    let responseData = String(data: data, encoding: .utf8)
//                    print("[listFiles] list response: \(responseData ?? "unknown")")
                    
                    
                    var packageNameDict = [String:[String]]()
                    var duplicagePackages = ""
                    // We can create a parser from a URL, a Stream, or NSData.
                    let xmlParser = XMLParser(data: data)
                    let delegate = S3XmlDelegate()
                    xmlParser.delegate = delegate
                    if xmlParser.parse() {
//                        for entry in delegate.packageArray {
//                            print("[ListPackages.listCloudPackages] name: \(entry.filename)")
//                            print("[ListPackages.listCloudPackages] size: \(entry.size)\n")
//                            WriteToLog.shared.message(stringOfText: "[ListPackages.listCloudPackages] name: \(entry.filename)")
                            if whichServer == "source" {
                                defaults.set("unmounted", forKey: "share")
                                defaults.set("server", forKey: "packageSource")
                                sourceJcds2PackageInfo.removeAll()
                                for thePackage in delegate.packageArray {
                                    listJcds2PackageInfo.append(jcds2PackageInfo(id: -1, fileName: thePackage.filename, displayName: "", length: Int(thePackage.size) ?? 0, status: "", md5: "", region: ""))
                                }
                            } else if whichServer == "destination" {
                                destinationJcds2PackageInfo.removeAll()
//                                print("[jcdsVersion] clear destinationJcds2PackageInfo\n")
                                for thePackage in delegate.packageArray {
                                    listJcds2PackageInfo.append(jcds2PackageInfo(id: -1, fileName: thePackage.filename, displayName: "", length: Int(thePackage.size) ?? 0, status: "", md5: "", region: ""))
                                }
                            }
//                        }
                    }
                }
                completion((statusCode, listJcds2PackageInfo))
            }
            task.resume()
        }
    }
    */
}
*/
