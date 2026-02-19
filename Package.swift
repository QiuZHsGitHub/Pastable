// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Pastable",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Existing dependencies
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.6"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.4.0"),
        .package(url: "https://github.com/Clipy/Sauce.git", branch: "master"),
        
        // Add Fuse for fuzzy search
        .package(url: "https://github.com/krisk/fuse-swift.git", from: "1.4.0"),
        
        // Other dependencies from DEPENDENCIES.md
        .package(url: "https://github.com/sindresorhus/Settings.git", from: "3.1.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.4"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
        .package(url: "https://github.com/thii/SwiftHEXColors.git", from: "1.4.1"),
        .package(url: "fuse-swift", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "Pastable",
            dependencies: [
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Fuse", package: "fuse-swift"),
                .product(name: "Settings", package: "Settings"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "OSLog", package: "swift-log"),
                .product(name: "SwiftHEXColors", package: "SwiftHEXColors"),
                "Sauce"
            ]
        )
    ]
)
