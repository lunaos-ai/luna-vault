#!/usr/bin/env bash
# Issue a signed Team license key using VaultCore via the CLI.
# usage:
#   bash scripts/issue-license.sh --email you@co.com --seats 5 --order-id ord_123
# Requires: VIBEVAULT_LICENSE_PRIVATE_KEY or dist/lemonsqueezy/private.b64
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
exec swift run --package-path "$ROOT" vibevault license issue "$@"
