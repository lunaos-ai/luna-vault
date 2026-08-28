// swift-tools-version: 5.10
import PackageDescription

/// Cross-platform desktop UI (Gtk 4 on Linux, WinUI on Windows, AppKit backend on macOS).
/// macOS production UI remains `VibeVaultApp` (SwiftUI) in the root package.
let package = Package(
    name: "VibeVaultDesktop",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VibeVaultDesktop", targets: ["VibeVaultDesktop"]),
    ],
    dependencies: [
        .package(name: "vibe-vault", path: "../.."),
        .package(
            url: "https://github.com/moreSwift/swift-cross-ui.git",
            exact: "0.9.0"
        ),
        // Keep under 1.8 so Linux Swift 5.10 CI can resolve (1.8+ needs tools 6.0).
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            "1.3.0"..<"1.8.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "VibeVaultDesktop",
            dependencies: [
                .product(name: "VaultCore", package: "vibe-vault"),
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui"),
            ]
        ),
    ]
)
