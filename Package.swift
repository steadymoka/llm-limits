// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLMLimits",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LLMLimits",
            path: "ClaudeUsage",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "LLMLimitsTests",
            dependencies: ["LLMLimits"]
        ),
    ]
)
