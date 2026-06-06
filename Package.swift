// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "vibe-vault",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VaultCore", targets: ["VaultCore"]),
        .executable(name: "vibevault", targets: ["vibevault"]),
        .executable(name: "vibevault-mcp", targets: ["vibevault-mcp"]),
        .executable(name: "VibeVaultApp", targets: ["VibeVaultApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "VaultCore",
            path: "packages/VaultCore/Sources/VaultCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Security"),
                .linkedFramework("LocalAuthentication")
            ]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"],
            path: "packages/VaultCore/Tests/VaultCoreTests"
        ),
        .executableTarget(
            name: "vibevault",
            dependencies: [
                "VaultCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "cli/vibevault"
        ),
        .testTarget(
            name: "vibevaultTests",
            dependencies: [
                "vibevault",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "cli/vibevaultTests"
        ),
        .executableTarget(
            name: "vibevault-mcp",
            dependencies: ["VaultCore"],
            path: "cli/vibevault-mcp"
        ),
        .executableTarget(
            name: "VibeVaultApp",
            dependencies: ["VaultCore"],
            path: "apps/VibeVaultApp",
            exclude: ["Info.plist", "VibeVault.entitlements", "Resources"]
        )
    ]
)
