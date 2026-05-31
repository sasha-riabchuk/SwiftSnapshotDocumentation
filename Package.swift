// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSnapshotDocumentation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftSnapshotDocumentation",
            targets: ["SwiftSnapshotDocumentation"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.15.0"
        )
    ],
    targets: [
        // Main library target
        .target(
            name: "SwiftSnapshotDocumentation",
            dependencies: [
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            resources: [
                .copy("Resources/FlowExplorerAssets")
            ]
        ),

        // Demo examples target
        .target(
            name: "SwiftSnapshotDocumentationExamples",
            dependencies: ["SwiftSnapshotDocumentation"],
            resources: [
                .process("Resources")
            ]
        ),

        // Unit tests
        .testTarget(
            name: "SwiftSnapshotDocumentationTests",
            dependencies: ["SwiftSnapshotDocumentation"]
        ),

        // Demo flow documentation tests (generates actual DocC)
        .testTarget(
            name: "ExampleFlowDocumentationTests",
            dependencies: [
                "SwiftSnapshotDocumentation",
                "SwiftSnapshotDocumentationExamples"
            ]
        )
    ]
)
