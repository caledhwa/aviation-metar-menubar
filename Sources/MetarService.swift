import Foundation

// Updated MetarData structure with a custom decoding strategy for fields that can be different types
struct MetarData: Decodable {
    let metar_id: Int?
    let icaoId: String?
    let receiptTime: String?
    let obsTime: Int?
    let reportTime: String?
    let temp: Double?
    let dewp: Double?
    let wdir: String?  // This will be decoded from either Int or String
    let wspd: Int?
    let wgst: Int?
    let visib: SupportedNumericTypes?
    let altim: Double?
    let slp: Double?
    let qcField: Int?
    let wxString: String?
    let metarType: String?
    let rawOb: String?
    let mostRecent: Int?
    let lat: Double?
    let lon: Double?
    let elev: Int?
    let prior: Int?
    let name: String?
    let clouds: [CloudData]?
    
    struct CloudData: Decodable {
        let cover: String?
        let base: Int?
    }
    
    // Custom decoding init to handle mixed types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle regular fields
        metar_id = try container.decodeIfPresent(Int.self, forKey: .metar_id)
        icaoId = try container.decodeIfPresent(String.self, forKey: .icaoId)
        receiptTime = try container.decodeIfPresent(String.self, forKey: .receiptTime)
        obsTime = try container.decodeIfPresent(Int.self, forKey: .obsTime)
        reportTime = try container.decodeIfPresent(String.self, forKey: .reportTime)
        temp = try container.decodeIfPresent(Double.self, forKey: .temp)
        dewp = try container.decodeIfPresent(Double.self, forKey: .dewp)
        wspd = try container.decodeIfPresent(Int.self, forKey: .wspd)
        wgst = try container.decodeIfPresent(Int.self, forKey: .wgst)
        // Special handling for visib which can be either String or numeric
        visib = try container.decodeIfPresent(SupportedNumericTypes.self, forKey: .visib)
        altim = try container.decodeIfPresent(Double.self, forKey: .altim)
        slp = try container.decodeIfPresent(Double.self, forKey: .slp)
        qcField = try container.decodeIfPresent(Int.self, forKey: .qcField)
        wxString = try container.decodeIfPresent(String.self, forKey: .wxString)
        metarType = try container.decodeIfPresent(String.self, forKey: .metarType)
        rawOb = try container.decodeIfPresent(String.self, forKey: .rawOb)
        mostRecent = try container.decodeIfPresent(Int.self, forKey: .mostRecent)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
        elev = try container.decodeIfPresent(Int.self, forKey: .elev)
        prior = try container.decodeIfPresent(Int.self, forKey: .prior)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        clouds = try container.decodeIfPresent([CloudData].self, forKey: .clouds)
        
        // Special handling for wdir which can be either String or Int
        if let wdirString = try? container.decodeIfPresent(String.self, forKey: .wdir) {
            wdir = wdirString
        } else if let wdirInt = try? container.decodeIfPresent(Int.self, forKey: .wdir) {
            wdir = String(wdirInt)
        } else {
            wdir = nil
        }
    }
    
    // Define CodingKeys enum
    enum CodingKeys: String, CodingKey {
        case metar_id, icaoId, receiptTime, obsTime, reportTime, temp, dewp, wdir
        case wspd, wgst, visib, altim, slp, qcField, wxString, metarType, rawOb
        case mostRecent, lat, lon, elev, prior, name, clouds
    }
}

// Add a custom type to handle fields that could be either String or numeric (Int/Double)
enum SupportedNumericTypes: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else {
            throw DecodingError.typeMismatch(
                SupportedNumericTypes.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String, Int, or Double"
                )
            )
        }
    }
    
    // Helper method to convert to String
    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        }
    }
}

class MetarService {
    private let apiUrl = "https://aviationweather.gov/api/data/metar"
    private let refreshInterval: TimeInterval = 600 // 10 minutes
    private var timer: Timer?
    
    // Use AirportManager to get the airport codes
    private var airportManager: AirportManager?
    
    public var airports: [Metar] = []
    public var lastError: String?

    init(airportManager: AirportManager? = nil) {
        self.airportManager = airportManager
    }
    
