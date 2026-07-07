// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MojuKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "MojuKit",
            targets: ["MojuKit"]
        )
    ],
    targets: [
        .target(
            name: "MojuKit"
        )
    ]
)
