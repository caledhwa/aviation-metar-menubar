import SwiftUI
import CoreLocation
import UniformTypeIdentifiers
import AppKit

// NSViewRepresentable wrapper for NSSearchField
struct MacSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholder
        searchField.delegate = context.coordinator
        return searchField
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        // Only update if needed to prevent cursor jumping
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: MacSearchField
        
        init(_ parent: MacSearchField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let searchField = obj.object as? NSSearchField {
                parent.text = searchField.stringValue
            }
        }
    }
}

struct AirportManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var airportManager: AirportManager
    
    @State private var selectedAvailableAirport: Airport?
    @State private var selectedUserAirport: Airport?
    @State private var searchText: String = ""
    @State private var draggedAirport: Airport?
    
    // Add focus state for the search field
    @FocusState private var searchFieldIsFocused: Bool
    
    // New sort state variables
    @State private var leftSortMode: SortMode = .nameAsc
    @State private var rightSortMode: SortMode = .nameAsc
    
    // Sort modes for both boxes
    enum SortMode {
        case nameAsc, nameDesc, distanceNear, distanceFar
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
            
            HStack(alignment: .top) {
                // Left column - Available airports
                VStack {
                    HStack {
                        Text("Choose Airports")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Sort buttons for left box
                        Button(action: { toggleLeftNameSort() }) {
                            HStack(spacing: 2) {
                                Text("Name")
                                    .font(.caption)
                                Image(systemName: leftSortMode == .nameAsc ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(leftSortMode != .nameAsc && leftSortMode != .nameDesc)
                        
                        Button(action: { toggleLeftDistanceSort() }) {
                            HStack(spacing: 2) {
                                Text("Distance")
                                    .font(.caption)
                                Image(systemName: leftSortMode == .distanceNear ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(leftSortMode != .distanceNear && leftSortMode != .distanceFar)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        MacSearchField(text: $searchText, placeholder: "Search airports")
                            .focused($searchFieldIsFocused)
                        
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
                    .frame(height: 300)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                }
                .frame(minWidth: 300)
                
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
                    HStack {
                        Text("Selected Airports")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Sort buttons for right box
                        Button(action: { toggleRightNameSort() }) {
                            HStack(spacing: 2) {
                                Text("Name")
                                    .font(.caption)
                                Image(systemName: rightSortMode == .nameAsc ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(rightSortMode != .nameAsc && rightSortMode != .nameDesc)
                        
                        Button(action: { toggleRightDistanceSort() }) {
                            HStack(spacing: 2) {
                                Text("Distance")
                                    .font(.caption)
                                Image(systemName: rightSortMode == .distanceNear ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(rightSortMode != .distanceNear && rightSortMode != .distanceFar)
                    }
                    .padding(.horizontal)
                    
                    Text("Drag to reorder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    List {
                        ForEach(airportManager.userAirports) { airport in
                            AirportRow(airport: airport)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedUserAirport = airport
                                }
                                .background(selectedUserAirport?.id == airport.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                .onDrag {
                                    self.draggedAirport = airport
                                    return NSItemProvider(object: airport.id as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: AirportDropDelegate(
                                    airport: airport, 
                                    airportList: airportManager.userAirports,
                                    airportManager: airportManager, 
                                    draggedAirport: $draggedAirport))
                        }
                    }
                    .listStyle(PlainListStyle())
                    .frame(height: 300)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    
                    // Clear All button 
                    HStack {
                        Button("Remove Selected") {
                            if let selected = selectedUserAirport {
                                airportManager.removeAirport(selected)
                                selectedUserAirport = nil
                            }
                        }
                        .disabled(selectedUserAirport == nil)
                        
                        Spacer()
                        
                        Button("Clear All") {
                            airportManager.removeAll()
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)
                }
                .frame(minWidth: 300)
            }
            .padding()
            
            // Location status indicator
            HStack {
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
                .buttonStyle(.bordered)
                .frame(width: 100)
                
                Spacer()
                
                Button("Done") {
                    airportManager.saveAirports()
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .frame(width: 100)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 700, idealWidth: 700, maxWidth: .infinity, 
               minHeight: 500, idealHeight: 500, maxHeight: .infinity)
        .onAppear {
            airportManager.fetchAirports()
            // Set focus to the search field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                searchFieldIsFocused = true
            }
        }
    }
    
    // Computed property for sorted user airports based on current sort mode
    private var sortedUserAirports: [Airport] {
        switch rightSortMode {
        case .nameAsc:
            return airportManager.userAirports.sorted { $0.icaoId < $1.icaoId }
        case .nameDesc:
            return airportManager.userAirports.sorted { $0.icaoId > $1.icaoId }
        case .distanceNear:
            return airportManager.userAirports.sorted { 
                ($0.distanceFromCurrentLocation ?? Double.infinity) < 
                ($1.distanceFromCurrentLocation ?? Double.infinity) 
            }
        case .distanceFar:
            return airportManager.userAirports.sorted { 
                ($0.distanceFromCurrentLocation ?? 0) > 
                ($1.distanceFromCurrentLocation ?? 0) 
            }
        }
    }
    
    // Filter available airports based on search text and sort by current mode
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
        
        // Sort based on current sort mode
        switch leftSortMode {
        case .nameAsc:
            airports.sort { $0.icaoId < $1.icaoId }
        case .nameDesc:
            airports.sort { $0.icaoId > $1.icaoId }
        case .distanceNear:
            airports.sort { 
                ($0.distanceFromCurrentLocation ?? Double.infinity) < 
                ($1.distanceFromCurrentLocation ?? Double.infinity) 
            }
        case .distanceFar:
            airports.sort { 
                ($0.distanceFromCurrentLocation ?? 0) > 
                ($1.distanceFromCurrentLocation ?? 0) 
            }
        }
        
        return airports
    }
    
    // Toggle sort functions for left box
    private func toggleLeftNameSort() {
        leftSortMode = leftSortMode == .nameAsc ? .nameDesc : .nameAsc
    }
    
    private func toggleLeftDistanceSort() {
        leftSortMode = leftSortMode == .distanceNear ? .distanceFar : .distanceNear
    }
    
    // Toggle sort functions for right box
    private func toggleRightNameSort() {
        rightSortMode = rightSortMode == .nameAsc ? .nameDesc : .nameAsc
        
        // Apply sorting directly to the airports array
        if rightSortMode == .nameAsc {
            airportManager.userAirports.sort { $0.icaoId < $1.icaoId }
        } else {
            airportManager.userAirports.sort { $0.icaoId > $1.icaoId }
        }
    }
    
    private func toggleRightDistanceSort() {
        rightSortMode = rightSortMode == .distanceNear ? .distanceFar : .distanceNear
        
        // Apply sorting directly to the airports array
        if rightSortMode == .distanceNear {
            airportManager.userAirports.sort { 
                ($0.distanceFromCurrentLocation ?? Double.infinity) < 
                ($1.distanceFromCurrentLocation ?? Double.infinity) 
            }
        } else {
            airportManager.userAirports.sort { 
                ($0.distanceFromCurrentLocation ?? Double.infinity) > 
                ($1.distanceFromCurrentLocation ?? Double.infinity) 
            }
        }
    }
    
    // Show confirmation before clearing all airports
    private func confirmClearAll() {
        let alert = NSAlert()
        alert.messageText = "Clear All Airports?"
        alert.informativeText = "Are you sure you want to remove all selected airports? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            airportManager.removeAll()
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

// Drop delegate to handle airport reordering
struct AirportDropDelegate: DropDelegate {
    let airport: Airport
    let airportList: [Airport]
    let airportManager: AirportManager
    @Binding var draggedAirport: Airport?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedAirport = self.draggedAirport else {
            return false
        }
        
        // Get the indices
        guard let fromIndex = airportManager.userAirports.firstIndex(where: { $0.id == draggedAirport.id }),
              let toIndex = airportManager.userAirports.firstIndex(where: { $0.id == airport.id }) else {
            return false
        }
        
        // Perform the move if indices are different
        if fromIndex != toIndex {
            withAnimation {
                let element = airportManager.userAirports.remove(at: fromIndex)
                airportManager.userAirports.insert(element, at: toIndex > fromIndex ? toIndex - 1 : toIndex)
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedAirport = self.draggedAirport,
              draggedAirport.id != airport.id,
              let fromIndex = airportManager.userAirports.firstIndex(where: { $0.id == draggedAirport.id }),
              let toIndex = airportManager.userAirports.firstIndex(where: { $0.id == airport.id }) else {
            return
        }
        
        // Move the item within the array
        if airportManager.userAirports[fromIndex].id != airportManager.userAirports[toIndex].id {
            withAnimation {
                let element = airportManager.userAirports.remove(at: fromIndex)
                airportManager.userAirports.insert(element, at: toIndex > fromIndex ? toIndex - 1 : toIndex)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
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
