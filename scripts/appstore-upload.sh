#!/usr/bin/env bash
set -euo pipefail

# Upload VibeVault to the Mac App Store.
#
# Required environment variables:
#   APPSTORE_API_KEY_ID     App Store Connect API key ID (e.g. ABCDEF1234)
#   APPSTORE_API_ISSUER_ID  App Store Connect API issuer ID
#   APPSTORE_API_KEY        Base64-encoded App Store Connect API private key (.p8)
#
# Optional but strongly recommended:
#   APPSTORE_DISTRIBUTION_IDENTITY  Common name of a "Mac App Distribution" cert
#   APPSTORE_INSTALLER_IDENTITY   Common name of a "Mac Installer Distribution" cert
#   APPSTORE_PROVISION_PROFILE    Base64-encoded .provisionprofile for dev.vibevault
#
# Usage:
#   bash scripts/appstore-upload.sh

cd "$(dirname "$0")/.."

fail() { echo "error: $1" >&2; exit 1; }

required=(APPSTORE_API_KEY_ID APPSTORE_API_ISSUER_ID APPSTORE_API_KEY)
for v in "${required[@]}"; do
    [ -n "${!v:-}" ] || fail "$v is not set"
done

# Build the signed .app bundle (release).
bash scripts/bundle-app.sh release

APP_PATH="build/VibeVault.app"
VERSION=$(plutil -extract CFBundleShortVersionString raw apps/VibeVaultApp/Info.plist)
BUILD=$(plutil -extract CFBundleVersion raw apps/VibeVaultApp/Info.plist)
PKG_PATH="build/VibeVault-${VERSION}-${BUILD}.pkg"

echo "==> Creating installer package: $PKG_PATH"

# If a Mac App Distribution identity is provided, re-sign everything so Apple
# accepts the upload. Otherwise bundle-app.sh already ad-hoc / debug-signed.
if [ -n "${APPSTORE_DISTRIBUTION_IDENTITY:-}" ]; then
    echo "  re-signing with: $APPSTORE_DISTRIBUTION_IDENTITY"

    if [ -n "${APPSTORE_PROVISION_PROFILE:-}" ]; then
        mkdir -p "$APP_PATH/Contents"
        echo "$APPSTORE_PROVISION_PROFILE" | base64 -d > "$APP_PATH/Contents/embedded.provisionprofile"
    fi

    sign() {
        local entitlements="$1" target="$2"
        codesign --force --sign "$APPSTORE_DISTRIBUTION_IDENTITY" \
                 --entitlements "$entitlements" "$target" 2>&1 | sed 's/^/  codesign: /'
    }
    sign apps/VibeVaultApp/VibeVault.entitlements "$APP_PATH/Contents/Helpers/vibevault"
    sign apps/VibeVaultApp/VibeVault.entitlements "$APP_PATH/Contents/Helpers/vibevault-browser-host"
    sign cli/vibevault-mcp/vibevault-mcp.entitlements "$APP_PATH/Contents/MacOS/vibevault-mcp"
    sign apps/VibeVaultApp/VibeVault.entitlements "$APP_PATH/Contents/MacOS/VibeVault"
    sign apps/VibeVaultApp/VibeVault.entitlements "$APP_PATH"
fi

# Wrap the app in a .pkg installer. Apple accepts .pkg for Mac App Store review.
SIGN_ARG=""
if [ -n "${APPSTORE_INSTALLER_IDENTITY:-}" ]; then
    SIGN_ARG="--sign $APPSTORE_INSTALLER_IDENTITY"
fi
productbuild --component "$APP_PATH" /Applications $SIGN_ARG "$PKG_PATH"

echo "==> Validating with App Store Connect..."
xcrun altool --validate-app \
    --type macos \
    --file "$PKG_PATH" \
    --apiKey "$APPSTORE_API_KEY_ID" \
    --apiIssuer "$APPSTORE_API_ISSUER_ID"

echo "==> Uploading to App Store Connect..."
xcrun altool --upload-app \
    --type macos \
    --file "$PKG_PATH" \
    --apiKey "$APPSTORE_API_KEY_ID" \
    --apiIssuer "$APPSTORE_API_ISSUER_ID"

echo "==> Done. Visit App Store Connect > Apps > VibeVault to finish submission."
