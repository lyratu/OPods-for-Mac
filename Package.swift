// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OPodsMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OPodsMac", targets: ["OPodsMac"])
    ],
    targets: [
        .executableTarget(
            name: "OPodsMac",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "OPodsMacTests",
            dependencies: ["OPodsMac"]
        )
    ]
)
