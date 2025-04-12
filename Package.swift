// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "AviationMetarMenubar",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "AviationMetarMenubar", targets: ["AviationMetarMenubar"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AviationMetarMenubar",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "AviationMetarMenubarTests",
            dependencies: ["AviationMetarMenubar"],
            path: "Tests"
        )
    ]
)