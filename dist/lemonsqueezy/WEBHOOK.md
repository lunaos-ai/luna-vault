# Lemon Squeezy webhook notes

## What the app does

- Opens a **checkout URL** (browser). No Lemon Squeezy API in the app.
- Activates a signed `VV1.…` key offline against the embedded Ed25519 public key.
- Never phones home to verify licenses.

## Store setup

1. Create a **Team** product + variant in Lemon Squeezy.
2. Copy the checkout URL into `dist/lemonsqueezy/config.example.json` (and set `VIBEVAULT_LS_CHECKOUT` or Settings → Team → Checkout URL).
3. Generate keys once: `swift scripts/gen-license-keys.swift`
4. Embed `public.b64` into `LicensePublicKey.base64`. Keep `private.b64` out of git (`VIBEVAULT_LICENSE_PRIVATE_KEY` in CI/secrets).

## Webhook (Cloudflare Worker)

**Callback URL:** `https://vibevault.lunaos.ai/webhooks/lemonsqueezy`

Worker lives in `workers/vibevault/`. See that README for deploy + secrets.

On `order_created` (or `subscription_created`):

1. Worker verifies Lemon Squeezy signature (`X-Signature` HMAC).
2. Signs a `VV1` key with `VIBEVAULT_LICENSE_PRIVATE_KEY`.
3. Emails the key if `RESEND_API_KEY` is set. Without Resend, the webhook response includes `licenseKey` for manual delivery/testing.

Manual issue (local):

```bash
bash scripts/issue-license.sh \
  --email "$EMAIL" \
  --seats 5 \
  --order-id "$ORDER_ID" \
  --product-id "$PRODUCT_ID"
```

On refund / cancel: optionally email the customer; the app cannot revoke offline keys without expiry. Prefer time-limited keys (`--days 365`) for subscriptions.

## Activate (customer)

```bash
vibevault license activate 'VV1.…'
# or paste in Settings → Team license
vibevault license status
```

## Security

- Private key never ships in the app or Homebrew bottle.
- Rotate pubkey by shipping a new app build; old keys stop verifying after rotation.
