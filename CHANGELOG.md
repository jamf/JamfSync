# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.3] - 2024-09-20
### Bug fixes
- Changed the wording for the delete prompt to be a little less ambiguous.
- Added a potential fix for a DUPLICATE_FIELD error that would sometimes happen. 

## [1.3.2] - 2024-07-02
### Bug fixes
- Fixed an issue where it would fail to copy a file from a JCDS DP to a file share DP.

## [1.3.1] - 2024-06-25
### Bug fixes
- Fixed an issue where some package fields for packages on the server would be overwritten with default values when packages were updated.
- Made it so you can delete a package on the Jamf Pro server that doesn't have a file associated with it, as long as "Files and associated packages" is selected.
- Fixed an issue where the Synchronize button may not activate after synchronization is completed.
- Made a change so when transferring files from JCDS distribution points to local or file share distribution points, it will retain the Posix and ACL permissions that are used when creating new files in the destination directory.
- Updated the command line argument help and the documentation regarding that.
- Made a change so that if connecting to a Jamf Pro server fails due to invalid credentials, it will prompt for credentials.
- Changed the prompt for the file share password to include the server address so it is more obvious what password to specify.

## [1.3.0] - 2024-05-08
### Features
- Added buttons below the source and destination distribution point to allow local files to be added or removed directly to/from the distribution point.
- Added the ability to copy selected log messages to the clipboard.
- Added support for mpkg files.
### Bug fixes
- Changed the timeout for uploads to an hour to solve an issue with large uploads. This does not solve the issue with files > 5 GB that are uploaded to a JCDS2 DP.
- Fixed an issue with the "Cloud" DP type where the file progress wasn't quite right.

## [1.2.0] - 2024-04-16
### Features
- Added the ability to use the v1/packages endpoint on Jamf Pro version 11.5 and above, which includes the ablity to upload files to any cloud instance that Jamf Pro supports. It shows up as a distribution point called "Cloud", but only for the destination since there isn't a way to download those files at this time.
### Enhancements
- Made the column headers resizable.
- Made it so it will show packages ending with ".pkg.zip" and if a package is non-flat (right click menu has "Show Package Contents"), it will only show up in the list if it doesn't have a corresponding ".pkg.zip" file. When a non-flat package is transferred, it will create a corresponding ".pkg.zip" file in the same directory and just transfer that.
- Updated the About view.
### Bug fixes
- Fixed an issue where files containing a "+" (and possibly other characters) would fail to upload to JCDS2 distribution points.

## [1.1.0] - 2024-03-19
### Features
- Made the package, savable item and the log message list columns sortable by clicking on the column headers.
### Enhancements
- Update AWS signature/header generation to AWS Signature Version 4 format, which improves JCDS 2 support.
- Replaced CommonCrypto with CrytoKit.
### Bug fixes
- Fixed an issue where it could indicate that JCDS2 was available when it was not.
- Fixed an issue where the icons in the source list could be incorrect.

## [1.0.0] - 2024-02-09
- First public release.
- Synchronization between local folders, and file shares and JCDS2 distribution points from Jamf Pro instances.
- Made checksum calculations on-demand instead of automatic.
