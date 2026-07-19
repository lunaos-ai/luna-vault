# Review Notes

Vibe Vault Importer requires the Vibe Vault macOS app or CLI and the native messaging host.

## Test Setup

1. Install/build Vibe Vault.
2. Load the unpacked extension from `extensions/browser-vibevault`.
3. Copy the extension id from `chrome://extensions`.
4. Run:

   ```bash
   vibevault browser install --browser chrome --extension-id <extension-id>
   ```

5. Open a supported provider page such as Google AI Studio. When a generated key is visible, the Vibe Vault panel offers to save it.

## Native Host

Native messaging host id:

```text
com.lunaos.vibevault.importer
```

The host accepts:

```json
{ "type": "ping" }
```

and:

```json
{
  "type": "save_secret",
  "name": "GEMINI_API_KEY",
  "value": "example",
  "provider": "Google Gemini",
  "sourceUrl": "https://aistudio.google.com/",
  "overwrite": false,
  "mcpAllowed": false
}
```
