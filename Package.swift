// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "luna-vault",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VaultCore", targets: ["VaultCore"]),
        .executable(name: "lunavault", targets: ["lunavault"])
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
            name: "lunavault",
            dependencies: [
                "VaultCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "cli/lunavault"
        )
    ]
)
