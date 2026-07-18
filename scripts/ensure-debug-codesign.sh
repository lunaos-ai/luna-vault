#!/usr/bin/env bash
# Resolve a codesigning identity for local builds.
#
# Ad-hoc signing (codesign -s -) changes the CDHash every rebuild, so macOS
# Keychain treats the app as a new binary and re-prompts "Always Allow".
# That dialog asks for the login keychain *password* — Touch ID never works there.
#
# Preference order:
#   1. CODESIGN_IDENTITY env
#   2. "Vibe Vault Debug" if present
#   3. First valid codesigning identity
#   4. Ad-hoc "-" (Always Allow will not stick across rebuilds)
#
# To create a stable local identity once (Keychain Access):
#   Certificate Assistant → Create a Certificate →
#   Name: Vibe Vault Debug · Identity Type: Self Signed Root ·
#   Certificate Type: Code Signing · Let me override defaults → Continue
#   Then: Trust → Code Signing → Always Trust
# Or renew Apple Development in Xcode (Accounts → Manage Certificates).

set -euo pipefail

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    echo "$CODESIGN_IDENTITY"
    exit 0
fi

LIST="$(security find-identity -v -p codesigning 2>/dev/null || true)"

if echo "$LIST" | grep -q "Vibe Vault Debug"; then
    echo "Vibe Vault Debug"
    exit 0
fi

# Prefer any valid (non-expired) identity.
FIRST="$(echo "$LIST" | sed -n 's/^ *[0-9]*) \([A-F0-9]*\) "\([^"]*\)".*/\2/p' | head -1)"
if [ -n "$FIRST" ]; then
    echo "$FIRST"
    exit 0
fi

echo "-"
exit 0
