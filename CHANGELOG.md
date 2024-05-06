# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2024-05-6
### Features
- Added buttons below the source and destination distribution point to allow local files to the distribution point, or to remove files from the distribution point.
### Bug fixes
- Fixed an issue with the "Cloud" DP type where the file progress wasn't qute right.

## [1.2.0] - 2024-04-16
### Features
- Added the ability to use the v1/packages endpoint on Jamf Pro version 11.5 and above, which includes the ablity to upload files to any cloud instance that Jamf Pro supports. It shows up as a distribution point called "Cloud", but only for the destination since there isn't a way to download those files at this time.
### Enhancements
- Made the column headers resizable.
- Made it so it will show packages ending with ".app.zip" and if a package is non-flat (right click menu has "Show Package Contents"), it will only show up in the list if it doesn't have a corresponding ".app.zip" file. When a non-flat package is transferred, it will create a corresponding ".app.zip" file in the same directory and just transfer that.
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
