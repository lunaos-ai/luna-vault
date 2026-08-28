#if canImport(CryptoKit)
@_exported import CryptoKit
#elseif canImport(Crypto)
@_exported import Crypto
#else
#error("VaultCore requires CryptoKit (Apple) or swift-crypto (Linux/Windows)")
#endif
