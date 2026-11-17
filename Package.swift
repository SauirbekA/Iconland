// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Iconland",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Iconland",
            path: "Sources/Iconland",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
