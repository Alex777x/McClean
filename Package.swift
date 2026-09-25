// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "McClean",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "McCleanKit",
            targets: ["McCleanKit"]
        ),
        .executable(
            name: "McClean",
            targets: ["McClean"]
        )
    ],
    targets: [
        .target(
            name: "McCleanKit",
            path: "Sources/McCleanKit",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "McClean",
            dependencies: ["McCleanKit"],
            path: "Sources/McClean",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "McCleanTests",
            dependencies: ["McCleanKit"],
            path: "Tests/McCleanTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
