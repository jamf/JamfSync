//
//  Copyright 2024, Jamf
//

@testable import Jamf_Sync
import XCTest

final class XmlErrorParserTests: XCTestCase {
    func testParser_happyPath() throws {
        // Given
        let xmlContent =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <Error>
            <Code>EntityTooLarge</Code>
            <Message>Your proposed upload exceeds the maximum allowed size</Message>
            <ProposedSize>13630203999</ProposedSize>
            <MaxSizeAllowed>5368709120</MaxSizeAllowed>
            <RequestId>DV1FDVPNGBQ5M1PX</RequestId>
            <HostId>F9zqYNRz3MMZ5nsfIkkIgrjUK7STfn9CUiIB2TlmvbFXWA5M0N/4pIKIRMqpiIZXhlH2Cc0xEiY=</HostId>
        </Error>
        """;
        let xmlData = Data(xmlContent.utf8)
        let xmlParser = XMLParser(data: xmlData)
        let xmlErrorParser = XmlErrorParser()
        xmlParser.delegate = xmlErrorParser

        // When
        xmlParser.parse()
        
        // Then
        XCTAssertEqual(xmlErrorParser.code, "EntityTooLarge")
        XCTAssertEqual(xmlErrorParser.message, "Your proposed upload exceeds the maximum allowed size")
        XCTAssertEqual(xmlErrorParser.proposedSize, "13630203999")
        XCTAssertEqual(xmlErrorParser.maxAllowedSize, "5368709120")
        XCTAssertEqual(xmlErrorParser.requestId, "DV1FDVPNGBQ5M1PX")
        XCTAssertEqual(xmlErrorParser.hostId, "F9zqYNRz3MMZ5nsfIkkIgrjUK7STfn9CUiIB2TlmvbFXWA5M0N/4pIKIRMqpiIZXhlH2Cc0xEiY=")
        XCTAssertNil(xmlErrorParser.parseError)
    }

    func testParser_someMissingFields() throws {
        // Given
        let xmlContent =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <Error>
            <Code>EntityTooLarge</Code>
            <Message>Your proposed upload exceeds the maximum allowed size</Message>
        </Error>
        """;
        let xmlData = Data(xmlContent.utf8)
        let xmlParser = XMLParser(data: xmlData)
        let xmlErrorParser = XmlErrorParser()
        xmlParser.delegate = xmlErrorParser

        // When
        xmlParser.parse()

        // Then
        XCTAssertEqual(xmlErrorParser.code, "EntityTooLarge")
        XCTAssertEqual(xmlErrorParser.message, "Your proposed upload exceeds the maximum allowed size")
        XCTAssertNil(xmlErrorParser.proposedSize)
        XCTAssertNil(xmlErrorParser.maxAllowedSize)
        XCTAssertNil(xmlErrorParser.requestId)
        XCTAssertNil(xmlErrorParser.hostId)
        XCTAssertNil(xmlErrorParser.parseError)
    }

    func testParser_parsingError() throws {
        // Given
        let xmlContent =
        """
        This
        is not very good <xml data
        """;
        let xmlData = Data(xmlContent.utf8)
        let xmlParser = XMLParser(data: xmlData)
        let xmlErrorParser = XmlErrorParser()
        xmlParser.delegate = xmlErrorParser

        // When
        xmlParser.parse()

        // Then
        XCTAssertNil(xmlErrorParser.code, "EntityTooLarge")
        XCTAssertNil(xmlErrorParser.message, "Your proposed upload exceeds the maximum allowed size")
        XCTAssertNil(xmlErrorParser.proposedSize)
        XCTAssertNil(xmlErrorParser.maxAllowedSize)
        XCTAssertNil(xmlErrorParser.requestId)
        XCTAssertNil(xmlErrorParser.hostId)
        XCTAssertNotNil(xmlErrorParser.parseError)
    }
}
