// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "reword",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "RewordCore"),
        .executableTarget(name: "reword", dependencies: ["RewordCore"]),
        .testTarget(name: "RewordCoreTests", dependencies: ["RewordCore"]),
    ]
)
