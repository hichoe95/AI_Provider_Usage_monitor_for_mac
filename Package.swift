// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "UsageMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AIUsageMonitor", targets: ["UsageMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "UsageMonitor",
            dependencies: ["UsageMonitorCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(name: "UsageMonitorCore")
    ]
)
