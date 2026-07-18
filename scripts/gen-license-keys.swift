#!/usr/bin/env swift
import CryptoKit
import Foundation

/// Generate an Ed25519 keypair for Vibe Vault Team licenses.
/// usage: swift scripts/gen-license-keys.swift [out-dir]
/// Writes public.b64 (safe to commit after embedding) and private.b64 (gitignored).

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dist/lemonsqueezy"
let fm = FileManager.default
try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let priv = Curve25519.Signing.PrivateKey()
let pubB64 = priv.publicKey.rawRepresentation.base64EncodedString()
let privB64 = priv.rawRepresentation.base64EncodedString()

let pubPath = (outDir as NSString).appendingPathComponent("public.b64")
let privPath = (outDir as NSString).appendingPathComponent("private.b64")
try (pubB64 + "\n").write(toFile: pubPath, atomically: true, encoding: .utf8)
try (privB64 + "\n").write(toFile: privPath, atomically: true, encoding: .utf8)
try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privPath)

print("public:  \(pubPath)")
print("         \(pubB64)")
print("private: \(privPath) (chmod 600, do not commit)")
print("")
print("Embed public into LicensePublicKey.base64, then rotate any previously issued keys.")
