// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeGotchi",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeGotchi",
            path: "Sources/ClaudeGotchi",
            resources: [.copy("Resources")]
        )
    ]
)
