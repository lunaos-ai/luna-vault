/**
 * vibevault.lunaos.ai — landing + Lemon Squeezy webhook.
 *
 * Public vars (wrangler.jsonc or dashboard):
 *   VIBEVAULT_VARIANT_TEAM | STUDIO | COMPANY  (Lemon Squeezy variant IDs)
 *   VIBEVAULT_PRODUCT_ID, VIBEVAULT_STORE_ID   (optional metadata)
 *
 * Secrets (wrangler secret put — either name works):
 *   VIBEVAULT_WEBHOOK_SECRET  or  LEMONSQUEEZY_WEBHOOK_SECRET
 *   VIBEVAULT_LICENSE_PRIVATE_KEY
 *   VIBEVAULT_RESEND_API_KEY  or  RESEND_API_KEY
 */

export interface Env {
  LANDING_URL: string;
  DOWNLOAD_URL: string;
  DOWNLOAD_DMG_URL?: string;
  FROM_EMAIL: string;
  VARIANT_SEATS_JSON: string;
  VIBEVAULT_VARIANT_TEAM?: string;
  VIBEVAULT_VARIANT_STUDIO?: string;
  VIBEVAULT_VARIANT_COMPANY?: string;
  VIBEVAULT_PRODUCT_ID?: string;
  VIBEVAULT_STORE_ID?: string;
  VIBEVAULT_CHECKOUT_BASE?: string;
  LEMONSQUEEZY_WEBHOOK_SECRET?: string;
  VIBEVAULT_WEBHOOK_SECRET?: string;
  VIBEVAULT_LICENSE_PRIVATE_KEY?: string;
  RESEND_API_KEY?: string;
  VIBEVAULT_RESEND_API_KEY?: string;
  ASSETS: Fetcher;
  [key: string]: unknown;
}

type LsMeta = { event_name?: string };
type LsOrderAttrs = {
  identifier?: string;
  user_email?: string;
  product_id?: number | string;
  variant_id?: number | string;
  quantity?: number;
  first_order_item?: {
    product_id?: number | string;
    variant_id?: number | string;
    quantity?: number;
  };
};

const LICENSE_DAYS = 35;
const LICENSE_EVENTS = new Set([
  "order_created",
  "subscription_created",
  "subscription_updated",
  "subscription_payment_success",
]);

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS" && url.pathname === "/api/checkout") {
      return new Response(null, { status: 204, headers: checkoutCorsHeaders() });
    }

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, host: "vibevault.lunaos.ai" });
    }

    if (request.method === "GET" && url.pathname === "/api/checkout") {
      return json(checkoutConfig(env), 200, {
        "cache-control": "public, max-age=60",
        ...checkoutCorsHeaders(),
      });
    }

    if ((request.method === "GET" || request.method === "HEAD") && url.pathname === "/privacy") {
      return html(privacyPolicyHTML(), 200, {
        "cache-control": "public, max-age=3600",
      });
    }

    if ((request.method === "GET" || request.method === "HEAD") && url.pathname === "/scan") {
      const scanURL = new URL("/scan/index.html", url);
      return env.ASSETS.fetch(new Request(scanURL, request));
    }

    if ((request.method === "GET" || request.method === "HEAD") && url.pathname === "/security") {
      const securityURL = new URL("/security/index.html", url);
      return env.ASSETS.fetch(new Request(securityURL, request));
    }

    if ((request.method === "GET" || request.method === "HEAD") && url.pathname === "/agents") {
      const agentsURL = new URL("/agents/index.html", url);
      return env.ASSETS.fetch(new Request(agentsURL, request));
    }

    if ((request.method === "GET" || request.method === "HEAD") && (url.pathname === "/download" || url.pathname === "/install")) {
      const installURL = new URL("/install/index.html", url);
      return env.ASSETS.fetch(new Request(installURL, request));
    }

    if ((request.method === "GET" || request.method === "HEAD") && url.pathname === "/downloads/VibeVault.dmg") {
      return Response.redirect(downloadDmgURL(env), 302);
    }

    if (request.method === "POST" && url.pathname === "/webhooks/lemonsqueezy") {
      return handleLemonWebhook(request, env, ctx);
    }

    return env.ASSETS.fetch(request);
  },
};

function checkoutConfig(env: Env) {
  const base =
    pick(env, "VIBEVAULT_CHECKOUT_BASE", "vibevault_checkout_base") ||
    "https://finsavvy.lemonsqueezy.com/checkout/buy";
  const team = pick(env, "VIBEVAULT_VARIANT_TEAM", "vibevault_variant_team");
  const studio = pick(env, "VIBEVAULT_VARIANT_STUDIO", "vibevault_variant_studio");
  const company = pick(env, "VIBEVAULT_VARIANT_COMPANY", "vibevault_variant_company");
  const buy = (id?: string) => (id ? `${base.replace(/\/$/, "")}/${id}` : null);
  return {
    store_id: pick(env, "VIBEVAULT_STORE_ID", "vibevault_store_id") || null,
    product_id: pick(env, "VIBEVAULT_PRODUCT_ID", "vibevault_product_id") || null,
    team: buy(team),
    studio: buy(studio),
    company: buy(company),
    seats: { team: 5, studio: 20, company: 100 },
    configured: Boolean(team && studio && company),
  };
}

