// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ctrlgrp",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Test-only. This machine has Command Line Tools without Xcode, where
        // XCTest is absent and the bundled Testing.framework ships without its
        // runtime dylib. Drop this dependency if full Xcode is ever installed:
        // the test sources use the same API as the toolchain version.
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
    ],
    targets: [
        .target(name: "CtrlgrpCore"),
        .executableTarget(name: "ctrlgrp", dependencies: ["CtrlgrpCore"]),
        .testTarget(
            name: "CtrlgrpCoreTests",
            dependencies: [
                "CtrlgrpCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
