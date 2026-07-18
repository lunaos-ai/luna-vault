# Monitoring & observability report

**Updated:** 2026-07-18  
**Status:** Baseline stubs (Solo app has no telemetry by design)

## Native app / CLI / MCP

| Channel | Status |
|---------|--------|
| Product analytics | **None** (CLAUDE Solo policy) |
| Crash reporting | **None** |
| Local audit | `~/Library/Application Support/vibe-vault/audit.db` |

Dogfood: use Audit pane + `vibevault audit` / MCP `get_audit_log` (MCP-allowed secrets only).

## Marketing Worker

| Channel | Status |
|---------|--------|
| Cloudflare Analytics | Enable / export weekly for `/`, `/api/checkout`, `/download` |
| Observability MCP | `needsAuth` — authenticate before `/ll-postlaunch` day-7 |
| Health | Spot-check `GET /` and `/api/checkout` |

## Alerts (recommended)

- Worker 5xx rate &gt; 1% over 15m
- Checkout API non-200
- Lemon Squeezy webhook signature failures (log order id only)

## Privacy

Do not log secret values, license private keys, or provider API tokens.
