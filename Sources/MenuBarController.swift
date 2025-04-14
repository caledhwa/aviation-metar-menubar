import Cocoa
import SwiftUI

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var metarService: MetarService!
    private var airportManager: AirportManager!
    private var refreshTimer: Timer?

    override init() {
        super.init()
        setupMenuBar()
        airportManager = AirportManager()
        metarService = MetarService(airportManager: airportManager)
        
        // Check if there are airports before attempting to fetch data
        if airportManager.userAirports.isEmpty {
            // Update the status bar to show "No Airports" instead of "Loading..."
            if let button = statusItem.button {
                button.title = "No Airports"
            }
            // Still build the menu with Manage Airports and Quit options
            showMenu()
        } else {
            // Only fetch METAR data if we have airports
            fetchMetarData()
        }
        
        startRefreshTimer()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Loading..."
            // Remove the action - we'll use the menu property instead
        }
        
        // Create the initial empty menu
        statusItem.menu = NSMenu()
    }

    @objc private func showMenu() {
        let menu = NSMenu()
        
        // Set the font for the entire menu
        menu.font = NSFont(name: "Frutiger Bold", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .bold)
        
        // Check if there's an error to display
        if metarService.airports.isEmpty, let errorMessage = metarService.lastError {
            // Create an error menu item
            let errorItem = NSMenuItem(title: "Error Details", action: nil, keyEquivalent: "")
            let errorMenu = NSMenu()
            
            // Add the error message to the submenu
            let messageItem = NSMenuItem(title: errorMessage, action: nil, keyEquivalent: "")
            let errorAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.red,
                .font: NSFont(name: "Frutiger Bold", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .bold)
            ]
            messageItem.attributedTitle = NSAttributedString(string: errorMessage, attributes: errorAttributes)
            errorMenu.addItem(messageItem)
            
            errorItem.submenu = errorMenu
            menu.addItem(errorItem)
        } else {
            // Get the order of airports from the airport manager
            let orderedAirportCodes = airportManager.userAirports.map { $0.icaoId }
            
            // Create a dictionary for fast lookup of Metar objects by airport code
            var metarByCode: [String: Metar] = [:]
            for metar in metarService.airports {
                metarByCode[metar.airportCode] = metar
            }
            
            // Display airports in the same order as in the airport manager
            for code in orderedAirportCodes {
                if let airport = metarByCode[code] {
                    // Format the primary menu item title with condensed format
                    let primaryTitle = formatCondensedMenuTitle(airport: airport)
                    let airportMenuItem = NSMenuItem(title: primaryTitle, action: nil, keyEquivalent: "")
                    
                    // Set color and font attributes for the main menu item
                    let airportAttributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: airport.categoryColor,
                        .font: NSFont(name: "Frutiger Bold", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .bold)
                    ]
                    airportMenuItem.attributedTitle = NSAttributedString(string: primaryTitle, attributes: airportAttributes)
                    
                    let subMenu = NSMenu()
                    // Set font for submenu items
                    subMenu.font = NSFont(name: "Frutiger Bold", size: 14) ?? NSFont.systemFont(ofSize: 14, weight: .bold)
                    
                    // Add airport name as the first item in submenu if available
                    if !airport.airportName.isEmpty {
                        let airportNameItem = NSMenuItem(title: airport.airportName, action: nil, keyEquivalent: "")
                        let nameAttributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: NSColor.white,
                            .font: NSFont(name: "Frutiger Bold", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .bold)
                        ]
                        airportNameItem.attributedTitle = NSAttributedString(string: airport.airportName, attributes: nameAttributes)
                        subMenu.addItem(airportNameItem)
                        subMenu.addItem(NSMenuItem.separator())
                    }
                    
                    // Add all cloud layers to the submenu
                    if !airport.allCloudLayers.isEmpty && airport.allCloudLayers[0] != "SKC" {
                        let cloudsTitle = NSMenuItem(title: "Cloud Layers:", action: nil, keyEquivalent: "")
                        let cloudsTitleAttributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: NSColor.white,
                            .font: NSFont(name: "Frutiger Bold", size: 14) ?? NSFont.systemFont(ofSize: 14, weight: .bold)
                        ]
                        cloudsTitle.attributedTitle = NSAttributedString(string: "Cloud Layers:", attributes: cloudsTitleAttributes)
                        subMenu.addItem(cloudsTitle)
                        
                        // Add each cloud layer
                        for layer in airport.allCloudLayers {
                            addColoredMenuItem(to: subMenu, title: "  \(layer)", color: airport.categoryColor)
                        }
                    } else {
                        addColoredMenuItem(to: subMenu, title: "SKC (Clear Skies)", color: airport.categoryColor)
                    }
                    
                    // Add additional conditions
                    if !airport.additionalConditions.isEmpty {
                        let conditionsTitle = NSMenuItem(title: "Weather Conditions:", action: nil, keyEquivalent: "")
                        let conditionsTitleAttributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: NSColor.white,
                            .font: NSFont(name: "Frutiger Bold", size: 14) ?? NSFont.systemFont(ofSize: 14, weight: .bold)
                        ]
                        conditionsTitle.attributedTitle = NSAttributedString(string: "Weather Conditions:", attributes: conditionsTitleAttributes)
                        subMenu.addItem(conditionsTitle)
                        
                        for condition in airport.additionalConditions {
                            addColoredMenuItem(to: subMenu, title: "  \(condition)", color: airport.categoryColor)
                        }
                    }
                    
                    subMenu.addItem(NSMenuItem.separator())
                    
                    // Add visibility
                    addColoredMenuItem(to: subMenu, title: "Visibility: \(airport.visibility)", color: airport.categoryColor)
                    
                    // Add wind
                    addColoredMenuItem(to: subMenu, title: "Wind: \(airport.wind)", color: airport.categoryColor)
                    
                    // Add temperature
                    addColoredMenuItem(to: subMenu, title: "Temp: \(airport.temperature)", color: airport.categoryColor)
                    
                    // Add altimeter
                    addColoredMenuItem(to: subMenu, title: "Alt: \(airport.altimeter)", color: airport.categoryColor)
                    
                    // Add both local and Zulu observation times
                    let localTimeItem = NSMenuItem(title: "Time (Local): \(airport.observationTime)", action: nil, keyEquivalent: "")
                    let localTimeAttributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor.white,
                        .font: NSFont(name: "Frutiger Bold", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .bold)
                    ]
                    localTimeItem.attributedTitle = NSAttributedString(string: "Time (Local): \(airport.observationTime)", attributes: localTimeAttributes)
                    subMenu.addItem(localTimeItem)
                    
                    // Add Zulu time with a purple color to distinguish it
                    let zuluTimeItem = NSMenuItem(title: "Time (Zulu): \(airport.observationTimeZulu)", action: nil, keyEquivalent: "")
                    let zuluTimeAttributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor(red: 0.7, green: 0.7, blue: 1.0, alpha: 1.0), // Light purple for Zulu time
                        .font: NSFont(name: "Frutiger Bold", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .bold)
                    ]
                    zuluTimeItem.attributedTitle = NSAttributedString(string: "Time (Zulu): \(airport.observationTimeZulu)", attributes: zuluTimeAttributes)
                    subMenu.addItem(zuluTimeItem)
                    
                    airportMenuItem.submenu = subMenu
                    menu.addItem(airportMenuItem)
                }
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Manage Airports menu item
        let manageAirportsItem = NSMenuItem(title: "Manage Airports...", action: #selector(showAirportManager), keyEquivalent: "M")
        manageAirportsItem.target = self
        menu.addItem(manageAirportsItem)
        
        // Add Refresh Now menu item with proper action
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshData), keyEquivalent: "R")
        refreshItem.target = self // Make sure the target is set for the action to work
        
        // Disable Refresh option if there are no airports
        if airportManager.userAirports.isEmpty {
            refreshItem.isEnabled = false
        }
        
        menu.addItem(refreshItem)
        
        // Add Quit menu item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "Q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }

    // Helper method to add colored menu items
    private func addColoredMenuItem(to menu: NSMenu, title: String, color: NSColor) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont(name: "Frutiger Bold", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .bold)
        ]
        item.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        menu.addItem(item)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func refreshData() {
        // Update status bar to show refreshing
        if let button = statusItem.button {
            button.title = "Refreshing..."
        }
        
        metarService.fetchMetarData { [weak self] success in
            guard let self = self else { return }
            
            if success {
                DispatchQueue.main.async {
                    self.updateMenu()
                    
                    // Rebuild the menu
                    self.showMenu()
                }
            } else {
                DispatchQueue.main.async {
                    if let button = self.statusItem.button {
                        button.title = "Refresh Failed"
                    }
                }
            }
        }
    }

    private func fetchMetarData() {
        metarService.fetchMetarData { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    self?.updateMenu()
                    // Build the menu after updating the title
                    self?.showMenu()
                }
            }
        }
    }

    private func updateMenu() {
        if let button = statusItem.button {
            if let firstAirport = metarService.airports.first {
                // Format the menu bar title with condensed information
                let titleText = formatCondensedMenuTitle(airport: firstAirport)
                
                // Create an attributed string with the flight category color
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: firstAirport.categoryColor,
                    .font: NSFont(name: "Frutiger Bold", size: 18) ?? NSFont.systemFont(ofSize: 18, weight: .bold)
                ]
                
                let attributedTitle = NSAttributedString(string: titleText, attributes: attributes)
                button.attributedTitle = attributedTitle
            } else if metarService.lastError != nil {
                // Show "Fetch Error" in the menu bar when there's an error
                button.title = "Fetch Error"
                button.contentTintColor = NSColor.red
            } else if airportManager.userAirports.isEmpty {
                // Show "No Airports" when the airport list is empty
                button.title = "No Airports"
                button.contentTintColor = NSColor.white
            } else {
                button.title = "No METAR Data"
                button.contentTintColor = NSColor.white
            }
        }
    }

    // Helper method to determine if cloud layer should be shown in the title
    private func shouldShowCloudLayer(_ cloudCondition: String) -> Bool {
        return cloudCondition.contains("BKN") || cloudCondition.contains("OVC") || cloudCondition.contains("OVX")
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(timeInterval: 600, target: self, selector: #selector(refreshData), userInfo: nil, repeats: true)
    }

    private func formatCondensedMenuTitle(airport: Metar) -> String {
        // Include airport code always
        var title = airport.airportCode
        
        // Add SPECI if it's a special report (not regular METAR)
        if airport.metarType == "SPECI" {
            title += " SPECI"
        }
        
        // Add flight category
        title += " \(airport.flightCategory)"
        
        // Add cloud layers only if BKN, OVC, or OVX
        if shouldShowCloudLayer(airport.weatherConditions) {
            title += " \(airport.weatherConditions)"
        }
        
        // Add abbreviated wind information
        title += " \(formatAbbreviatedWind(airport.wind))"
        
        // Add visibility only if it's less than or equal to 9SM
        let shouldShowVisibility = !shouldOmitVisibility(airport.visibility)
        if shouldShowVisibility {
            title += " \(airport.visibility)"
        }
        
        return title
    }
    
    // Helper method to determine if visibility should be omitted (greater than 9SM)
    private func shouldOmitVisibility(_ visibilityString: String) -> Bool {
        // Extract numeric value from the visibility string
        let numericPart = visibilityString.replacingOccurrences(of: "SM", with: "").trimmingCharacters(in: .whitespaces)
        
        // Handle "10+" format
        if numericPart.contains("+") {
            // If it contains a plus sign, it's definitely greater than 9SM
            return true
        }
        
        // Try to convert to Double
        if let visibilityValue = Double(numericPart), visibilityValue > 9.0 {
            return true
        }
        
        return false
    }
    
    // Helper to format abbreviated wind info (e.g., "240@7" or "240@7G25")
    private func formatAbbreviatedWind(_ windString: String) -> String {
        // Handle "Calm" case
        if windString == "Calm" {
            return "Calm"
        }
        
        // Try to extract direction, speed, and gust from formatted wind string
        // Format is typically "240° @ 7kts" or "240° @ 7kts G25kts"
        var result = ""
        
        // Extract direction
        if let dirEndIndex = windString.firstIndex(of: "°") {
            let directionSubstring = windString[..<dirEndIndex]
            
            // Convert to int and format with leading zeros to ensure 3 digits
            if let directionInt = Int(directionSubstring) {
                result += String(format: "%03d", directionInt)
            } else {
                // Fallback to original text if not an integer
                result += directionSubstring
            }
            
            // Add the degree symbol
            result += "°"
        }
        
        // Extract speed
        if let speedStartIndex = windString.firstIndex(of: "@"),
           let speedEndIndex = windString.range(of: "kts")?.lowerBound {
            let speedStartAdjusted = windString.index(speedStartIndex, offsetBy: 2) // Skip "@ "
            if speedStartAdjusted < speedEndIndex { // Safety check
                let speed = windString[speedStartAdjusted..<speedEndIndex].trimmingCharacters(in: .whitespaces)
                result += "@\(speed)"
            }
        }
        
        // Extract gust if present
        if windString.contains("G") {
            // Use regex to safely extract gust value
            let gustPattern = try? NSRegularExpression(pattern: "G(\\d+)kts", options: [])
            if let gustPattern = gustPattern,
               let match = gustPattern.firstMatch(in: windString, options: [], range: NSRange(windString.startIndex..., in: windString)) {
                if let range = Range(match.range(at: 1), in: windString) {
                    let gustValue = windString[range]
                    result += "G\(gustValue)"
                }
            }
        }
        
        return result
    }
    
    @objc private func showAirportManager() {
        // Create a SwiftUI hosting controller for our AirportManagementView
        let airportManagementView = AirportManagementView(airportManager: airportManager)
            .frame(width: 700, height: 600) // Fixed size to ensure buttons are visible
        
        let hostingController = NSHostingController(rootView: airportManagementView)
        
        // Create a window for the view with proper macOS window style
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600), // Taller to show buttons
            styleMask: [.titled, .closable, .miniaturizable], // Proper macOS window controls
            backing: .buffered,
            defer: false
        )
        
        window.title = "Manage Airports"
        window.contentViewController = hostingController
        window.center()
        window.level = .floating  // Keep window on top
        
        // Fix minimum size to ensure buttons remain visible
        window.minSize = NSSize(width: 700, height: 600)
        
        // Make sure the window is key and front
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Create a window controller to manage the window
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        
        // Add observer for when window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main) { [weak self] _ in
                // Stop observing
                NotificationCenter.default.removeObserver(self as Any, 
                    name: NSWindow.willCloseNotification, 
                    object: window)
                
                // Refresh data when window closes
                self?.refreshData()
                
                // Rebuild the menu to ensure it's not disabled
                self?.statusItem.menu = nil
                self?.showMenu()
            }
    }
}