    func startFetchingMetarData(completion: @escaping ([Metar]) -> Void) {
        fetchMetarData { success in
            if success {
                completion(self.airports)
                self.timer = Timer.scheduledTimer(withTimeInterval: self.refreshInterval, repeats: true) { _ in
                    self.fetchMetarData { success in
                        if success {
                            completion(self.airports)
                        }
                    }
                }
            }
        }
    }
    
    func stopFetchingMetarData() {
        timer?.invalidate()
        timer = nil
    }
    
    public func fetchMetarData(completion: @escaping (Bool) -> Void) {
        // Get the list of airport codes - use the manager if available, otherwise fall back to defaults
        let airportCodes: [String]
        if let manager = airportManager {
            airportCodes = manager.userAirports.map { $0.icaoId }
        } else {
            // Default list if no manager is provided
            airportCodes = ["KRNT", "KBFI", "KSEA", "KOLM", "KPWT", "KPLU", "KTIW", "KSHN", "KAWO", "KBVS", "KHQM", "KPAE", "KSPB", "KAST", "KCLS", "KKLS", "KPDX", "KHIO"]
        }
        
        // Ensure we have airports to fetch
        guard !airportCodes.isEmpty else {
            self.lastError = "No airports selected"
            completion(false)
            return
        }
        
        // Construct URL with query parameters for the specified airports
        var urlComponents = URLComponents(string: apiUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "ids", value: airportCodes.joined(separator: ",")),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "taf", value: "false")
        ]
        
        guard let url = urlComponents?.url else {
            self.lastError = "Invalid URL"
            completion(false)
            return
        }
        
        // Real API request implementation
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle error cases
            if let error = error {
                self.lastError = "Network error: \(error.localizedDescription)"
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.lastError = "Invalid response"
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                self.lastError = "HTTP error: \(httpResponse.statusCode)"
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard let data = data else {
                self.lastError = "No data received"
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            do {
                // Parse the API response
                self.airports = try self.parseMetarData(data: data)
                self.lastError = nil
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                self.lastError = "Parsing error: \(error.localizedDescription)"
                print("Parsing error: \(error)")
                
                // Print data for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Received JSON: \(jsonString)")
                }
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
        
        task.resume()
    }
    
    private func provideSampleData(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            // Simulate network delay
            Thread.sleep(forTimeInterval: 1.0)
            
            self.airports = [
                Metar(
                    airportCode: "KRNT",
                    flightCategory: "VFR",
                    weatherConditions: "BKN 5500",
                    visibility: "10+SM",
                    wind: "240° @ 3kts",
                    temperature: "8.3°C / 2.2°C",
                    altimeter: "30.35 inHg",
                    observationTime: "12.4.2025 15:00 (PDT)",
                    observationTimeZulu: "12Z22:00",
                    additionalConditions: ["SCT 4200ft"],
                    allCloudLayers: ["SCT 4200ft", "BKN 5500ft"]
                ),
                Metar(
                    airportCode: "KTIW",
                    flightCategory: "VFR",
                    weatherConditions: "SCT 6000",
                    visibility: "10SM",
                    wind: "220° @ 5kts",
                    temperature: "7.8°C / 1.5°C",
                    altimeter: "30.34 inHg",
                    observationTime: "12.4.2025 15:02 (PDT)",
                    observationTimeZulu: "12Z22:02",
                    additionalConditions: [],
                    allCloudLayers: ["SCT 6000ft"]
                ),
                Metar(
                    airportCode: "KBFI",
                    flightCategory: "MVFR",
                    weatherConditions: "OVC 2100",
                    visibility: "5SM",
                    wind: "210° @ 8kts",
                    temperature: "8.1°C / 3.3°C",
                    altimeter: "30.33 inHg",
                    observationTime: "12.4.2025 14:56 (PDT)",
                    observationTimeZulu: "12Z21:56",
                    additionalConditions: ["Light Rain"],
                    allCloudLayers: ["OVC 2100ft"]
                ),
                Metar(
                    airportCode: "KBLI",
                    flightCategory: "VFR",
                    weatherConditions: "FEW 5000",
                    visibility: "10SM",
                    wind: "190° @ 4kts",
                    temperature: "7.2°C / 0.5°C",
                    altimeter: "30.32 inHg",
                    observationTime: "12.4.2025 14:55 (PDT)",
                    observationTimeZulu: "12Z21:55",
                    additionalConditions: [],
                    allCloudLayers: ["FEW 5000ft"]
                ),
                Metar(
                    airportCode: "KPDX",
                    flightCategory: "VFR",
                    weatherConditions: "BKN 5500ft",
                    visibility: "10+SM",
                    wind: "240° @ 3kts",
                    temperature: "8.3°C / 2.2°C",
                    altimeter: "30.35 inHg",
                    observationTime: "12.4.2025 15:00 (PDT)",
                    observationTimeZulu: "12Z22:00",
                    additionalConditions: ["SCT 4200ft"],
                    allCloudLayers: ["SCT 4200ft", "BKN 5500ft"]
                )
            ]
            
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    private func parseMetarData(data: Data) throws -> [Metar] {
        // Parse JSON data from the Aviation Weather API
        let decoder = JSONDecoder()
        
        do {
            // Try to decode the response as an array of MetarData objects
            let response = try decoder.decode([MetarData].self, from: data)
            
            return response.map { metarData in
                // Determine flight category since it's not provided in the API
                let flightCategory = determineFlightCategory(visibility: metarData.visib, cloudLayers: metarData.clouds)
                
                // Format weather conditions from cloud layers
                let weatherConditions = formatCloudLayers(metarData.clouds)
                
                // Format visibility
                let visibilityString = formatVisibility(metarData.visib)
                
                // Format wind
                let windString = formatWind(metarData.wdir, windSpeed: metarData.wspd, windGust: metarData.wgst)
                
                // Format temperature
                let temperatureString = formatTemperature(metarData.temp, dewpoint: metarData.dewp)
                
                // Format altimeter
                let altimeterString = formatAltimeter(metarData.altim)
                
                // Format time - convert Unix timestamp to readable format
                let times = formatTimeFromTimestamp(metarData.obsTime)
                
                // Extract additional conditions from rawOb
                let additionalConditions = extractAdditionalConditions(from: metarData.rawOb ?? "")
                
                return Metar(
                    airportCode: metarData.icaoId ?? "Unknown",
                    airportName: metarData.name ?? "",
                    metarType: metarData.metarType ?? "METAR",
                    flightCategory: flightCategory,
                    weatherConditions: weatherConditions,
                    visibility: visibilityString,
                    wind: windString,
                    temperature: temperatureString,
                    altimeter: altimeterString,
                    observationTime: times.local,
                    observationTimeZulu: times.zulu,
                    additionalConditions: additionalConditions,
                    allCloudLayers: formatAllCloudLayers(metarData.clouds)
                )
            }
        } catch {
            // If the first format fails, try an alternative format
            print("First parsing attempt failed: \(error)")
            
            // Print data for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Received JSON: \(jsonString)")
            }
            
            // Try reading from the example file as a fallback
            if let exampleDataPath = Bundle.main.path(forResource: "exampleMetarOutput", ofType: "json"),
               let exampleData = try? Data(contentsOf: URL(fileURLWithPath: exampleDataPath)) {
                let exampleResponse = try decoder.decode([MetarData].self, from: exampleData)
                // Process example data similar to above
                // (This is just a fallback for testing)
                return exampleResponse.map { metarData in
                    let flightCategory = determineFlightCategory(visibility: metarData.visib, cloudLayers: metarData.clouds)
                    let times = formatTimeFromTimestamp(metarData.obsTime)
                    
                    return Metar(
                        airportCode: metarData.icaoId ?? "Unknown",
                        airportName: metarData.name ?? "",
                        metarType: metarData.metarType ?? "METAR",
                        flightCategory: flightCategory,
                        weatherConditions: formatCloudLayers(metarData.clouds),
                        visibility: formatVisibility(metarData.visib),
                        wind: formatWind(metarData.wdir, windSpeed: metarData.wspd, windGust: metarData.wgst),
                        temperature: formatTemperature(metarData.temp, dewpoint: metarData.dewp),
                        altimeter: formatAltimeter(metarData.altim),
                        observationTime: times.local,
                        observationTimeZulu: times.zulu,
                        additionalConditions: extractAdditionalConditions(from: metarData.rawOb ?? ""),
                        allCloudLayers: formatAllCloudLayers(metarData.clouds)
                    )
                }
            }
            
            // If all else fails, throw the error
            throw error
        }
    }
    
    // Updated helper functions to match the new MetarData structure
    private func formatCloudLayers(_ cloudLayers: [MetarData.CloudData]?) -> String {
        guard let layers = cloudLayers, !layers.isEmpty else { return "SKC" }
        
        // Find the lowest ceiling (BKN, OVC, or OVX)
        var lowestCeiling: (cover: String, base: Int)? = nil
        
        for layer in layers {
            if let cover = layer.cover, let base = layer.base {
                // Only consider OVC, BKN, or OVX as a ceiling
                if (cover == "OVC" || cover == "BKN" || cover == "OVX") {
                    // Initialize lowestCeiling if it's nil, or update if this layer is lower
                    if lowestCeiling == nil || base < lowestCeiling!.base {
                        lowestCeiling = (cover, base)
                    }
                }
            }
        }
        
        // Return the lowest ceiling if found
        if let ceiling = lowestCeiling {
            return "\(ceiling.cover) \(ceiling.base)ft"
        }
        
        // If no ceiling, return highest layer (as we did before)
        if let highestLayer = layers.max(by: { ($0.base ?? 0) < ($1.base ?? 0) }) {
            let coverage = highestLayer.cover ?? "Unknown"
            let height = highestLayer.base != nil ? "\(highestLayer.base!)ft" : ""
            return "\(coverage) \(height)"
        }
        
        return "Unknown"
    }
    
    private func formatVisibility(_ visibility: SupportedNumericTypes?) -> String {
        guard let vis = visibility else { return "Unknown" }
        return "\(vis.stringValue)SM"
    }
    
    private func formatWind(_ windDir: String?, windSpeed: Int?, windGust: Int?) -> String {
        // If wind speed is 0 or nil, return "Calm"
        if (windSpeed == 0 || windSpeed == nil) && windDir == nil {
            return "Calm"
        }
        
        // Format the direction, handling VRB (variable) case
        let direction: String
        if let dir = windDir {
            if (dir == "VRB" || dir == "Variable") {
                direction = "Variable"
            } else if let dirInt = Int(dir) {
                direction = "\(dirInt)°"
            } else {
                direction = dir
            }
        } else {
            direction = "Variable"
        }
        
        let speed = windSpeed != nil ? "\(windSpeed!)kts" : "0kts"
        let gust = windGust != nil ? " G\(windGust!)kts" : ""
        
        return "\(direction) @ \(speed)\(gust)"
    }
    
    private func formatTemperature(_ temp: Double?, dewpoint: Double?) -> String {
        let tempC = temp != nil ? String(format: "%.1f°C", temp!) : "Unknown"
        let dewC = dewpoint != nil ? String(format: "%.1f°C", dewpoint!) : "Unknown"
        
        return "\(tempC) / \(dewC)"
    }
    
    private func formatAltimeter(_ alt: Double?) -> String {
        guard let alt = alt else { return "Unknown" }
        
        // Check if the value is likely in millibars (typically around 1013-1030 mb)
        // Standard atmospheric pressure is 1013.25 mb or 29.92 inHg
        if alt > 100 {  // If greater than 100, it's likely millibars
            // Convert from millibars to inches of mercury
            // 1 millibar = 0.02953 inches of mercury
            let inHg = alt * 0.02953
            return String(format: "%.2f inHg", inHg)
        } else {
            // Value is already in inches of mercury
            return String(format: "%.2f inHg", alt)
        }
    }
    
    private func formatTime(_ time: Int?) -> String {
        guard let time = time else { return "Unknown" }
        
        // Format the time string to a more readable format
        // This is a simplified conversion
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = dateFormatter.date(from: String(time)) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MM.dd.yyyy HH:mm"
            outputFormatter.timeZone = TimeZone.current
            let localTime = outputFormatter.string(from: date)
            return "\(localTime) (\(TimeZone.current.abbreviation() ?? "Local"))"
        }
        
        return "\(time) (UTC)"
    }
    
    private func extractAdditionalConditions(from rawMETAR: String) -> [String] {
        // This is a simplified implementation
        // In a real app, you would parse the rawMETAR to extract additional conditions
        var conditions: [String] = []
        
        // Extract precipitation
        if rawMETAR.contains("RA") {
            conditions.append("Rain")
        } else if rawMETAR.contains("-RA") {
            conditions.append("Light Rain")
        } else if rawMETAR.contains("+RA") {
            conditions.append("Heavy Rain")
        }
        
        return conditions
    }
    
    // Updated flight category determination based on correct FAA criteria
    private func determineFlightCategory(visibility: SupportedNumericTypes?, cloudLayers: [MetarData.CloudData]?) -> String {
        // Extract numeric visibility value, handling "10+" format
        let visibilityValue: Double
        if let visString = visibility?.stringValue {
            if visString.contains("+") {
                // Handle "10+" or similar format
                if let numericPart = Double(visString.replacingOccurrences(of: "+", with: "")) {
                    visibilityValue = numericPart
                } else {
                    visibilityValue = 0.0
                }
            } else if let doubleValue = Double(visString) {
                visibilityValue = doubleValue
            } else {
                visibilityValue = 0.0
            }
        } else {
            visibilityValue = 0.0
        }
        
        // Get lowest cloud ceiling
        var lowestCeiling = Int.max
        if let clouds = cloudLayers {
            for cloud in clouds {
                if let cover = cloud.cover, let base = cloud.base {
                    // Only consider OVC, BKN, or OVX as a ceiling
                    if (cover == "OVC" || cover == "BKN" || cover == "OVX") && base < lowestCeiling {
                        lowestCeiling = base
                    }
                }
            }
        }
        
        // If no ceiling was found, set to unlimited
        if lowestCeiling == Int.max {
            lowestCeiling = 999999
        }
        
        // Correct flight category determination based on FAA criteria
        if visibilityValue < 1.0 || lowestCeiling < 500 {
            return "LIFR" // Low IFR
        } else if visibilityValue < 3.0 || lowestCeiling < 1000 {
            return "IFR"  // IFR
        } else if visibilityValue <= 5.0 || lowestCeiling < 3000 {
            return "MVFR" // Marginal VFR (includes visibility exactly at 5.0)
        } else {
            return "VFR"  // VFR (visibility > 5.0 and ceiling >= 3000)
        }
    }
    
    // New method to format time from Unix timestamp that returns both local and Zulu time
    private func formatTimeFromTimestamp(_ timestamp: Int?) -> (local: String, zulu: String) {
        guard let timestamp = timestamp else { return (local: "Unknown", zulu: "Unknown") }
        
        let date = Date(timeIntervalSince1970: Double(timestamp))
        
        // Format local time
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "MM.dd.yyyy HH:mm"
        localFormatter.timeZone = TimeZone.current
        let localTime = "\(localFormatter.string(from: date)) (\(TimeZone.current.abbreviation() ?? "Local"))"
        
        // Format Zulu (UTC) time
        let zuluFormatter = DateFormatter()
        zuluFormatter.dateFormat = "dd'Z'HH:mm"  // Aviation format: day followed by Z and time
        zuluFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let zuluTime = zuluFormatter.string(from: date)
        
        return (local: localTime, zulu: zuluTime)
    }

    // New method to format all cloud layers as an array of strings
    private func formatAllCloudLayers(_ cloudLayers: [MetarData.CloudData]?) -> [String] {
        guard let layers = cloudLayers, !layers.isEmpty else { return ["SKC"] }
        
        // Sort layers by altitude (ascending)
        let sortedLayers = layers.sorted { ($0.base ?? 0) < ($1.base ?? 0) }
        
        // Format each layer
        return sortedLayers.map { layer in
            let coverage = layer.cover ?? "Unknown"
            let height = layer.base != nil ? "\(layer.base!)ft" : ""
            return "\(coverage) \(height)"
        }
    }
}