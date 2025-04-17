import XCTest
@testable import AviationMetarMenubar

final class AviationMetarMenubarTests: XCTestCase {
    func testAirportModelInitialization() {
        let airport = Airport(
            icaoId: "KSEA",
            name: "Seattle-Tacoma International Airport",
            state: "WA",
            country: "US",
            lat: 47.4489,
            lon: -122.3094,
            elev: 433,
            iataId: "SEA",
            faaId: "SEA",
            priority: nil
        )
        XCTAssertEqual(airport.icaoId, "KSEA")
        XCTAssertEqual(airport.name, "Seattle-Tacoma International Airport")
        XCTAssertEqual(airport.state, "WA")
        XCTAssertEqual(airport.country, "US")
        XCTAssertEqual(airport.lat, 47.4489)
        XCTAssertEqual(airport.lon, -122.3094)
        XCTAssertEqual(airport.elev, 433)
        XCTAssertEqual(airport.iataId, "SEA")
        XCTAssertEqual(airport.faaId, "SEA")
    }
    
    func testAirportDisplayName() {
        let airport = Airport(
            icaoId: "KBFI",
            name: "Boeing Field",
            state: nil,
            country: nil,
            lat: nil,
            lon: nil,
            elev: nil,
            iataId: nil,
            faaId: nil,
            priority: nil
        )
        XCTAssertEqual(airport.displayName, "KBFI - Boeing Field")
    }
    
    func testAirportManagerAddAndRemoveAirport() {
        let manager = AirportManager()
        manager.userAirports = [] // Ensure a clean state for testing
        let airport = Airport(
            icaoId: "KPDX",
            name: "Portland International Airport",
            state: "OR",
            country: "US",
            lat: 45.5887,
            lon: -122.5975,
            elev: 30,
            iataId: "PDX",
            faaId: "PDX",
            priority: nil
        )
        // Ensure airport is not already in userAirports
        XCTAssertFalse(manager.userAirports.contains(airport))
        manager.addAirport(airport)
        XCTAssertTrue(manager.userAirports.contains(airport))
        manager.removeAirport(airport)
        XCTAssertFalse(manager.userAirports.contains(airport))
    }

    func testAirportManagerPreventsDuplicateAirports() {
        let manager = AirportManager()
        let airport = Airport(
            icaoId: "KSEA",
            name: "Seattle-Tacoma International Airport",
            state: "WA",
            country: "US",
            lat: 47.4489,
            lon: -122.3094,
            elev: 433,
            iataId: "SEA",
            faaId: "SEA",
            priority: nil
        )
        manager.addAirport(airport)
        manager.addAirport(airport)
        let count = manager.userAirports.filter { $0.icaoId == "KSEA" }.count
        XCTAssertEqual(count, 1)
    }

    func testAirportManagerAvailableAirports() {
        let manager = AirportManager()
        // Simulate allAirports and userAirports
        let sea = Airport(icaoId: "KSEA", name: "Seattle", state: nil, country: nil, lat: nil, lon: nil, elev: nil, iataId: nil, faaId: nil, priority: nil)
        let bfi = Airport(icaoId: "KBFI", name: "Boeing Field", state: nil, country: nil, lat: nil, lon: nil, elev: nil, iataId: nil, faaId: nil, priority: nil)
        manager.allAirports = [sea, bfi]
        manager.userAirports = [sea]
        let available = manager.availableAirports
        XCTAssertTrue(available.contains(bfi))
        XCTAssertFalse(available.contains(sea))
    }

    func testFormatWind() {
        let service = MetarService()
        XCTAssertEqual(service.formatWind("240", windSpeed: 10, windGust: nil), "240° @ 10kts")
        XCTAssertEqual(service.formatWind("VRB", windSpeed: 5, windGust: 12), "Variable @ 5kts G12kts")
        XCTAssertEqual(service.formatWind(nil, windSpeed: nil, windGust: nil), "Calm")
        XCTAssertEqual(service.formatWind("180", windSpeed: 0, windGust: nil), "Calm")
    }

    func testFormatTemperature() {
        let service = MetarService()
        XCTAssertEqual(service.formatTemperature(20.0, dewpoint: 10.0), "20.0°C / 10.0°C")
        XCTAssertEqual(service.formatTemperature(nil, dewpoint: 5.0), "Unknown / 5.0°C")
        XCTAssertEqual(service.formatTemperature(15.0, dewpoint: nil), "15.0°C / Unknown")
        XCTAssertEqual(service.formatTemperature(nil, dewpoint: nil), "Unknown / Unknown")
    }

