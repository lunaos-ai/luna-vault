// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "vibe-vault",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VaultCore", targets: ["VaultCore"]),
        .executable(name: "vibevault", targets: ["vibevault"]),
        .executable(name: "vibevault-browser-host", targets: ["vibevault-browser-host"]),
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
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("CryptoKit"),
                .linkedFramework("Vision")
            ]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"],
            path: "packages/VaultCore/Tests/VaultCoreTests"
        ),
        .testTarget(
            name: "VibeVaultAppTests",
            dependencies: ["VibeVaultApp"],
            path: "apps/VibeVaultAppTests"
        ),
        .executableTarget(
            name: "vibevault",
            dependencies: [
                "VaultCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "cli/vibevault",
            exclude: ["vibevault.entitlements"]
        ),
        .testTarget(
            name: "vibevaultTests",
            dependencies: ["vibevault"],
            path: "cli/vibevaultTests"
        ),
        .executableTarget(
            name: "vibevault-browser-host",
            dependencies: ["VaultCore"],
            path: "cli/vibevault-browser-host"
        ),
        .executableTarget(
            name: "vibevault-mcp",
            dependencies: ["VaultCore"],
            path: "cli/vibevault-mcp",
            exclude: ["vibevault-mcp.entitlements"]
        ),
        .executableTarget(
            name: "VibeVaultApp",
            dependencies: ["VaultCore"],
            path: "apps/VibeVaultApp",
            exclude: ["Info.plist", "VibeVault.entitlements", "Resources"]
        )
    ]
)
