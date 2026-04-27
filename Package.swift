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
    targets: [
        .target(
            name: "TempuraCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "TempuraApp",
            dependencies: ["TempuraCore"]
        ),
        .executableTarget(
            name: "TempuraProbe",
            dependencies: ["TempuraCore"]
        )
    ]
)
