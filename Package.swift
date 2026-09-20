// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Far",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Far", targets: ["Far"])
    ],
    targets: [
        .target(name: "FarCore"),
        .executableTarget(
            name: "Far",
            dependencies: ["FarCore"]
        ),
        .testTarget(
            name: "FarCoreTests",
            dependencies: ["FarCore"]
        ),
        .testTarget(
            name: "FarTests",
            dependencies: ["FarCore", "Far"]
        ),
    ]
)
