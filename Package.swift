// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Smeta",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "SmetaApp", targets: ["SmetaApp"]),
        .library(name: "SmetaCore", targets: ["SmetaCore"])
    ],
    targets: [
        .target(
            name: "SmetaCore",
            path: "Sources/SmetaCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "SmetaApp",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("PDFKit"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(name: "SmetaAppTests", dependencies: ["SmetaCore"])
    ]
)
