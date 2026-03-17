// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Smeta",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "SmetaApp", targets: ["SmetaApp"])
    ],
    targets: [
        .executableTarget(
            name: "SmetaApp",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("PDFKit"),
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
