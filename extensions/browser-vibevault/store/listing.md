# Chrome Web Store Listing

## Name

Vibe Vault Importer

## Summary

Save freshly generated AI provider API keys directly into your local Vibe Vault.

## Description

Vibe Vault Importer helps developers move newly generated API keys from provider dashboards into Vibe Vault without pasting keys into chat, notes, or terminal commands.

When a supported provider page displays a new key, or exposes it through a Copy API key button, the extension shows a small save panel. The key is sent only after you click Save, and it is handed to the local Vibe Vault native host through Chrome Native Messaging. Vibe Vault then stores it in the encrypted local vault and preserves the normal audit path.

No browser login is required for Solo use. The popup connects to the local Vibe Vault native host, links to the install guide, and points Team users to license information without uploading secrets to a hosted extension account.

The extension runs only on explicitly supported API-key dashboard pages declared in its Chrome host permissions. Provider support is limited to pages where Vibe Vault can detect a visible key or a user-triggered copy action, and unsupported pages are ignored.

## Category

Developer Tools

## Language

English

## Support URL

https://vibevault.lunaos.ai/

## Website

https://vibevault.lunaos.ai/

## Single Purpose

Detect visible or user-copied API keys on supported provider dashboards and save them into the user's local Vibe Vault through a native messaging host after explicit user action.
