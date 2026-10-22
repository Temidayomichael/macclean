// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacClean",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacClean",
            path: "Sources/MacClean"
        )
    ]
)
