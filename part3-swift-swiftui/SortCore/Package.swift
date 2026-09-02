// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SortCore",
    platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "SortCore", targets: ["SortCore"]),
        .executable(name: "sortbench", targets: ["sortbench"]),
    ],
    targets: [
        .target(
            name: "SortCore",
            swiftSettings: [.unsafeFlags(["-Ounchecked"], .when(configuration: .release))]
        ),
        .executableTarget(name: "sortbench", dependencies: ["SortCore"]),
        .testTarget(name: "SortCoreTests", dependencies: ["SortCore"]),
    ]
)