function downloadDmgURL(env: Env): string {
  return pick(env, "DOWNLOAD_DMG_URL", "download_dmg_url") || "https://lunaos.ai/downloads/VibeVault.dmg";
}

function checkoutCorsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET, OPTIONS",
    "access-control-allow-headers": "content-type",
  };
}

function privacyPolicyHTML(): string {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Vibe Vault Importer Privacy Policy</title>
  <style>
    :root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #111827; background: #f8fafc; }
    body { margin: 0; }
    main { max-width: 760px; margin: 0 auto; padding: 64px 24px 80px; }
    h1 { font-size: 36px; line-height: 1.1; margin: 0 0 12px; }
    h2 { font-size: 18px; margin: 32px 0 10px; }
    p, li { font-size: 16px; line-height: 1.65; color: #334155; }
    ul { padding-left: 22px; }
    a { color: #0f766e; }
    .updated { color: #64748b; margin-bottom: 32px; }
  </style>
</head>
<body>
  <main>
    <h1>Vibe Vault Importer Privacy Policy</h1>
    <p class="updated">Last updated: July 19, 2026</p>
    <p>Vibe Vault Importer does not sell or share user data.</p>
    <p>The extension does not use chrome.storage, localStorage, IndexedDB, analytics, telemetry, or remote logging.</p>

    <h2>How API keys are handled</h2>
    <p>API key values are kept in page memory only long enough to show the save panel. For providers that expose keys through a copy button, the extension may read the clipboard immediately after that user click so it can show the same save panel. A raw key is sent to the local native messaging host only after the user clicks Save. The native host writes the key to the local encrypted Vibe Vault store.</p>
    <p>The extension requests access only to supported provider dashboard domains. It does not run on arbitrary websites.</p>

    <h2>Data handled</h2>
    <ul>
      <li>API key values visible on supported provider dashboards or copied from provider copy buttons</li>
      <li>Suggested secret names entered by the user</li>
      <li>Current provider page URL, stored only as local Vibe Vault notes for source context</li>
    </ul>

    <h2>Data not collected</h2>
    <ul>
      <li>Browsing history</li>
      <li>Account profile data</li>
      <li>Payment data</li>
      <li>Personal communications</li>
      <li>Analytics or usage telemetry</li>
    </ul>

    <h2>Contact</h2>
    <p>For support, visit <a href="https://vibevault.lunaos.ai/">vibevault.lunaos.ai</a>.</p>
  </main>
</body>
</html>`;
}

function pick(env: Env, ...keys: string[]): string | undefined {
  for (const k of keys) {
    const v = env[k];
    if (typeof v === "string" && v.trim() && !v.includes("REPLACE")) return v.trim();
  }
  return undefined;
}

async function handleLemonWebhook(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const secret = pick(env, "VIBEVAULT_WEBHOOK_SECRET", "LEMONSQUEEZY_WEBHOOK_SECRET", "vibevault_webhook_secret");
  if (!secret) return json({ error: "webhook_secret_missing" }, 500);

  const raw = await request.text();
  const sig = request.headers.get("X-Signature") || "";
  if (!(await verifyLemonSignature(raw, sig, secret))) {
    return json({ error: "invalid_signature" }, 401);
  }

  let body: { meta?: LsMeta; data?: { id?: string; attributes?: LsOrderAttrs } };
  try {
    body = JSON.parse(raw);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const event = body.meta?.event_name || "";
  if (!LICENSE_EVENTS.has(event)) {
    return json({ ok: true, ignored: event });
  }

  const attrs = body.data?.attributes || {};
  const email = (attrs.user_email || "").trim().toLowerCase();
  const orderId = String(attrs.identifier || body.data?.id || "");
  const item = attrs.first_order_item || {};
  const productId = String(
    item.product_id || attrs.product_id || pick(env, "VIBEVAULT_PRODUCT_ID", "vibevault_product_id") || "team"
  );
  const variantId = String(item.variant_id || attrs.variant_id || "");
  const seats = seatsForVariant(env, variantId, item.quantity || attrs.quantity);
  const priv = pick(env, "VIBEVAULT_LICENSE_PRIVATE_KEY", "vibevault_license_private_key");

  if (!email || !orderId) return json({ error: "missing_email_or_order" }, 400);
  if (!priv) return json({ error: "license_private_key_missing" }, 500);

  let licenseKey: string;
  try {
    licenseKey = await issueLicense({
      email,
      seats,
      orderId,
      productId,
      privateKeyB64: priv,
      days: LICENSE_DAYS,
    });
  } catch (e) {
    console.error(JSON.stringify({ err: "sign_failed", message: String(e) }));
    return json({ error: "sign_failed" }, 500);
  }

  const resend = pick(env, "VIBEVAULT_RESEND_API_KEY", "RESEND_API_KEY", "vibevault_resend_api_key");
  if (resend) {
    try {
      await emailLicense(env, resend, email, licenseKey, seats, LICENSE_DAYS);
    } catch (e) {
      console.error(JSON.stringify({ err: "email_failed", message: String(e) }));
      return json({ error: "email_failed" }, 502);
    }
  }

  const response: Record<string, unknown> = { ok: true, emailed: Boolean(resend), licenseDays: LICENSE_DAYS };
  if (!resend) response.licenseKey = licenseKey;

  console.log(JSON.stringify({
    event,
    email,
    orderId,
    variantId,
    seats,
    issued: true,
    licenseDays: LICENSE_DAYS,
    emailed: Boolean(resend),
    manualDelivery: !resend,
  }));

  return json(response);
}

function seatsForVariant(env: Env, variantId: string, quantity?: number): number {
  const team = pick(env, "VIBEVAULT_VARIANT_TEAM", "vibevault_variant_team");
  const studio = pick(env, "VIBEVAULT_VARIANT_STUDIO", "vibevault_variant_studio");
  const company = pick(env, "VIBEVAULT_VARIANT_COMPANY", "vibevault_variant_company");
  if (variantId && team && variantId === team) return 5;
  if (variantId && studio && variantId === studio) return 20;
  if (variantId && company && variantId === company) return 100;
  try {
    const map = JSON.parse(String(env.VARIANT_SEATS_JSON || "{}")) as Record<string, number>;
    if (variantId && Object.prototype.hasOwnProperty.call(map, variantId)) return Number(map[variantId]);
  } catch {
    /* ignore */
  }
  if (quantity && quantity > 1) return quantity;
  return 5;
}

async function verifyLemonSignature(raw: string, signature: string, secret: string): Promise<boolean> {
  if (!signature) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw));
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return timingSafeEqual(hex, signature.toLowerCase());
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

async function issueLicense(opts: {
  email: string;
  seats: number;
  orderId: string;
  productId: string;
  privateKeyB64: string;
  days?: number;
}): Promise<string> {
  if (opts.seats <= 0) throw new Error("seats must be positive");
  const issuedAt = new Date();
  const tier =
    opts.seats >= 100 ? "company" : opts.seats >= 20 ? "studio" : "team";
  const payload: Record<string, unknown> = {
    email: opts.email,
    issuedAt: issuedAt.toISOString().replace(/\.\d{3}Z$/, "Z"),
    orderId: opts.orderId,
    productId: opts.productId,
    seats: opts.seats,
    tier,
  };
  if (opts.days) {
    const exp = new Date(issuedAt.getTime() + opts.days * 86_400_000);
    payload.expiresAt = exp.toISOString().replace(/\.\d{3}Z$/, "Z");
  }
  const jsonStr = JSON.stringify(payload, Object.keys(payload).sort());
  const bytes = new TextEncoder().encode(jsonStr);
  const priv = base64Decode(opts.privateKeyB64);
  if (priv.byteLength !== 32) throw new Error("private key must be 32 bytes");
  const key = await crypto.subtle.importKey("pkcs8", ed25519Pkcs8FromSeed(priv), { name: "Ed25519" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("Ed25519", key, bytes));
  return `VV1.${b64url(bytes)}.${b64url(sig)}`;
}

function ed25519Pkcs8FromSeed(seed: Uint8Array): Uint8Array {
  const prefix = new Uint8Array([
    0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06,
    0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
  ]);
  const out = new Uint8Array(prefix.length + seed.length);
  out.set(prefix);
  out.set(seed, prefix.length);
  return out;
}

async function emailLicense(
  env: Env,
  apiKey: string,
  to: string,
  licenseKey: string,
  seats: number,
  days: number
): Promise<void> {
  const from = (typeof env.FROM_EMAIL === "string" && env.FROM_EMAIL) || "licenses@lunaos.ai";
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: "Your Vibe Vault Team license",
      text: [
        "Thanks for purchasing Vibe Vault.",
        "",
        `Seats: ${seats}`,
        `Valid for: ${days} days`,
        "A fresh license key is issued on renewal.",
        "",
        "Activate with:",
        `  vibevault license activate '${licenseKey}'`,
        "",
        "Or paste the key in Vibe Vault → Settings → Team license.",
        "",
        "Verification is offline. We never phone home.",
        "",
        "— LunaOS",
      ].join("\n"),
    }),
  });
  if (!res.ok) throw new Error(`resend returned ${res.status}`);
}

function b64url(data: Uint8Array): string {
  const s = btoa(String.fromCharCode(...data));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64Decode(s: string): Uint8Array {
  const bin = atob(s.trim());
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function json(data: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...headers },
  });
}

function html(data: string, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(data, {
    status,
    headers: { "content-type": "text/html; charset=utf-8", ...headers },
  });
}
