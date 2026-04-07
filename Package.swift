// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "claude-pop",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "claude-pop",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore"),
            ]
        ),
    ]
)
