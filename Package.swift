// swift-tools-version: 5.9
// The Xcode project is the canonical app build. This manifest exists so the
// logic can be compiled and tested from the command line (`swift test`) without
// the Xcode GUI. Keep it in sync with the actual imports.

import PackageDescription

let package = Package(
    name: "Pastable",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "Pastable",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Pastable",
            exclude: [
                "Assets.xcassets",
                "Resources",
                "Pastable.entitlements",
                "PastableDebug.entitlements",
                ".codex",
                ".specify"
            ]
        ),
        .testTarget(
            name: "PastableTests",
            dependencies: ["Pastable"],
            path: "Tests/PastableTests"
        )
    ]
)
