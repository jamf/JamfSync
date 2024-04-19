# JamfSync
Utility for transferring files between file folders, Jamf Pro file share distribution points and Jamf Pro JDCS2 distribution points and updating the packages on Jamf Pro servers.

## Instructions
See JamfSync/Resources/Jamf Sync User Guide.pdf for help running Jamf Sync, or when running "Jamf Sync.app", click Help / Jamf Sync User Guide. 

## Features
- Handles multiple Jamf Pro servers, allowing moving packages from a test server to a production server or vice-versa.
- Can copy files between a Cloud DP, file share DP, or a local file folder.
- Can optionally delete files from the destination DP that are not on the source DP.
- Can optionally delete packages on the Jamf Pro server that are not on the source DP.
- Can treat a local file folder as a distribution point, allowing uploading and downloading of multiple packages.
- Handles automatically creating checksums for packages.
- Command line parameters allow for scripting synchronizations.
## Description
### Settings
- Add Jamf Pro servers and/or folders.
- Folders are treated as distribution points, allowing syncing between other distribution points or folders.
- When close is clicked, if changes were made, it will contact each Jamf Pro server to get the distribution points and will use them to populate the source and destination selection lists.
#### Add Jamf Pro Server
- The user can provide the Jamf Pro Server URL and either the user id and password or the client id and client secret, depending on whether the standard auth or OAuth (API roles and clients) is used.
- Can hit a "Test" button in order to verify that the Jamf Pro server is accessible with the settings.
- This will automatically add a cloud DP server and all the file share DPs that are in the Jamf Pro Server.
- Settings are stored locally. The credentials for Jamf Pro and file share distribution points will be securely stored in the keychain.
#### Add Local Folder
- Allows a local folder to be added, which will be presented to the user as an option to use as a source or destination. Folders are treated as distribution points, allowing synchronization between other distribution points or folders. It will contain a name and a directory location. The name will default to the directory name.
#### Edit
- Lets you edit whatever item is selected. If nothing is selected, the edit button is disabled.
#### Delete
- Lets you delete whatever item is selected. It will prompt for confirmation before deleting. If nothing is selected, the delete button is disabled.
### Main View
- The Synchronization button will be grayed out until both a source and destination are selected and the source and destination are different. This will syncrhonize from the source to the destination.
- The Force Sync checkbox will cause all source items to be copied even if the checksum on the destination matches. When it's not checked, only items added or changed will be synchronized.
- There is a picker for the source and for the destination, each of which contain a list of all folders and distribution points. Initially "--" is selected, which indicates no selection.
- A list of files on the selected source distribution point are on the left and the list of files on the destination distribution point is on the right. 
- When both a source and destination distribution point are selected, the Sync column will show an icon indicating what will happen during a syncrhonization. When the Sync icon has a color, it means that it will participate in a synchronization. If it's black and white, it will not. The sync icon will have a + if it will be added, a check mark if it will be updated, an X if it will be deleted from the destination (if they choose to after clicking Synchronize) and an = if the file on both the source and destination match.
- Items in the source list can be selected. If there are selected items, only these files will be synchronized and no files will be removed from the destination. If no files are selected, when the Syncrhonize button is pressed, you will be prompted about whether to delete items that are not on the source. If you choose Yes, then any files on the destination that show a red x symbol will be removed from the destination and list of packages in Jamf Pro.

## Command line parameters
NOTE: Run JamfSync with no parameters first to add Jamf Pro servers and/or folders.
      Passwords for Jamf Pro servers and distribution points must be stored in the
      keychain in order to synchronize via command line arguments.

Usage:
    JamfSync [(-s | --srcDp) <name>] [(-d | --dstDp) <name>] [(-f | --forceSync)] [(-r | --removeFilesNotOnSource)] [(-rp | --removePackagesNotOnSource)] [-p | --progress]
    JamfSync [-h | --help]
    JamfSync [-v | --version]

    -s --srcDp:        The name of the source distribution point or folder.
    -d --dstDp:        The name of the destination distribution point or folder.
    -f --forceSync:        Force synchronization of all files even if they appear to match on both the source and destination.
    -r --removeFilesNotOnSource:        Delete files on the destination that are not on the source. No delete is done if ommitted.
    -rp --removePackagesNotOnSource:        Delete packages on the destination's Jamf Pro instance that are not on the source. No delete is done if ommitted.
    -p --progress:        Show the progress of files being copied.
    -v --version:        Display the version number and build number.
    -h --help:        Shows this help text.
