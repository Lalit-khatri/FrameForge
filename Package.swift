// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FrameForge",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FrameForge", targets: ["FrameForge"]),
    ],
    targets: [
        .target(
            name: "FrameForge",
            path: "FrameForge"
        ),
    ]
)
