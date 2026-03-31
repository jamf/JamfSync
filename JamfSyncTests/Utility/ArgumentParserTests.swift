//
//  Copyright 2026, Jamf
//

@testable import Jamf_Sync
import XCTest

final class ArgumentParserTests: XCTestCase {

    // MARK: - processArgs tests with help and version

    func test_processArgs_help_shortForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-h"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should return false to indicate program should exit")
        XCTAssertTrue(parser.someArgumentsPassed)
        XCTAssertNil(parser.srcDp)
        XCTAssertNil(parser.dstDp)
    }

    func test_processArgs_help_longForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "--help"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should return false to indicate program should exit")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    func test_processArgs_help_noPrefix() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-help"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should return false to indicate program should exit")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    func test_processArgs_version_shortForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-v"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should return false to indicate program should exit")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    func test_processArgs_version_longForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "--version"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should return false to indicate program should exit")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    func test_processArgs_version_noPrefix() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-version"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should return false to indicate program should exit")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    // MARK: - processArgs tests with source and destination

    func test_processArgs_sourceAndDestination_shortForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "SourceDP", "-d", "DestDP"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result, "Should return true for valid arguments")
        XCTAssertEqual(parser.srcDp, "SourceDP")
        XCTAssertEqual(parser.dstDp, "DestDP")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    func test_processArgs_sourceAndDestination_longForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "--srcDp", "SourceDP", "--dstDp", "DestDP"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result, "Should return true for valid arguments")
        XCTAssertEqual(parser.srcDp, "SourceDP")
        XCTAssertEqual(parser.dstDp, "DestDP")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    func test_processArgs_sourceAndDestination_noPrefix() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-srcDp", "SourceDP", "-dstDp", "DestDP"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result, "Should return true for valid arguments")
        XCTAssertEqual(parser.srcDp, "SourceDP")
        XCTAssertEqual(parser.dstDp, "DestDP")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    func test_processArgs_sourceAndDestination_withColons() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "JCDS:Stage", "-d", "JCDS:Prod"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result, "Should return true for valid arguments")
        XCTAssertEqual(parser.srcDp, "JCDS:Stage")
        XCTAssertEqual(parser.dstDp, "JCDS:Prod")
    }

    // MARK: - processArgs tests with flags

    func test_processArgs_forceSync_shortForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "-f"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.forceSync)
    }

    func test_processArgs_forceSync_longForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "--forceSync"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.forceSync)
    }

    func test_processArgs_removeFilesNotOnSrc_shortForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "-r"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.removeFilesNotOnSrc)
    }

    func test_processArgs_removeFilesNotOnSrc_longForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "--removeFilesNotOnSource"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.removeFilesNotOnSrc)
    }

    func test_processArgs_removePackagesNotOnSrc_shortForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "-rp"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.removePackagesNotOnSrc)
    }

    func test_processArgs_removePackagesNotOnSrc_longForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "--removePackagesNotOnSource"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.removePackagesNotOnSrc)
    }

    func test_processArgs_showProgress_shortForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "-p"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.showProgress)
    }

    func test_processArgs_showProgress_longForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "--progress"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.showProgress)
    }

    func test_processArgs_dryRun_shortForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "-dr"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.dryRun)
    }

    func test_processArgs_dryRun_longForm() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "--dryRun"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.dryRun)
    }

    func test_processArgs_allFlags() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "-f", "-r", "-rp", "-p", "-dr"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.forceSync)
        XCTAssertTrue(parser.removeFilesNotOnSrc)
        XCTAssertTrue(parser.removePackagesNotOnSrc)
        XCTAssertTrue(parser.showProgress)
        XCTAssertTrue(parser.dryRun)
    }

    // MARK: - processArgs validation tests

    func test_processArgs_sourceOnly_fails() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "SourceDP"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should fail when only source is provided")
        XCTAssertEqual(parser.srcDp, "SourceDP")
        XCTAssertNil(parser.dstDp)
    }

    func test_processArgs_destinationOnly_fails() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-d", "DestDP"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should fail when only destination is provided")
        XCTAssertNil(parser.srcDp)
        XCTAssertEqual(parser.dstDp, "DestDP")
    }

    func test_processArgs_noArguments_succeeds() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result, "Should succeed with no arguments (launches UI)")
        XCTAssertNil(parser.srcDp)
        XCTAssertNil(parser.dstDp)
        XCTAssertFalse(parser.someArgumentsPassed)
    }

    func test_processArgs_sourceMissingValue() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should fail validation")
        XCTAssertNil(parser.srcDp, "Source should be nil when no value provided")
        XCTAssertTrue(parser.someArgumentsPassed)
    }

    func test_processArgs_destinationMissingValue() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertFalse(result, "Should fail validation")
        XCTAssertEqual(parser.srcDp, "Src")
        XCTAssertNil(parser.dstDp, "Destination should be nil when no value provided")
    }

    // MARK: - processArgs tests with unknown arguments

    func test_processArgs_unknownArgument_returnsTrue() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-unknown"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result, "Should return true for unknown arguments to allow UI to start (for preview support)")
    }

    func test_processArgs_NSDocumentRevisionsDebugMode_ignored() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-NSDocumentRevisionsDebugMode", "YES"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result, "Should ignore NSDocumentRevisionsDebugMode argument")
        XCTAssertFalse(parser.someArgumentsPassed)
    }

    // MARK: - validateArgs tests

    func test_validateArgs_bothSourceAndDestination() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName"])
        parser.srcDp = "Src"
        parser.dstDp = "Dst"

        // When
        let result = parser.validateArgs()

        // Then
        XCTAssertTrue(result)
    }

    func test_validateArgs_neitherSourceNorDestination() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName"])

        // When
        let result = parser.validateArgs()

        // Then
        XCTAssertTrue(result, "Should be valid when neither are provided")
    }

    func test_validateArgs_sourceOnlyWithoutDestination() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName"])
        parser.srcDp = "Src"

        // When
        let result = parser.validateArgs()

        // Then
        XCTAssertFalse(result, "Should be invalid with only source")
    }

    func test_validateArgs_destinationOnlyWithoutSource() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName"])
        parser.dstDp = "Dst"

        // When
        let result = parser.validateArgs()

        // Then
        XCTAssertFalse(result, "Should be invalid with only destination")
    }

    // MARK: - Complex argument order tests

    func test_processArgs_argumentsInDifferentOrder() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-p", "-d", "Dst", "-r", "-s", "Src", "-f"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(parser.srcDp, "Src")
        XCTAssertEqual(parser.dstDp, "Dst")
        XCTAssertTrue(parser.showProgress)
        XCTAssertTrue(parser.removeFilesNotOnSrc)
        XCTAssertTrue(parser.forceSync)
    }

    func test_processArgs_flagsBeforeSourceAndDestination() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-f", "-r", "-rp", "-s", "Src", "-d", "Dst"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.forceSync)
        XCTAssertTrue(parser.removeFilesNotOnSrc)
        XCTAssertTrue(parser.removePackagesNotOnSrc)
    }

    func test_processArgs_flagsAfterSourceAndDestination() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Src", "-d", "Dst", "-f", "-r", "-rp"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(parser.forceSync)
        XCTAssertTrue(parser.removeFilesNotOnSrc)
        XCTAssertTrue(parser.removePackagesNotOnSrc)
    }

    // MARK: - Edge cases

    func test_processArgs_emptyStringValues() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "", "-d", ""])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result, "Should accept empty strings")
        XCTAssertEqual(parser.srcDp, "")
        XCTAssertEqual(parser.dstDp, "")
    }

    func test_processArgs_spaceInValues() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Source DP", "-d", "Dest DP"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(parser.srcDp, "Source DP")
        XCTAssertEqual(parser.dstDp, "Dest DP")
    }

    func test_processArgs_specialCharactersInValues() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "Source@#$%", "-d", "Dest!&*()"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(parser.srcDp, "Source@#$%")
        XCTAssertEqual(parser.dstDp, "Dest!&*()")
    }

    // MARK: - Default values tests

    func test_initialState_allFlagsFalse() throws {
        // Given
        let parser = ArgumentParser(arguments: ["ProgramName"])

        // Then
        XCTAssertFalse(parser.forceSync)
        XCTAssertFalse(parser.removeFilesNotOnSrc)
        XCTAssertFalse(parser.removePackagesNotOnSrc)
        XCTAssertFalse(parser.showProgress)
        XCTAssertFalse(parser.dryRun)
        XCTAssertFalse(parser.someArgumentsPassed)
        XCTAssertNil(parser.srcDp)
        XCTAssertNil(parser.dstDp)
    }

    // MARK: - Real-world example tests

    func test_processArgs_realWorldExample1() throws {
        // Given - Example from the help text
        let parser = ArgumentParser(arguments: ["ProgramName", "-srcDp", "localSourceName", "-dstDp", "destinationSourceName", "--removeFilesNotOnSource", "--progress"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(parser.srcDp, "localSourceName")
        XCTAssertEqual(parser.dstDp, "destinationSourceName")
        XCTAssertTrue(parser.removeFilesNotOnSrc)
        XCTAssertTrue(parser.showProgress)
        XCTAssertFalse(parser.forceSync)
        XCTAssertFalse(parser.removePackagesNotOnSrc)
    }

    func test_processArgs_realWorldExample2() throws {
        // Given - Example from the help text
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "JCDS:Stage", "-d", "JCDS:Prod", "-r", "-rp", "-p"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(parser.srcDp, "JCDS:Stage")
        XCTAssertEqual(parser.dstDp, "JCDS:Prod")
        XCTAssertTrue(parser.removeFilesNotOnSrc)
        XCTAssertTrue(parser.removePackagesNotOnSrc)
        XCTAssertTrue(parser.showProgress)
    }

    func test_processArgs_realWorldExample3() throws {
        // Given - Example from the help text
        let parser = ArgumentParser(arguments: ["ProgramName", "-s", "localSourceName", "-d", "destinationSourceName"])

        // When
        let result = parser.processArgs()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(parser.srcDp, "localSourceName")
        XCTAssertEqual(parser.dstDp, "destinationSourceName")
        XCTAssertFalse(parser.removeFilesNotOnSrc)
        XCTAssertFalse(parser.removePackagesNotOnSrc)
        XCTAssertFalse(parser.showProgress)
        XCTAssertFalse(parser.forceSync)
        XCTAssertFalse(parser.dryRun)
    }
}
