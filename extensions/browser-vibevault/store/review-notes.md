# Review Notes

Vibe Vault Importer requires the Vibe Vault macOS app or CLI and the native messaging host.

The extension has no hosted login flow. Solo users connect a local native host;
Team licenses are handled by the Vibe Vault app or CLI and are verified offline.

## Test Setup

1. Install/build Vibe Vault.
2. Load the unpacked extension from `extensions/browser-vibevault`.
3. Copy the extension id from `chrome://extensions`.
4. Run:

   ```bash
   vibevault browser install --browser chrome --extension-id nfeigikipagiccmhlolgfbeienkckbpc
   ```

5. Open a supported provider page such as Google AI Studio. When a generated key is visible, or after the user clicks a provider "Copy API key" button, the Vibe Vault panel offers to save it.

The extension requests `clipboardRead` only for provider dashboards that hide API key values behind a copy button. Clipboard text is read after the user clicks a provider copy control, filtered against provider API-key patterns, kept in page memory only long enough to show the save panel, and sent to the native host only after the user clicks Save.

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
