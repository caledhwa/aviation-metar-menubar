import Foundation
import AppKit

struct Metar {
    let airportCode: String
    let airportName: String
    let metarType: String
    let flightCategory: String
    let weatherConditions: String
    let visibility: String
    let wind: String
    let temperature: String
    let altimeter: String
    let observationTime: String
    let observationTimeZulu: String
    let additionalConditions: [String]
    let allCloudLayers: [String]
    
    // Computed property to get color for flight category
    var categoryColor: NSColor {
        switch flightCategory {
        case "VFR":
            return NSColor(red: 0, green: 1, blue: 0, alpha: 1) // Green
        case "MVFR":
            return NSColor(red: 0, green: 0.8, blue: 1, alpha: 1) // Light Blue
        case "IFR":
            return NSColor(red: 1, green: 0, blue: 0, alpha: 1) // Red
        case "LIFR":
            return NSColor(red: 0.6, green: 0, blue: 0.8, alpha: 1) // Purple
        default:
            return NSColor.white
        }
    }
    
    init(airportCode: String, airportName: String = "", metarType: String = "METAR", flightCategory: String, weatherConditions: String, visibility: String, wind: String, temperature: String, altimeter: String, observationTime: String, observationTimeZulu: String, additionalConditions: [String] = [], allCloudLayers: [String] = []) {
        self.airportCode = airportCode
        self.airportName = airportName
        self.metarType = metarType
        self.flightCategory = flightCategory
        self.weatherConditions = weatherConditions
        self.visibility = visibility
        self.wind = wind
        self.temperature = temperature
        self.altimeter = altimeter
        self.observationTime = observationTime
        self.observationTimeZulu = observationTimeZulu
        self.additionalConditions = additionalConditions
        self.allCloudLayers = allCloudLayers
    }
}