# Vibe Vault Browser Importer

Chrome-compatible extension for importing freshly generated provider API keys into Vibe Vault without copying them into chat, local storage, or command arguments.

## Setup

1. Build the CLI and native host:

   ```bash
   swift build --product vibevault
   swift build --product vibevault-browser-host
   ```

2. Open `chrome://extensions`, enable Developer mode, and load this folder as an unpacked extension:

   ```text
   extensions/browser-vibevault
   ```

3. Copy the extension id from Chrome and install the native host manifest:

   ```bash
   ./.build/debug/vibevault browser install --browser chrome --extension-id <extension-id>
   ```

   For Brave, Edge, or Chromium, replace `chrome` with `brave`, `edge`, `chromium`, or `all`.

4. Visit a supported provider key page. When a key is detected, Vibe Vault shows a small save panel.

## Package

```bash
bash scripts/package-browser-extension.sh
```

The Web Store upload zip is written to `build/VibeVault-Browser-Importer.zip`. Listing copy, privacy text, review notes, and screenshots are in `store/`.

## Supported Pages

- Google AI Studio / Gemini
- OpenAI platform
- Anthropic console
- Groq console
- Mistral console
- Cohere dashboard
- Together AI
- DeepSeek platform
- OpenRouter
- Replicate
- Stripe dashboard
- GitHub tokens
- Vercel tokens
- Cloudflare dashboard

The extension also accepts a selected value on those pages when it looks like a secret but does not match a provider-specific pattern.

## Security Model

- The content script does not use `chrome.storage`, `localStorage`, or IndexedDB.
- Raw key values stay in page memory until the user clicks **Save**.
- The native messaging manifest restricts calls to the installed extension id.
- `vibevault-browser-host` validates the request and writes through `VaultService.live()`, so imports use the same encrypted vault and audit path as the CLI.
- Existing secrets are not overwritten unless **Update if name exists** is checked.
