// swift-tools-version: 5.10
import PackageDescription

#if os(Windows)
let cryptoPackage: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.8.0"),
]
let cryptoDeps: [Target.Dependency] = [
    .product(name: "Crypto", package: "swift-crypto"),
]
let sqliteTargets: [Target] = [
    .target(
        name: "CSQLite",
        path: "packages/CSQLite",
        exclude: ["README.md", ".gitignore", ".gitkeep"],
        publicHeadersPath: "include"
    ),
]
let sqliteDeps: [Target.Dependency] = ["CSQLite"]
let vaultLinker: [LinkerSetting] = [
    .linkedLibrary("crypt32"),
]
let secretTargets: [Target] = []
let secretDeps: [Target.Dependency] = []
let appleAppProducts: [Product] = []
let appleAppTargets: [Target] = []
#elseif os(Linux)
let cryptoPackage: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.8.0"),
]
let cryptoDeps: [Target.Dependency] = [
    .product(name: "Crypto", package: "swift-crypto"),
]
let sqliteTargets: [Target] = [
    .systemLibrary(
        name: "CSQLite",
        pkgConfig: "sqlite3",
        providers: [.apt(["libsqlite3-dev"])]
    ),
]
let sqliteDeps: [Target.Dependency] = ["CSQLite"]
let vaultLinker: [LinkerSetting] = [
    .linkedLibrary("sqlite3"),
]
let secretTargets: [Target] = [
    .target(
        name: "CLibSecret",
        path: "packages/CLibSecret",
        exclude: ["README.md"],
        publicHeadersPath: "include",
        linkerSettings: [.linkedLibrary("dl")]
    ),
]
let secretDeps: [Target.Dependency] = ["CLibSecret"]
let appleAppProducts: [Product] = []
let appleAppTargets: [Target] = []
#else
let cryptoPackage: [Package.Dependency] = []
let cryptoDeps: [Target.Dependency] = []
let sqliteTargets: [Target] = []
let sqliteDeps: [Target.Dependency] = []
let secretTargets: [Target] = []
let secretDeps: [Target.Dependency] = []
let vaultLinker: [LinkerSetting] = [
    .linkedLibrary("sqlite3"),
    .linkedFramework("Security"),
    .linkedFramework("LocalAuthentication"),
    .linkedFramework("CryptoKit"),
    .linkedFramework("Vision"),
]
let appleAppProducts: [Product] = [
    .executable(name: "VibeVaultApp", targets: ["VibeVaultApp"]),
]
let appleAppTargets: [Target] = [
    .testTarget(
        name: "VibeVaultAppTests",
        dependencies: ["VibeVaultApp"],
        path: "apps/VibeVaultAppTests"
    ),
    .executableTarget(
        name: "VibeVaultApp",
        dependencies: ["VaultCore"],
        path: "apps/VibeVaultApp",
        exclude: ["Info.plist", "VibeVault.entitlements", "Resources"]
    ),
]
#endif

let package = Package(
    name: "vibe-vault",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VaultCore", targets: ["VaultCore"]),
        .executable(name: "vibevault", targets: ["vibevault"]),
        .executable(name: "vibevault-browser-host", targets: ["vibevault-browser-host"]),
        .executable(name: "vibevault-mcp", targets: ["vibevault-mcp"]),
    ] + appleAppProducts,
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            "1.3.0"..<"1.8.0"
        ),
    ] + cryptoPackage,
    targets: sqliteTargets + secretTargets + [
        .target(
            name: "VaultCore",
            dependencies: cryptoDeps + sqliteDeps + secretDeps,
            path: "packages/VaultCore/Sources/VaultCore",
            linkerSettings: vaultLinker
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
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "cli/vibevault",
            exclude: ["vibevault.entitlements"]
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
    ] + appleAppTargets
)
