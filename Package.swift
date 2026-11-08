// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Ledge",
    platforms: [.macOS("15.0")],
    targets: [
        .target(name: "LedgeKit"),
        .executableTarget(name: "Ledge", dependencies: ["LedgeKit"]),
        .testTarget(name: "LedgeKitTests", dependencies: ["LedgeKit"]),
    ]
)
