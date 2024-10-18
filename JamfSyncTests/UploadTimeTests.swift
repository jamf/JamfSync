//
//  UploadTimeTests.swift
//  Jamf SyncTests
//
//  Created by Harry Strand on 10/10/24.
//

@testable import Jamf_Sync
import XCTest

final class UploadTimeTests: XCTestCase {
    let uploadTime = UploadTime()

    func testUploadTime_zero() throws {
        // Given

        // When
        let result = uploadTime.total()

        // Then
        XCTAssertEqual(result, "0 seconds")
    }

    func testUploadTime_partialMinute() throws {
        // Given
        uploadTime.start = Date().timeIntervalSinceNow
        uploadTime.end = uploadTime.start + 53

        // When
        let result = uploadTime.total()

        // Then
        XCTAssertEqual(result, "53 seconds")
    }

    func testUploadTime_multipleMinutesEven() throws {
        // Given
        uploadTime.start = Date().timeIntervalSinceNow
        uploadTime.end = uploadTime.start + 180

        // When
        let result = uploadTime.total()

        // Then
        XCTAssertEqual(result, "3 minutes")
    }

    func testUploadTime_multipleMinutesPlusSeconds() throws {
        // Given
        uploadTime.start = Date().timeIntervalSinceNow
        uploadTime.end = uploadTime.start + 187

        // When
        let result = uploadTime.total()

        // Then
        XCTAssertEqual(result, "3 minutes, 7 seconds")
    }

    func testUploadTime_multipleHoursEven() throws {
        // Given
        uploadTime.start = Date().timeIntervalSinceNow
        uploadTime.end = uploadTime.start + 10800

        // When
        let result = uploadTime.total()

        // Then
        XCTAssertEqual(result, "3 hours")
    }

    func testUploadTime_multipleMinutesPlusMinutesEven() throws {
        // Given
        uploadTime.start = Date().timeIntervalSinceNow
        uploadTime.end = uploadTime.start + 10920

        // When
        let result = uploadTime.total()

        // Then
        XCTAssertEqual(result, "3 hours, 2 minutes")
    }

    func testUploadTime_multipleMinutesPlusMinutesPlusSeconds() throws {
        // Given
        uploadTime.start = Date().timeIntervalSinceNow
        uploadTime.end = uploadTime.start + 10957

        // When
        let result = uploadTime.total()

        // Then
        XCTAssertEqual(result, "3 hours, 2 minutes, 37 seconds")
    }

}
