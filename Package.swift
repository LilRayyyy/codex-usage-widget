// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexUsageWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CodexUsageCore", targets: ["CodexUsageCore"])
    ],
    targets: [
        .target(
            name: "CodexUsageCore",
            path: "Sources/CodexUsageCore",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "CodexUsageCoreTests",
            dependencies: ["CodexUsageCore"],
            path: "Tests/CodexUsageCoreTests"
        )
    ]
)
