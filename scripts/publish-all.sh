#!/usr/bin/env bash
# Publish every Vibe Vault artifact: app/DMG, browser extension zip,
# Cloudflare Worker, marketing download, iCloud copy, and optional GitHub release.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
TAG="${TAG:-}"
DRY_RUN=0
YES="${PUBLISH_ALL_YES:-0}"
NOTARIZE="${NOTARIZE:-0}"
NOTARIZE_DMG="${NOTARIZE_DMG:-0}"
RUN_TESTS="${RUN_TESTS:-1}"
SKIP_BUILD=0
SKIP_RELEASE=0
SKIP_BROWSER_EXTENSION=0
SKIP_WORKER=0
SKIP_WEBSITE=0
SKIP_ICLOUD=0
SKIP_GITHUB=0

BROWSER_EXTENSION_DIR="extensions/browser-vibevault"
BROWSER_EXTENSION_ZIP="${BROWSER_EXTENSION_ZIP:-build/VibeVault-Browser-Importer.zip}"

usage() {
    cat <<'USAGE'
Usage: bash scripts/publish-all.sh [options]

Publishes all Vibe Vault release surfaces:
  - release Swift CLI/MCP/browser-host products
  - VibeVault.app + VibeVault.dmg
  - browser extension zip
  - vibevault Cloudflare Worker
  - LunaOS marketing/download site
  - iCloud DMG copy
  - GitHub release when --tag or TAG is set

Options:
  --dry-run                 Print commands without running them
  --yes                     Do not prompt before publishing
  --config <release|debug>  App bundle config passed to scripts/release.sh
  --tag <vX.Y.Z>            Create GitHub release using scripts/gh-release.sh
  --notarize                Enable app notarization
  --notarize-dmg            Enable DMG notarization too
  --skip-build              Skip release Swift product build/sign step
  --skip-release            Skip app bundle + DMG step
  --skip-browser-extension  Skip browser extension zip
  --skip-worker             Skip Cloudflare Worker deploy
  --skip-website            Skip marketing/download site publish
  --skip-icloud             Skip iCloud DMG publish
  --skip-github             Skip GitHub release
  --skip-tests              Skip pre-publish tests/checks
  -h, --help                Show this help

Environment:
  TAG, CONFIG, NOTARIZE, NOTARIZE_DMG, PUBLISH_ALL_YES
  BROWSER_EXTENSION_ZIP, CF_PAGES_PROJECT, LUNAOS_MARKETING_REPO
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --yes)
            YES=1
            ;;
        --config)
            CONFIG="${2:?--config requires a value}"
            shift
            ;;
        --tag)
            TAG="${2:?--tag requires a value}"
            shift
            ;;
        --notarize)
            NOTARIZE=1
            ;;
        --notarize-dmg)
            NOTARIZE=1
            NOTARIZE_DMG=1
            ;;
        --skip-build)
            SKIP_BUILD=1
            ;;
        --skip-release)
            SKIP_RELEASE=1
            ;;
        --skip-browser-extension)
            SKIP_BROWSER_EXTENSION=1
            ;;
        --skip-worker)
            SKIP_WORKER=1
            ;;
        --skip-website)
            SKIP_WEBSITE=1
            ;;
        --skip-icloud)
            SKIP_ICLOUD=1
            ;;
        --skip-github)
            SKIP_GITHUB=1
            ;;
        --skip-tests)
            RUN_TESTS=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

run() {
    echo "+ $*"
    if [ "$DRY_RUN" != "1" ]; then
        "$@"
    fi
}

run_shell() {
    echo "+ $*"
    if [ "$DRY_RUN" != "1" ]; then
        bash -lc "$*"
    fi
}

require_command() {
    if command -v "$1" >/dev/null 2>&1; then
        return
    fi
    if [ "$DRY_RUN" = "1" ]; then
        echo "warn: required command not found for real publish: $1" >&2
        return
    fi
    echo "error: required command not found: $1" >&2
        exit 127
}

confirm_publish() {
    if [ "$DRY_RUN" = "1" ] || [ "$YES" = "1" ]; then
        return
    fi
    if [ ! -t 0 ]; then
        echo "error: refusing to publish non-interactively without --yes" >&2
        exit 2
    fi
    echo "This will publish external Vibe Vault artifacts."
    echo "Targets: DMG/app, browser extension zip, Worker, website/download, iCloud"
    if [ -n "$TAG" ] && [ "$SKIP_GITHUB" != "1" ]; then
        echo "GitHub release: $TAG"
    fi
    printf "Type 'publish-all' to continue: "
    read -r answer
    if [ "$answer" != "publish-all" ]; then
        echo "aborted"
        exit 1
    fi
}

