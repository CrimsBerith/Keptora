// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeptoraCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "KeptoraCore", targets: ["KeptoraCore"])
    ],
    targets: [
        .target(
            name: "KeptoraCore",
            linkerSettings: [
                .linkedFramework("Photos"),
                .linkedFramework("ImageIO"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Vision")
            ]
        ),
        .testTarget(name: "KeptoraCoreTests", dependencies: ["KeptoraCore"])
    ]
)
