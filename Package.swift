// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tuft",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Tuft", path: "Sources/Tuft")
    ]
)
