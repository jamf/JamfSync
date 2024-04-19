//
//  Copyright 2024, Jamf
//

import Foundation

class ArgumentParser: NSObject {
    var srcDp: String?
    var dstDp: String?
    var forceSync = false
    var removeFilesNotOnSrc = false
    var removePackagesNotOnSrc = false
    var showProgress = false
    var someArgumentsPassed = false
    private var arguments: [String]

    init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }
    
    fileprivate func processStringArg(_ i: inout Int) -> String? {
        var stringArg: String?
        if i < CommandLine.arguments.count - 1 {
            stringArg = arguments[i + 1]
            i = i + 1
        }
        return stringArg
    }
    
    func processArgs() -> Bool {
        var i = 1
        while i < arguments.count  {
            let arg = arguments[i]
            switch arg {
            case "-h", "--help", "-help":
                displayHelp()
                someArgumentsPassed = true
                return false
            case "-v", "--version", "-version":
                displayVersion()
                someArgumentsPassed = true
                return false
            case "-s", "--srcDp", "-srcDp":
                if let arg = processStringArg(&i) {
                    srcDp = arg
                }
                someArgumentsPassed = true
            case "-d", "--dstDp", "-dstDp":
                if let arg = processStringArg(&i) {
                    dstDp = arg
                }
                someArgumentsPassed = true
            case "-f", "--forceSync", "-forceSync":
                forceSync = true
                someArgumentsPassed = true
            case "-r", "--removeFilesNotOnSource", "-removeFilesNotOnSource":
                removeFilesNotOnSrc = true
                someArgumentsPassed = true
            case "-rp", "--removePackagesNotOnSource", "-removePackagesNotOnSource":
                removePackagesNotOnSrc = true
                someArgumentsPassed = true
            case "-p", "--progress", "-progress":
                showProgress = true
                someArgumentsPassed = true
           case "-NSDocumentRevisionsDebugMode":
                _ = processStringArg(&i)
            default:
                print("Unknown argument: " + arg)
                print("Use -h or --help to get the valid parameters. NOTE: The UI will start when invalid parameters are specified.")
                // Have to return true so it won't exit since otherwise it stops any previews from working.
                // There doens't seem to be a way to determine what command line arguments are passed during
                // a preview, otherwise we could just ignore them like with -NSDocumentRevisionsDebugMode.
                return true
            }
            i = i + 1
        }

        return validateArgs()
    }
    
    func displayHelp() {
        displayVersion()
        
        print("NOTE: Run JamfSync with no parameters first to add Jamf Pro servers and/or folders.")
        print("      Passwords for Jamf Pro servers and distribution points must be stored in the")
        print("      keychain in order to synchronize via command line arguments.")
        print("")
        print("Usage:")
        print("\tJamfSync [(-s | --srcDp) <name>] [(-d | --dstDp) <name>] [(-f | --forceSync)] [(-r | --removeFilesNotOnSource)] [(-rp | --removePackagesNotOnSource)] [-p | --progress]")
        print("\tJamfSync [-h | --help]")
        print("\tJamfSync [-v | --version]")
        print("")
        print("\t-s --srcDp:\t\tThe name of the source distribution point or folder.")
        print("\t-d --dstDp:\t\tThe name of the destination distribution point or folder.")
        print("\t-f --forceSync:\t\tForce synchronization of all files even if they appear to match on both the source and destination.")
        print("\t-r --removeFilesNotOnSource:\t\tDelete files on the destination that are not on the source. No delete is done if ommitted.")
        print("\t-rp --removePackagesNotOnSource:\t\tDelete packages on the destination's Jamf Pro instance that are not on the source. No delete is done if ommitted.")
        print("\t-p --progress:\t\tShow the progress of files being copied.")
        print("\t-v --version:\t\tDisplay the version number and build number.")
        print("\t-h --help:\t\tShows this help text.")
        print("NOTE: If a distribution point name is the same on multiple Jamf Pro instances, use \"dpName:jamfProName\" for the name.")
        print("")
        print("Examples:")
        print("\t\"/Applications/Jamf Sync.app/Contents/MacOS/Jamf Sync\" -srcDp localSourceName -dstDp destinationSourceName --removeFilesNotOnSource --progress")
        print("\t\"/Applications/Jamf Sync.app/Contents/MacOS/Jamf Sync\" -s \"JCDS:Stage\" -d \"JCDS:Prod\" -r -rp -p")
        print("\t\"/Applications/Jamf Sync.app/Contents/MacOS/Jamf Sync\" -s localSourceName -d destinationSourceName")
        print("")
    }
    
    func displayVersion() {
        let versionInfo = VersionInfo()
        print(versionInfo.getDisplayVersion())
    }

    func validateArgs() -> Bool {
        // Either none or both, but not one or the other
        if (srcDp == nil && dstDp == nil) || (srcDp != nil && dstDp != nil) {
            return true
        } else {
            print("Both the source and the destination arguments are required.")
            print("")
            displayHelp()
            return false
        }
    }
}
