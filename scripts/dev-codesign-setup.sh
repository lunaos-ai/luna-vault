#!/usr/bin/env bash
# Creates a stable self-signed code-signing identity for VibeVault dev builds.
# Run once. Keychain ACLs ("Always Allow") will then persist across rebuilds.
set -euo pipefail

IDENTITY="VibeVault Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Allow codesign + security to use the signing key WITHOUT a GUI prompt every
# time. The `-T` flags during import add the tools to the key's ACL, but modern
# macOS also requires the key's partition list to list them. That needs the
# login password, so we prompt for it here (interactive, never stored).
set_partition_list() {
  echo "==> Authorizing codesign to use the key without prompts."
  printf "    Enter your macOS login password (not echoed): "
  read -r -s LOGIN_PW; echo
  if security set-key-partition-list -S apple-tool:,apple: -s \
       -k "$LOGIN_PW" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "    Partition list set. codesign will no longer prompt for the key."
  else
    echo "    Could not set partition list (wrong password?). codesign may"
    echo "    prompt once for key access on first build — click \"Always Allow\"."
  fi
}

if security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY"; then
  echo "==> Identity \"$IDENTITY\" already present."
  set_partition_list
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

cat > openssl.cnf <<'CNF'
[req]
distinguished_name = dn
x509_extensions    = v3_ext
prompt             = no
[dn]
CN = VibeVault Dev
[v3_ext]
basicConstraints       = critical, CA:false
keyUsage               = critical, digitalSignature
extendedKeyUsage       = critical, codeSigning
subjectKeyIdentifier   = hash
1.2.840.113635.100.6.1.13 = DER:05:00
CNF

echo "==> Generating self-signed code-signing cert..."
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout key.pem -out cert.pem \
  -days 3650 -config openssl.cnf >/dev/null 2>&1

# `-legacy` forces SHA1-MAC + 3DES PBE so Apple's `security import` can read the
# bundle. OpenSSL 3 defaults to a newer MAC that fails with "MAC verification
# failed". Apple also rejects empty-password p12 MACs, so use a throwaway one.
P12PASS="vibevault"
openssl pkcs12 -export -legacy \
  -inkey key.pem -in cert.pem \
  -out identity.p12 -passout "pass:$P12PASS" -name "$IDENTITY" >/dev/null

echo "==> Importing into login keychain..."
security import identity.p12 \
  -k "$KEYCHAIN" -P "$P12PASS" \
  -T /usr/bin/codesign -T /usr/bin/security \
  >/dev/null

set_partition_list

echo
echo "==> Done. Bundle script will now sign with \"$IDENTITY\"."
echo "    First Keychain prompt on app launch: click \"Always Allow\"."
echo "    It will stick across rebuilds as long as this identity exists."
