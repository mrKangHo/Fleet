// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WorkManager",
            targets: ["WorkManager"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WorkManager",
            dependencies: [],
            path: "Sources/WorkManager",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "WorkManagerTests",
            dependencies: ["WorkManager"],
            path: "Tests/WorkManagerTests"
        )
    ]
)
