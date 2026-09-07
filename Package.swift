// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fleet",
    defaultLocalization: "ko",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Fleet",
            targets: ["Fleet"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Fleet",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/Fleet",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "FleetTests",
            dependencies: ["Fleet"],
            path: "Tests/FleetTests"
        )
    ]
)