NOTE: If a distribution point name is the same on multiple Jamf Pro instances, use "dpName:jamfProName" for the name.

Examples:
    "/Applications/Jamf Sync.app/Contents/MacOS/Jamf Sync" -srcDp localSourceName -dstDp destinationSourceName --removeFilesNotOnSource --progress
    "/Applications/Jamf Sync.app/Contents/MacOS/Jamf Sync" -s "JCDS:Stage" -d "JCDS:Prod" -r -rp -p
    "/Applications/Jamf Sync.app/Contents/MacOS/Jamf Sync" -s localSourceName -d destinationSourceName

## Source Code Overview

The source code is located in several groups. 
- Model contains classes that are not directly related to the UI. 
- Inside the Model group is ViewModels, which is a more closely related to the UI but isn't specifically tied to it. Usually when fields in a view model change, the associated UI will automatically be redrawn. 
- Resources contains images and other files that are used by the program.
- UI contains the SwiftUI files for all the views that show up in the program, as well as JamfSyncApp, which is where the program exucution begins.
- Utility contains classes that perform more general tasks.

### Model
The files in the Model group are used to keep track of and process data that is used.

* **DataModel:** This represents the state of almost everything and contains data and functions that act on that data. It is responsible for loading data from core storage and also loading data for the distribution points. It has published variables that are used to control the UI. 

* **SavableItem:** The base class for anything that can be saved (JamfProInstance and FolderInstance).
These items are stored in Core Data. Passwords are not stored in core data but are instead stored in the keychain as long as the user allows it. The loadDps function is overridden by the specific child class and is responsible for loading all the distribution points associated with that item. The getDps function returns the distribution point(s) associated with that item.
    * JamfProInstance - This represents a Jamf Pro instance and is responsible for loading necessary data and communicating with the Jamf Pro APIs. It also creates and loads data for the distribution points associated with the Jamf Pro server. It also loads and stores package information from the Jamf Pro server.
    * FolderInstance - This represents a local directory on the computer. It creates a single FolderDp that acts like a distribution point during synchronization.

* **DistributionPoint:** The base class for all DistributionPoint objects (FileShareDp, Jcds2Dp & FolderDp)
The copyFiles function is the main function for synchronizing. It calls other functions that are overridden by the specific distribution point objects.
    * FileShareDp - The specific distribution point object for file share distribution points.
    * Jcds2Dp - The specific distribution point object for Cloud distribution points.
    * FolderDp - The specific distribution point object for Folder distributrion points (representing a local file folder).

* **Other objects:**
    * DpFile - Stores information for a single file. It also contains functions to maintain and compare its checksums.
    * DpFiles - Stores a list of files. It has functions to help find a particular file, update checksums for the files, and to update the state of each file that indicates the state of files.
    * Checksum - Represents a checksum of any type (usually SHA-512)
    * Checksums - An object that holds a list of Checksum objects and has functions to use on the collection of checksums.

#### ViewModels
The files in the ViewModels group are used to keep track of and process data that is used. Published variables will cause the assocated views to redraw.
    * LogViewModel - Used for the log view and the message that displays at the bottom of the screen.
    * SetupViewModel - Used for the setup view.
    * PackageListViewModel - Used for the source and destination file lists on the main view.
    * DpFileViewModel - Used for each file in the PackageListViewModel. It has a pointer to a specific DpFile instance and has UI specific fields.
    * DpFilesViewModel - Has an array of DpFileViewModel objects and is used to store the files in a PackageListViewModel object.

