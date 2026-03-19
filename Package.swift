// swift-tools-version: 5.7
import PackageDescription

var products: [Product] = [
    .library(name: "SmetaCore", targets: ["SmetaCore"])
]

var targets: [Target] = [
    .target(
        name: "SmetaCore",
        path: "Sources/SmetaCore",
        linkerSettings: [
            .linkedLibrary("sqlite3")
        ]
    ),
    .testTarget(name: "SmetaAppTests", dependencies: ["SmetaCore"])
]

#if os(macOS)
products.insert(.executable(name: "SmetaApp", targets: ["SmetaApp"]), at: 0)
targets.insert(
    .executableTarget(
        name: "SmetaApp",
        dependencies: ["SmetaCore"],
        linkerSettings: [
            .linkedFramework("SwiftUI"),
            .linkedFramework("AppKit"),
            .linkedFramework("PDFKit"),
            .linkedLibrary("sqlite3")
        ]
    ),
    at: 1
)
targets.append(
    .testTarget(
        name: "SmetaAppStartupTests",
        dependencies: ["SmetaApp"]
    )
)
#endif

let package = Package(
    name: "Smeta",
    platforms: [
        .macOS(.v12)
    ],
    products: products,
    targets: targets
)
