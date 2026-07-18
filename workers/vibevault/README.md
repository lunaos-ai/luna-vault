# vibevault.lunaos.ai (Cloudflare Worker)

Luxury marketing site + Lemon Squeezy webhook.

| Path | Behavior |
|------|----------|
| `GET /` | Full product + pricing landing |
| `GET /api/checkout` | Public Team/Studio/Company buy URLs |
| `GET /assets/*` | Product imagery |
| `GET /download` | 302 → DMG |
| `GET /health` | `{ ok: true }` |
| `POST /webhooks/lemonsqueezy` | Sign `VV1` + email via Resend or return key for manual delivery |

## Deploy

```bash
cd workers/vibevault
# Public IDs (vars in wrangler.jsonc or CF dashboard):
#   VIBEVAULT_STORE_ID, VIBEVAULT_PRODUCT_ID
#   VIBEVAULT_VARIANT_TEAM, VIBEVAULT_VARIANT_STUDIO, VIBEVAULT_VARIANT_COMPANY
npx wrangler deploy
```

## Secrets (`VIBEVAULT_` prefix)

```bash
npx wrangler secret put VIBEVAULT_WEBHOOK_SECRET
npx wrangler secret put VIBEVAULT_LICENSE_PRIVATE_KEY
npx wrangler secret put VIBEVAULT_RESEND_API_KEY   # recommended for customer delivery
```

Legacy `LEMONSQUEEZY_WEBHOOK_SECRET` / `RESEND_API_KEY` still accepted.

## Lemon Squeezy webhook

- **Callback:** `https://vibevault.lunaos.ai/webhooks/lemonsqueezy`
- **Events:** `order_created`, `subscription_created`
- If `VIBEVAULT_RESEND_API_KEY` is set, the Worker sends the license email before acknowledging the webhook. If it is not set, the JSON response includes `licenseKey` for manual delivery/testing.
