# Aviation Metar Menubar

Aviation Metar Menubar is a macOS application that provides real-time aviation weather information (METARs) for various airports. The application runs in the macOS menubar and updates every 10 minutes to display the latest weather conditions.

## Features

- Displays METAR information for multiple airports.
- Updates automatically every 10 minutes.
- Configurable menu with options to refresh data and quit the application.
- Organized menu structure with airport codes as main entries and detailed weather information as sub-entries.

## Project Structure

```
AviationMetarMenubar
├── AviationMetarMenubar.xcodeproj
├── Sources
│   ├── AppDelegate.swift
│   ├── ContentView.swift
│   ├── MenuBarController.swift
│   ├── MetarService.swift
│   ├── Models
│   │   └── Metar.swift
│   └── Utilities
│       └── Constants.swift
├── Resources
│   ├── Assets.xcassets
│   └── Info.plist
├── Tests
│   └── AviationMetarMenubarTests.swift
└── README.md
```

## Setup Instructions

1. Clone the repository:
   ```
   git clone <repository-url>
   ```

2. Open the project in Xcode:
   ```
   open AviationMetarMenubar.xcodeproj
   ```

3. Build and run the application.

## Usage

- The application will appear in the macOS menubar.
- Click on the menubar icon to view the METAR information for the configured airports.
- Use the "Refresh Now" option in the Config menu to manually refresh the data.
- Select "Quit" to close the application.

## API Reference

The application fetches METAR data from the AviationWeather.gov API. For more information on the API, visit [AviationWeather.gov API Documentation](https://aviationweather.gov/data/api/#/Data/dataMetars).

## License

This project is licensed under the MIT License. See the LICENSE file for details.