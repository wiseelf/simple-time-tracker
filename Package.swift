// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeTracker",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.10.0")
    ],
    targets: [
        .target(
            name: "TimeTrackerCore",
            path: "Sources/TimeTrackerCore"
        ),
        .executableTarget(
            name: "TimeTracker",
            dependencies: ["TimeTrackerCore"],
            path: "Sources/TimeTracker",
            exclude: ["TimeTracker.entitlements"],
            resources: [.process("Assets.xcassets")]
        ),
        .testTarget(
            name: "TimeTrackerTests",
            dependencies: [
                "TimeTrackerCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/TimeTrackerTests"
        )
    ]
)
