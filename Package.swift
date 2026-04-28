// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tempura",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TempuraCore",
            targets: ["TempuraCore"]
        ),
        .executable(
            name: "Tempura",
            targets: ["TempuraApp"]
        ),
        .executable(
            name: "tempura-probe",
            targets: ["TempuraProbe"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .target(
            name: "TempuraCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "TempuraApp",
            dependencies: [
                "TempuraCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .executableTarget(
            name: "TempuraProbe",
            dependencies: ["TempuraCore"]
        ),
        .testTarget(
            name: "TempuraCoreTests",
            dependencies: ["TempuraCore"]
        )
    ]
)
