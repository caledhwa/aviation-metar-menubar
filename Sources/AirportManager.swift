import Foundation
import CoreLocation
import AppKit  // Added to provide access to NSWorkspace

class AirportManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var allAirports: [Airport] = []
    @Published var userAirports: [Airport] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var currentLocation: CLLocation?
    @Published var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    private let apiUrl = "https://aviationweather.gov/api/data/airport"
    private let userDefaultsKey = "selectedAirportCodes"
    
    // Initialize with currently saved airports
    override init() {
        super.init()
        loadSavedAirports()
        
        // Setup location manager with delegate
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Don't need high precision
        
        // Check current authorization status
        locationAuthStatus = locationManager.authorizationStatus
        
        // Request location permission if not determined yet
        if locationAuthStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization() // macOS only has .requestAlwaysAuthorization()
        } else if locationAuthStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = locationAuthStatus
        locationAuthStatus = manager.authorizationStatus
        
        print("Location authorization changed from \(oldStatus) to \(locationAuthStatus)")
        
        // Take action based on new status
        switch locationAuthStatus {
        case .authorizedAlways:
            print("Location access authorized, starting updates")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied or restricted")
            // Don't automatically open settings here, let the user initiate that
        case .notDetermined:
            print("Location authorization still not determined")
        @unknown default:
            print("Unknown location authorization status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Only update if the location has meaningfully changed or is first update
        if currentLocation == nil || 
           (currentLocation!.distance(from: location) > 5000) { // 5km threshold
            
            currentLocation = location
            
            // Update airport distances
            updateAirportDistances()
            
            // If we already have airports loaded, re-sort them
            if !allAirports.isEmpty {
                sortAirportsByDistance()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        
        // Handle specific location errors
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                // This is a temporary error that might be resolved automatically
                print("Location currently unknown, waiting for update...")
                
            case .denied:
                // User denied access to location data - direct them to settings
                print("Location access denied by user")
                // Only prompt to open settings if we detect this error
                if locationAuthStatus == .denied || locationAuthStatus == .restricted {
                    // User has explicitly denied - we should guide them to settings
                    DispatchQueue.main.async { [weak self] in
                        self?.openLocationSettings()
                    }
                }
                
            case .network:
                // Network-related error
                print("Network error prevented location update")
                
            default:
                print("Other location error: \(clError.code.rawValue)")
            }
        }
    }
    
    // MARK: - Airport Management
    
    // Function to request location permissions manually if needed
    func requestLocationPermission() {
        print("Requesting location permission, current status: \(locationAuthStatus)")
        
        // First check if we're already authorized
        if locationAuthStatus == .authorizedAlways {
            // If already authorized, just start updating location
            locationManager.startUpdatingLocation()
            return
        }
        
        // Request authorization - this will display the system prompt if not determined
        locationManager.requestAlwaysAuthorization()
        
        // For macOS, we need to handle status specially
        switch locationAuthStatus {
        case .denied, .restricted:
            // If already denied, we need to direct user to System Settings
            print("Location access denied - opening settings")
            openLocationSettings()
            
        case .notDetermined:
            // For notDetermined status, we need a more robust approach
            print("Location permission not determined - requesting and setting up a delayed start")
            
            // Instead of immediately trying to get location,
            // set a delay to give the system time to process the permission request
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                // Check if permission was granted
                if self.locationAuthStatus == .authorizedAlways {
                    print("Location permission now granted, starting updates")
                    self.locationManager.startUpdatingLocation()
                } else if self.locationAuthStatus == .denied || self.locationAuthStatus == .restricted {
                    // If denied after the delay, open settings
                    print("Location permission was denied, opening settings")
                    self.openLocationSettings()
                } else {
                    // Still not determined or some other status, try one more time
                    print("Location permission still not determined, trying again with a basic approach")
                    // This sometimes triggers the permission prompt when other methods fail
                    self.locationManager.requestLocation()
                }
            }
            
        default:
            break
        }
    }
    
    // Helper function to open Location Services settings
    private func openLocationSettings() {
        // For macOS Sequoia (15.x) and newer
        if #available(macOS 15, *) {
            // Try latest macOS Sequoia URL formats first
            let sequoiaURLs = [
                // Primary format for Sequoia
                URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.Privacy_Location"),
                // Alternative formats that might work on Sequoia
                URL(string: "x-apple.systempreferences:com.apple.settings.Privacy"),
                URL(string: "x-apple.systempreferences:com.apple.settings.Privacy.LocationServices")
            ]
            
            for url in sequoiaURLs {
                if let url = url, NSWorkspace.shared.open(url) {
                    print("Successfully opened settings with URL: \(url)")
                    return
                }
            }
        } 
        // For macOS Ventura and Sonoma (13.x-14.x)
        else if #available(macOS 13, *) {
            let venturaURLs = [
                URL(string: "x-apple.systempreferences:com.apple.settings.Privacy.locationservices"),
                URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Location"),
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
            ]
            
            for url in venturaURLs {
                if let url = url, NSWorkspace.shared.open(url) {
                    return
                }
            }
        } 
        // For older macOS versions (Monterey and earlier)
        else {
            let legacyURLs = [
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"),
                URL(string: "x-apple.systempreferences:com.apple.preference.security")
            ]
            
            for url in legacyURLs {
                if let url = url, NSWorkspace.shared.open(url) {
                    return
                }
            }
        }
        
        // Final fallback method - open System Settings directly
        if #available(macOS 13, *) {
            // For Ventura and newer, System Settings has a different bundle ID
            if let settingsURL = URL(string: "x-apple.systempreferences:") {
                NSWorkspace.shared.open(settingsURL)
            }
        } else {
            // For older macOS versions
            if let prefApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
                NSWorkspace.shared.open(prefApp)
            }
        }
    }
    
    // Load saved airport codes from UserDefaults
    private func loadSavedAirports() {
        if let airportCodes = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            userAirports = airportCodes.compactMap { code in
                Airport(icaoId: code, name: code, state: nil, country: nil, lat: nil, lon: nil, elev: nil, iataId: nil, faaId: nil, priority: nil)
            }
        } else {
            // Default airports if none are saved
            userAirports = ["KRNT", "KBFI", "KSEA", "KOLM", "KPWT", "KPLU", "KTIW", "KSHN", "KAWO", "KBVS", "KHQM", "KPAE", "KSPB", "KAST", "KCLS", "KKLS", "KPDX", "KHIO"].map { code in
                Airport(icaoId: code, name: code, state: nil, country: nil, lat: nil, lon: nil, elev: nil, iataId: nil, faaId: nil, priority: nil)
            }
        }
    }
    
    // Save selected airport codes to UserDefaults
    func saveAirports() {
        let codes = userAirports.map { $0.icaoId }
        UserDefaults.standard.set(codes, forKey: userDefaultsKey)
    }
    
    // Update distances for all airports
    private func updateAirportDistances() {
        guard let location = currentLocation else { return }
        
        for i in 0..<allAirports.count {
            allAirports[i].calculateDistance(from: location)
        }
        
        for i in 0..<userAirports.count {
            userAirports[i].calculateDistance(from: location)
        }
    }
    
    // Sort airports by distance
    private func sortAirportsByDistance() {
        // Sort allAirports by distance
        allAirports.sort { 
            ($0.distanceFromCurrentLocation ?? Double.infinity) < 
            ($1.distanceFromCurrentLocation ?? Double.infinity) 
        }
        
        // Note: We don't sort userAirports as users may want a specific order
    }
    
    // Fetch airports from API for the specified states
    func fetchAirports(forStates states: [String] = ["@WA", "@OR", "@ID"]) {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        var urlComponents = URLComponents(string: apiUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "ids", value: states.joined(separator: ",")),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = urlComponents?.url else {
            isLoading = false
            error = "Invalid URL"
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    self.error = "Server error"
                    return
                }
                
                guard let data = data else {
                    self.error = "No data received"
                    return
                }
                
                do {
                    var airports = try JSONDecoder().decode([Airport].self, from: data)
                    
                    // Calculate distances if user location is available
                    if let location = self.currentLocation {
                        for i in 0..<airports.count {
                            airports[i].calculateDistance(from: location)
                        }
                        
                        // Sort by distance
                        airports.sort { 
                            ($0.distanceFromCurrentLocation ?? Double.infinity) < 
                            ($1.distanceFromCurrentLocation ?? Double.infinity) 
                        }
                    }
                    
                    self.allAirports = airports
                    
                    // Update user airports with full info if possible
                    self.updateUserAirportsWithFullInfo()
                } catch {
                    self.error = "Failed to parse airport data: \(error.localizedDescription)"
                    print("Parsing error: \(error)")
                    
                    // Print data for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Received JSON: \(jsonString)")
                    }
                }
            }
        }
        
        task.resume()
    }
    
    // Update user airports with full information from allAirports
    private func updateUserAirportsWithFullInfo() {
        let userAirportCodes = userAirports.map { $0.icaoId }
        
        let updatedAirports = userAirportCodes.compactMap { code in
            allAirports.first { $0.icaoId == code } ?? 
            userAirports.first { $0.icaoId == code }
        }
        
        // Only update if we have airports - prevents wiping out the list on error
        if !updatedAirports.isEmpty {
            userAirports = updatedAirports
        }
    }
    
    // Add an airport to user's selection
    func addAirport(_ airport: Airport) {
        guard !userAirports.contains(where: { $0.icaoId == airport.icaoId }) else { return }
        userAirports.append(airport)
    }
    
    // Remove an airport from user's selection
    func removeAirport(_ airport: Airport) {
        userAirports.removeAll { $0.icaoId == airport.icaoId }
    }
    
    // Get available airports that are not already selected
    var availableAirports: [Airport] {
        let userAirportCodes = Set(userAirports.map { $0.icaoId })
        return allAirports.filter { !userAirportCodes.contains($0.icaoId) }
    }
    
    // Sort user's airports by distance
    func sortUserAirportsByDistance() {
        guard currentLocation != nil else { return }
        
        userAirports.sort { 
            ($0.distanceFromCurrentLocation ?? Double.infinity) < 
            ($1.distanceFromCurrentLocation ?? Double.infinity) 
        }
    }
}