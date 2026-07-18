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
  first_order_item?: {
    product_id?: number;
    variant_id?: number;
    quantity?: number;
  };
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, host: "vibevault.lunaos.ai" });
    }

    if (request.method === "GET" && url.pathname === "/api/checkout") {
      return json(checkoutConfig(env), 200, {
        "cache-control": "public, max-age=60",
      });
    }

    if (request.method === "GET" && url.pathname === "/download") {
      return Response.redirect(env.DOWNLOAD_URL || "https://lunaos.ai/download/vibevault", 302);
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
    "https://lunaos.lemonsqueezy.com/checkout/buy";
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
  if (event !== "order_created" && event !== "subscription_created") {
    return json({ ok: true, ignored: event });
  }

  const attrs = body.data?.attributes || {};
  const email = (attrs.user_email || "").trim().toLowerCase();
  const orderId = String(attrs.identifier || body.data?.id || "");
  const item = attrs.first_order_item || {};
  const productId = String(
    item.product_id || pick(env, "VIBEVAULT_PRODUCT_ID", "vibevault_product_id") || "team"
  );
  const variantId = String(item.variant_id || "");
  const seats = seatsForVariant(env, variantId, item.quantity);
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
      days: event === "subscription_created" ? 365 : undefined,
    });
  } catch (e) {
    console.error(JSON.stringify({ err: "sign_failed", message: String(e) }));
    return json({ error: "sign_failed" }, 500);
  }

  console.log(JSON.stringify({ event, email, orderId, variantId, seats, issued: true }));

  const resend = pick(env, "VIBEVAULT_RESEND_API_KEY", "RESEND_API_KEY", "vibevault_resend_api_key");
  if (resend) ctx.waitUntil(emailLicense(env, resend, email, licenseKey, seats));

  return json({ ok: true, emailed: Boolean(resend) });
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
    if (variantId && map[variantId]) return Number(map[variantId]);
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
  const issuedAt = new Date();
  const payload: Record<string, unknown> = {
    email: opts.email,
    issuedAt: issuedAt.toISOString().replace(/\.\d{3}Z$/, "Z"),
    orderId: opts.orderId,
    productId: opts.productId,
    seats: opts.seats,
    tier: "team",
  };
  if (opts.days) {
    const exp = new Date(issuedAt.getTime() + opts.days * 86_400_000);
    payload.expiresAt = exp.toISOString().replace(/\.\d{3}Z$/, "Z");
  }
  const jsonStr = JSON.stringify(payload, Object.keys(payload).sort());
  const bytes = new TextEncoder().encode(jsonStr);
  const priv = base64Decode(opts.privateKeyB64);
  if (priv.byteLength !== 32) throw new Error("private key must be 32 bytes");
  const key = await crypto.subtle.importKey("raw", priv, { name: "Ed25519" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("Ed25519", key, bytes));
  return `VV1.${b64url(bytes)}.${b64url(sig)}`;
}

async function emailLicense(
  env: Env,
  apiKey: string,
  to: string,
  licenseKey: string,
  seats: number
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
  if (!res.ok) console.error(JSON.stringify({ err: "email_failed", status: res.status }));
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
