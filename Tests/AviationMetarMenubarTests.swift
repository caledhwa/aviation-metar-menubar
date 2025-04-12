import XCTest
@testable import AviationMetarMenubar

class AviationMetarMenubarTests: XCTestCase {

    var metarService: MetarService!

    override func setUp() {
        super.setUp()
        metarService = MetarService()
    }

    override func tearDown() {
        metarService = nil
        super.tearDown()
    }

    func testFetchMetarData() {
        let expectation = self.expectation(description: "Fetch METAR data")
        
        metarService.fetchMetarData(for: ["KPDX", "KBLI"]) { result in
            switch result {
            case .success(let metars):
                XCTAssertFalse(metars.isEmpty, "METAR data should not be empty")
                XCTAssertEqual(metars.count, 2, "Should fetch METAR data for two airports")
            case .failure(let error):
                XCTFail("Failed to fetch METAR data: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testParseMetarResponse() {
        let sampleResponse = """
        KRNT VFR BKN 5500;
        KPDX VFR BKN 5500ft 10+SM|color="#00FF00" font="Frutiger Bold" size="16"
        --SCT 4200ft|color="#00FF00" font="Frutiger Bold" size="16"
        --BKN 5500ft|color="#00FF00" font="Frutiger Bold" size="16"
        --Visibility: 10+SM|color="#00FF00" font="Frutiger Bold" size="16"
        --Wind: 240° @ 3kts |color="#00FF00" font="Frutiger Bold" size="16"
        --Temp: 8.3°C / 2.2°C|color="#00FF00" font="Frutiger Bold" size="16"
        --Alt: 30.35 inHg|color="#00FF00" font="Frutiger Bold" size="16"
        --Time: 12.4.2025 15:00 (PDT)|color="#FFFFFF" font="Frutiger Bold" size="16"
        """
        
        let metar = metarService.parseMetarResponse(sampleResponse)
        XCTAssertNotNil(metar, "Parsed METAR should not be nil")
        XCTAssertEqual(metar?.airportCode, "KPDX", "Airport code should match")
    }
}