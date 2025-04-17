import Foundation
import CoreLocation

struct Airport: Identifiable, Codable, Equatable, Hashable {
    var id: String { icaoId }
    let icaoId: String
    let name: String
    let state: String?
    let country: String?
    let lat: Double?
    let lon: Double?
    let elev: Int?
    
    // Additional fields that could be useful
    let iataId: String?
    let faaId: String?
    let priority: String?
    
    // Computed properties
    var displayName: String {
        return "\(icaoId) - \(name.trimmingCharacters(in: .whitespaces))"
    }
    
    var location: CLLocation? {
        if let lat = lat, let lon = lon {
            return CLLocation(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    var distanceFromCurrentLocation: Double?
    
    // Static methods
    static func == (lhs: Airport, rhs: Airport) -> Bool {
        return lhs.icaoId == rhs.icaoId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(icaoId)
    }
}

// Extension for distance calculation
extension Airport {
    mutating func calculateDistance(from userLocation: CLLocation) {
        if let location = self.location {
            self.distanceFromCurrentLocation = userLocation.distance(from: location) / 1609.34 // Convert to miles
        }
    }
    
    var formattedDistance: String {
        if let distance = distanceFromCurrentLocation {
            return String(format: "%.1f mi", distance)
        }
        return "Unknown"
    }
}