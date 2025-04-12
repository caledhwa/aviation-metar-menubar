import SwiftUI
import CoreLocation

struct AirportManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var airportManager: AirportManager
    
    @State private var selectedAvailableAirport: Airport?
    @State private var selectedUserAirport: Airport?
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .custom
    
    enum SortOption {
        case custom
        case distance
        case alphabetical
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Your Airports")
                .font(.headline)
                .padding(.top)
            
            // Location status banner - more prominent when not authorized
            if airportManager.locationAuthStatus == .denied || 
               airportManager.locationAuthStatus == .restricted {
                HStack {
                    Image(systemName: "location.slash.fill")
                        .foregroundColor(.red)
                    
                    Text("Location access is required for distance-based sorting")
                        .font(.subheadline)
                    
                    Button("Open Settings") {
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
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            HStack {
                // Left column - Available airports
                VStack {
                    HStack {
                        TextField("Search airports", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    List {
                        if airportManager.isLoading {
                            ProgressView("Loading airports...")
                        } else if let error = airportManager.error {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                        } else {
                            ForEach(filteredAvailableAirports) { airport in
                                AirportRow(airport: airport)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedAvailableAirport = airport
                                    }
                                    .background(selectedAvailableAirport?.id == airport.id ? Color.accentColor.opacity(0.2) : Color.clear)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .frame(minWidth: 300)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Middle - Add/Remove buttons
                VStack {
                    Button(action: {
                        if let airport = selectedAvailableAirport {
                            airportManager.addAirport(airport)
                            selectedAvailableAirport = nil
                        }
                    }) {
                        Image(systemName: "arrow.right")
                            .frame(width: 30, height: 30)
                    }
                    .disabled(selectedAvailableAirport == nil)
                    .padding()
                    
                    Button(action: {
                        if let airport = selectedUserAirport {
                            airportManager.removeAirport(airport)
                            selectedUserAirport = nil
                        }
                    }) {
                        Image(systemName: "arrow.left")
                            .frame(width: 30, height: 30)
                    }
                    .disabled(selectedUserAirport == nil)
                    .padding()
                }
                
                // Right column - Selected airports
                VStack {
                    VStack(spacing: 8) {
                        Text("Your Selected Airports")
                            .font(.headline)
                        
                        // Sorting options
                        HStack {
                            Text("Sort by:")
                                .font(.caption)
                            
                            Picker("Sort", selection: $sortOption) {
                                Text("Custom").tag(SortOption.custom)
                                Text("Distance").tag(SortOption.distance)
                                Text("Name").tag(SortOption.alphabetical)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            // Fixed onChange modifier to be compatible with current Swift version
                            .onChange(of: sortOption, perform: { _ in
                                sortUserAirports()
                            })
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    
                    List {
                        ForEach(airportManager.userAirports) { airport in
                            AirportRow(airport: airport)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedUserAirport = airport
                                }
                                .background(selectedUserAirport?.id == airport.id ? Color.accentColor.opacity(0.2) : Color.clear)
                        }
                        .onMove(perform: sortOption == .custom ? moveUserAirport : nil)
                    }
                    .listStyle(PlainListStyle())
                    .frame(minWidth: 300)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    
                    if sortOption == .custom {
                        Text("Drag to reorder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                }
            }
            .padding()
            
            // Location status indicator
            HStack {
                // Define status properties without using let statements in the view body
                Image(systemName: getStatusIcon())
                    .foregroundColor(getStatusColor())
                
                Text(getStatusText())
                    .font(.caption)
                
                if airportManager.locationAuthStatus == .notDetermined {
                    Button("Request Permission") {
                        airportManager.requestLocationPermission()
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(.leading, 8)
                }
            }
            .padding(.bottom, 8)
            
            // Bottom action buttons
            HStack {
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    airportManager.saveAirports()
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 700, idealWidth: 700, maxWidth: .infinity, 
               minHeight: 500, idealHeight: 500, maxHeight: .infinity)
        .onAppear {
            airportManager.fetchAirports()
        }
    }
    
    // Filter available airports based on search text and sort by distance
    private var filteredAvailableAirports: [Airport] {
        // Start with all available airports
        var airports = airportManager.availableAirports
        
        // Filter by search text if needed
        if (!searchText.isEmpty) {
            airports = airports.filter {
                $0.icaoId.lowercased().contains(searchText.lowercased()) ||
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Sort by distance if location is available (should already be sorted in manager, but ensure it here)
        if airportManager.currentLocation != nil {
            airports.sort {
                ($0.distanceFromCurrentLocation ?? Double.infinity) <
                ($1.distanceFromCurrentLocation ?? Double.infinity)
            }
        }
        
        return airports
    }
    
    // Move user airport in the list (for reordering)
    private func moveUserAirport(from source: IndexSet, to destination: Int) {
        airportManager.userAirports.move(fromOffsets: source, toOffset: destination)
    }
    
    // Sort user airports based on selected option
    private func sortUserAirports() {
        switch sortOption {
        case .distance:
            airportManager.sortUserAirportsByDistance()
        case .alphabetical:
            airportManager.userAirports.sort { $0.icaoId < $1.icaoId }
        case .custom:
            // Do nothing - keep current order
            break
        }
    }
    
    // Close the window
    private func closeWindow() {
        // For macOS we need to stop modal session and close window
        if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            NSApplication.shared.stopModal()
            window.close()
        }
    }
    
    // Get status icon based on location authorization status
    private func getStatusIcon() -> String {
        switch airportManager.locationAuthStatus {
        case .authorizedAlways:
            return "location.fill"
        case .notDetermined:
            return "location.circle"
        case .denied, .restricted:
            return "location.slash.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    // Get status color based on location authorization status
    private func getStatusColor() -> Color {
        switch airportManager.locationAuthStatus {
        case .authorizedAlways:
            return .green
        case .notDetermined:
            return .yellow
        case .denied, .restricted:
            return .red
        @unknown default:
            return .gray
        }
    }
    
    // Get status text based on location authorization status
    private func getStatusText() -> String {
        switch airportManager.locationAuthStatus {
        case .authorizedAlways:
            return "Using your location for distance calculation"
        case .notDetermined:
            return "Location permission not yet determined"
        case .denied, .restricted:
            return "Location access denied - can't calculate distances"
        @unknown default:
            return "Unknown location authorization status"
        }
    }
}

// Row view for displaying an airport in the list
struct AirportRow: View {
    let airport: Airport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(airport.icaoId)
                    .font(.headline)
                
                if let state = airport.state {
                    Text("(\(state))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let distance = airport.distanceFromCurrentLocation {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(String(format: "%.1f mi", distance))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            
            Text(airport.name.trimmingCharacters(in: .whitespaces))
                .font(.subheadline)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                if let elev = airport.elev {
                    Text("Elev: \(elev) ft")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let lat = airport.lat, let lon = airport.lon {
                    Text("Lat: \(String(format: "%.4f", lat)), Lon: \(String(format: "%.4f", lon))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}