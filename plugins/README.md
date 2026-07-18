# Provider plugins (v0.3)

Third-party sync targets for Vibe Vault. Builtin providers (Cloudflare, Vercel, PushCI) live in VaultCore.

## Manifest

Drop a `manifest.json` into:

```
~/Library/Application Support/vibe-vault/plugins/my-provider.json
```

Schema matches `ProviderPluginManifest` in VaultCore.

v0.1 loads manifests for display only. v0.3 will load SwiftPM plugin bundles implementing `SecretProvider`.

## Examples

- `github-actions/manifest.json` — GitHub Actions secrets (stub)
