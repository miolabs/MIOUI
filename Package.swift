// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MIOUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MIOUI", targets: ["MIOUI"]),
    ],
    targets: [
        .target(name: "MIOUI"),
        .testTarget(name: "MIOUITests", dependencies: ["MIOUI"]),
    ]
)
