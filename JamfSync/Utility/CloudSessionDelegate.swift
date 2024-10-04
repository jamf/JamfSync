//
//  Copyright 2024, Jamf
//

import Foundation

class CloudSessionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    let progress: SynchronizationProgress
    var dispatchGroup: DispatchGroup?
    var downloadLocation: URL?

    init(progress: SynchronizationProgress, dispatchGroup: DispatchGroup? = nil) {
        self.progress = progress
        self.dispatchGroup = dispatchGroup
    }
    
    // MARK: URLSessionTaskDelegate functions

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        print("[urlSession.CloudSessionDelegate] totalBytesTransferred: \(totalBytesSent), bytesTransferred: \(bytesSent)")
        progress.updateFileTransferInfo(totalBytesTransferred: totalBytesSent, bytesTransferred: bytesSent)
    }

    // MARK: URLSessionDownloadDelegate functions

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        progress.updateFileTransferInfo(totalBytesTransferred: totalBytesWritten, bytesTransferred: bytesWritten)
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        self.downloadLocation = location
        dispatchGroup?.leave()
    }
}
