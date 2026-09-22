// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "music",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "music",
            targets: ["music"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "music",
            dependencies: [],
            path: "music",
            exclude: [
                "Resources/Assets.xcassets",
                "Resources/Info.plist",
                "Resources/music.entitlements"
            ]
        ),
        .testTarget(
            name: "MusicTests",
            dependencies: ["music"],
            path: "Tests/MusicTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
