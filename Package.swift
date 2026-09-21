// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-chrono-pt",
    platforms: [.iOS(.v16), .macOS(.v13), .watchOS(.v9), .tvOS(.v16), .visionOS(.v1)],
    products: [
        .library(name: "ChronoPT", targets: ["ChronoPT"])
    ],
    targets: [
        .target(name: "ChronoPT"),
        .testTarget(name: "ChronoPTTests", dependencies: ["ChronoPT"])
    ]
)