preflight() {
    require_command swift
    require_command bash
    require_command git
    require_command ditto

    if [ "$SKIP_WORKER" != "1" ]; then
        require_command npx
        if [ ! -d workers/vibevault/node_modules ]; then
            require_command npm
        fi
    fi
    if [ "$SKIP_WEBSITE" != "1" ]; then
        require_command wrangler
    fi
    if [ "$SKIP_GITHUB" != "1" ] && [ -n "$TAG" ]; then
        require_command gh
    fi
}

test_and_check() {
    if [ "$RUN_TESTS" != "1" ]; then
        echo "==> Skipping tests/checks"
        return
    fi

    echo "==> Running pre-publish checks..."
    run swift test --filter VaultServiceTests
    run bash scripts/gtm-check.sh
    if [ -d "$BROWSER_EXTENSION_DIR" ]; then
        run_shell "node_path=\"$(command -v node || true)\"; if [ -n \"\$node_path\" ]; then \"\$node_path\" --check extensions/browser-vibevault/src/background.js && \"\$node_path\" --check extensions/browser-vibevault/src/content.js && \"\$node_path\" --check extensions/browser-vibevault/src/popup.js; else echo 'warn: node not found; skipping extension JS syntax checks'; fi"
    fi
}

build_release_products() {
    if [ "$SKIP_BUILD" = "1" ]; then
        echo "==> Skipping release Swift product build"
        return
    fi

    echo "==> Building signed release CLI products..."
    run bash scripts/build.sh
    run swift build -c release --product vibevault-browser-host
}

build_app_release() {
    if [ "$SKIP_RELEASE" = "1" ]; then
        echo "==> Skipping app/DMG release"
        return
    fi

    echo "==> Building app + DMG..."
    run env NOTARIZE="$NOTARIZE" NOTARIZE_DMG="$NOTARIZE_DMG" bash scripts/release.sh "$CONFIG"
}

package_browser_extension() {
    if [ "$SKIP_BROWSER_EXTENSION" = "1" ]; then
        echo "==> Skipping browser extension package"
        return
    fi
    if [ ! -d "$BROWSER_EXTENSION_DIR" ]; then
        echo "warn: $BROWSER_EXTENSION_DIR missing; skipping browser extension package"
        return
    fi

    echo "==> Packaging browser extension..."
    run env BROWSER_EXTENSION_DIR="$BROWSER_EXTENSION_DIR" BROWSER_EXTENSION_ZIP="$BROWSER_EXTENSION_ZIP" bash scripts/package-browser-extension.sh
}

deploy_worker() {
    if [ "$SKIP_WORKER" = "1" ]; then
        echo "==> Skipping Cloudflare Worker deploy"
        return
    fi

    echo "==> Deploying vibevault.lunaos.ai Worker..."
    if [ ! -d workers/vibevault/node_modules ]; then
        run_shell "cd workers/vibevault && npm ci"
    fi
    run_shell "cd workers/vibevault && npx wrangler deploy"
}

publish_website() {
    if [ "$SKIP_WEBSITE" = "1" ]; then
        echo "==> Skipping website/download publish"
        return
    fi

    echo "==> Publishing LunaOS marketing/download site..."
    run bash scripts/publish-to-website.sh
}

publish_icloud() {
    if [ "$SKIP_ICLOUD" = "1" ]; then
        echo "==> Skipping iCloud publish"
        return
    fi

    echo "==> Publishing DMG to iCloud..."
    run bash scripts/publish-to-icloud.sh
}

publish_github_release() {
    if [ "$SKIP_GITHUB" = "1" ]; then
        echo "==> Skipping GitHub release"
        return
    fi
    if [ -z "$TAG" ]; then
        echo "==> Skipping GitHub release (set TAG or pass --tag)"
        return
    fi

    echo "==> Publishing GitHub release $TAG..."
    run env TAG="$TAG" BROWSER_EXTENSION_ZIP="$BROWSER_EXTENSION_ZIP" bash scripts/gh-release.sh
}

summary() {
    echo ""
    echo "==> Publish-all complete"
    echo "    Worker:  https://vibevault.lunaos.ai/"
    echo "    Download: https://vibevault.lunaos.ai/download"
    if [ -f "$BROWSER_EXTENSION_ZIP" ]; then
        echo "    Browser extension: $BROWSER_EXTENSION_ZIP"
    fi
    if [ -n "$TAG" ] && [ "$SKIP_GITHUB" != "1" ]; then
        echo "    GitHub release: $TAG"
    fi
}

preflight
confirm_publish
test_and_check
build_release_products
build_app_release
package_browser_extension
deploy_worker
publish_website
publish_icloud
publish_github_release
summary