    func testFormatVisibility() {
        let service = MetarService()
        XCTAssertEqual(service.formatVisibility(.int(10)), "10SM")
        XCTAssertEqual(service.formatVisibility(.string("10+")), "10+SM")
        XCTAssertEqual(service.formatVisibility(nil), "Unknown")
    }

    // MARK: - Metar Model Tests
    func testMetarModelInitialization() {
        let metar = Metar(
            airportCode: "KSEA",
            airportName: "Seattle-Tacoma International Airport",
            metarType: "METAR",
            flightCategory: "VFR",
            weatherConditions: "Clear",
            visibility: "10SM",
            wind: "240° @ 5kts",
            temperature: "15.0°C / 10.0°C",
            altimeter: "30.00 inHg",
            observationTime: "04.17.2025 12:00 (PDT)",
            observationTimeZulu: "17Z19:00",
            additionalConditions: ["None"],
            allCloudLayers: ["SKC"]
        )
        XCTAssertEqual(metar.airportCode, "KSEA")
        XCTAssertEqual(metar.flightCategory, "VFR")
        XCTAssertEqual(metar.weatherConditions, "Clear")
        XCTAssertEqual(metar.visibility, "10SM")
        XCTAssertEqual(metar.wind, "240° @ 5kts")
        XCTAssertEqual(metar.temperature, "15.0°C / 10.0°C")
        XCTAssertEqual(metar.altimeter, "30.00 inHg")
        XCTAssertEqual(metar.observationTime, "04.17.2025 12:00 (PDT)")
        XCTAssertEqual(metar.observationTimeZulu, "17Z19:00")
        XCTAssertEqual(metar.additionalConditions, ["None"])
        XCTAssertEqual(metar.allCloudLayers, ["SKC"])
    }

    // MARK: - AirportManager Edge Case Tests
    func testAirportManagerRemoveAll() {
        let manager = AirportManager()
        manager.userAirports = [
            Airport(icaoId: "KSEA", name: "Seattle", state: nil, country: nil, lat: nil, lon: nil, elev: nil, iataId: nil, faaId: nil, priority: nil),
            Airport(icaoId: "KBFI", name: "Boeing Field", state: nil, country: nil, lat: nil, lon: nil, elev: nil, iataId: nil, faaId: nil, priority: nil)
        ]
        manager.removeAll()
        XCTAssertTrue(manager.userAirports.isEmpty)
    }

    // MARK: - MetarService Additional Logic Tests
    func testFormatAltimeter() {
        let service = MetarService()
        XCTAssertEqual(service.formatAltimeter(29.92), "29.92 inHg")
        XCTAssertEqual(service.formatAltimeter(1013.25), "29.92 inHg") // 1013.25 mb = 29.92 inHg
        XCTAssertEqual(service.formatAltimeter(nil), "Unknown")
    }

    func testDetermineFlightCategory() {
        let service = MetarService()
        // VFR: vis > 5, ceiling >= 3000
        XCTAssertEqual(service.determineFlightCategory(visibility: .int(10), cloudLayers: [MetarData.CloudData(cover: "SCT", base: 5000)]), "VFR")
        // MVFR: vis <= 5, ceiling < 3000
        XCTAssertEqual(service.determineFlightCategory(visibility: .int(5), cloudLayers: [MetarData.CloudData(cover: "BKN", base: 2000)]), "MVFR")
        // IFR: vis < 3, ceiling < 1000
        XCTAssertEqual(service.determineFlightCategory(visibility: .int(2), cloudLayers: [MetarData.CloudData(cover: "OVC", base: 800)]), "IFR")
        // LIFR: vis < 1, ceiling < 500
        XCTAssertEqual(service.determineFlightCategory(visibility: .int(0), cloudLayers: [MetarData.CloudData(cover: "OVC", base: 400)]), "LIFR")
    }

    // MARK: - SwiftUI View Instantiation Tests
    func testAirportManagementViewInstantiation() {
        let manager = AirportManager()
        _ = AirportManagementView(airportManager: manager)
    }

    // MARK: - MenuBarController Instantiation Test
    func testMenuBarControllerInstantiation() {
        _ = MenuBarController()
    }
    // MARK: - AppDelegate Instantiation Test
    func testAppDelegateInstantiation() {
        _ = AppDelegate()
    }
}
