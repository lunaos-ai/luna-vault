# Privacy

Vibe Vault Importer does not sell or share user data.

The extension does not use `chrome.storage`, `localStorage`, IndexedDB, analytics, telemetry, or remote logging.

API key values are kept in page memory only long enough to show the save panel. A raw key is sent to the local native messaging host only after the user clicks Save. The native host writes the key to the local encrypted Vibe Vault store.

The extension requests access only to supported provider dashboard domains. It does not run on arbitrary websites.

Data handled:

- API key values visible on supported provider dashboards
- Suggested secret names entered by the user
- Current provider page URL, stored only as local Vibe Vault notes for source context

Data not collected:

- Browsing history
- Account profile data
- Payment data
- Personal communications
- Analytics or usage telemetry
