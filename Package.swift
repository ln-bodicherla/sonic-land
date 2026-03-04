// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SonicLand",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SonicLand",
            dependencies: [],
            path: "Sources/SonicLand",
            resources: [
                .copy("../../Resources/Info.plist"),
                .copy("../../Resources/AppIcon.icns")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Network"),
            ]
        ),
        .executableTarget(
            name: "sonicctl",
            dependencies: [],
            path: "Sources/sonicctl",
            linkerSettings: [
                .linkedFramework("Network"),
            ]
        ),
    ]
)
