// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicPageKitStudioPackage",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DynamicPageKitCore",
            targets: ["DynamicPageKitCore"]
        ),
        .executable(
            name: "DynamicPageKitStudio",
            targets: ["DynamicPageKitStudio"]
        ),
        .executable(
            name: "DynamicPageKitCLI",
            targets: ["DynamicPageKitCLI"]
        )
    ],
    targets: [
        .target(
            name: "DynamicPageKitCore"
        ),
        .executableTarget(
            name: "DynamicPageKitStudio",
            dependencies: ["DynamicPageKitCore"]
        ),
        .executableTarget(
            name: "DynamicPageKitCLI",
            dependencies: ["DynamicPageKitCore"]
        ),
        .testTarget(
            name: "DynamicPageKitCoreTests",
            dependencies: ["DynamicPageKitCore"]
        ),
        .testTarget(
            name: "DynamicPageKitStudioTests",
            dependencies: ["DynamicPageKitStudio"]
        )
    ]
)