### UI
The files in the UI group are the SwiftUI files for the user interface. The data in DataModel is used to control the view. Anytime a property with @Published is changed, it will cause any views that use those fields to redraw.
- AboutView: A view that shows the version and other information.
- ChecksumView: Shows what checksums have been calculated for a file and presents a string with the actual checksums when hovered over.
- ConfirmationView: The view that is used to confirm various things
- ContentView: The main view that drives everything.
- FileSharePasswordView: Used to prompt for a file share password when it hasn't been stored in the keychain.
- FolderView: The view when adding or editing a folder
- HeaderView: The top portion of the ContentView that contains the Synchronization button and the Force Sync checkbox.
- JamfProPasswordView: Used to prompt for the Jamf Pro password when it hasn't been stored in the keychain.
- JamfProServerView: The view when adding or editing a Jamf Pro server
- JamfSyncApp: Main app that holds the ContentView
- LogMessageView: The view that briefly shows the log message at the bottom on the main view.
- LogView: The view that shows log messages
- PackageAnimationView: The view that shows the animation during synchronization.
- PackageListView: The view for the package list on the main view.
- SavableItemListView: The view for the list on the Setup view 
- SetupView: The main view for Setup
- SourceDestinationView: The portion of the MainView with the source and destination pickers and file lists.
- SynchronizationProgressView: The synchroniztion view that shows progress for an ongoing synchronization. This also starts the synchronization in **onAppear**.

### Utility
The files in the Utility group are helper classes for processing data and don't have a direct connection to the UI.
- ArgumentParser: Parses the command line arguments if there are any.
- CloudSessionDelegate: Handles URLSessionTaskDelegate and URLSessionDownloadDelegatedelegate functions when files are trasnfered to and from the cloud.
- FileHash: Creates file hash values. This is an actor class, so a function will only process one file at a time in order to prevent conflicts.
- FileShare: Handles mounting and unmounting a fileshare. This is an actor class in order to avoid conflicts.
- FileShares: Mounts shares or returns an already mounted file share. And unmoounts all mounted file shares. This is an actor class in order to avoid conflicts.
- KeychainHelper: Assists with storage and retrieval of keychain items.
- View+NSWindow: Used to display a view as its own window.
- UserSettings: Reads, saves and keeps track of data that is written to user settings.

## Expanding the types of distribution points supported by JamfSync
It would be handy to add distribution points for direct cloud connections, like for Rackspace, Amazon Web Services, Akamai. The following would need to be done in order to support one of these:
- Create an object that inherits SavableItem (like FolderInstance) and add member variables for each piece of info that will need to be provided.
- Create an object that inherits from DistributionPoint. See Jcds2Dp for an example of this. See FolderItem to see how this should be created and returned (like FolderDp is).
- Create an entity in StoredSettings.xcdatamodeld and set the parent to SavableItemData.
- Modify SetupView to be able to create, edit and delete the new item.
- Add a new object like JamfProServerView so the user can enter any necessary information.
- Use KeychainHelper to save credentials to the keychain and add additional service names (like fileShareServiceName) if necessary.
- Make sure existing unit tests pass and add additional unit tests to cover the changes you make.

## Improvements needed yet
- Create support for additional cloud distribution points like Rackspace, Amazon Web Services, Akamai, as described above.
- The cancel action needs to be improved. For FileShareDps and FolderDps, it doesn't cancel the current file that is being transferred so it can take quite a while to cancel.
- Make the lists sortable by any column.
- Make the list columns sizable.
- Add more unit test coverage (especially finish Jcds2DpTests and add unit tests for CommandLineProcessing).
- Improvements could be made to make it more accessible.
- Would be good to make it localizable and start adding some localizations.

## Contributing

To set up for local development, make a fork of this repo, make a branch on your fork named after
the issue or workflow you are improving, checkout your branch, then open the folder in Xcode.

This repository requires verified signed commits.  You can find out more about
[signing commits on GitHub Docs](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits).

### Pull requests

Before submitting your pull request, please do the following:

- If you are adding new commands or features, they should include unit tests.  If you are changing functionality, update the tests or add new tests as needed.
- Verify all unit tests pass.
- Add a note to the CHANGELOG describing what you changed.
- If your pull request is related to an issue, add a link to the issue in the description.

## Contributors

- Harry Strand
- Leslie Helou

