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
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "WorkManager",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
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
