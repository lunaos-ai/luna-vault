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

type ComparisonLink = { label: string; href: string };
type ComparisonRow = { area: string; incumbent: string; vibevault: string };
type ComparisonPage = {
  slug: string;
  competitor: string;
  metaTitle: string;
  metaDescription: string;
  eyebrow: string;
  h1: string;
  lead: string;
  quickTake: string;
  incumbentBestFor: string[];
  vibeBestFor: string[];
  rows: ComparisonRow[];
  vibeWins: string[];
  incumbentWins: string[];
  migration: string[];
  sources: ComparisonLink[];
};

const COMPARISON_UPDATED = "July 23, 2026";
const CLEAN_STATIC_ROUTES: Record<string, string> = {
  "/scan": "/scan/index.html",
  "/security": "/security/index.html",
  "/agents": "/agents/index.html",
  "/download": "/install/index.html",
  "/install": "/install/index.html",
};

const COMPARISON_ORDER = [
  "vs-env-files",
  "vs-1password",
  "vs-bitwarden-mcp",
  "vs-doppler",
  "vs-infisical",
] as const;

const COMPARISON_PAGES: Record<string, ComparisonPage> = {
  "vs-env-files": {
    slug: "vs-env-files",
    competitor: ".env files",
    metaTitle: "Vibe Vault vs .env files | AI agent secret management",
    metaDescription: "Compare Vibe Vault with .env files for AI coding agents, local development, repo scanning, secret injection, and audit.",
    eyebrow: "Vibe Vault vs .env files",
    h1: "Stop treating .env files as the security boundary for AI coding.",
    lead: ".env files are convenient for examples and local defaults. They become risky when real API keys sit inside repos that AI agents can inspect, edit, commit, or summarize.",
    quickTake: "Keep .env.example for names and safe defaults. Use Vibe Vault when a real credential must stay outside the repo while Cursor, Claude Code, Codex, Gemini, or a terminal agent still needs scoped runtime access.",
    incumbentBestFor: [
      "Small prototypes with no real secrets.",
      "Documenting required environment variable names.",
      "Local defaults that are safe to commit.",
    ],
    vibeBestFor: [
      "Real API keys used by AI coding agents.",
      "Multi-repo projects where env files drift.",
      "Teams that need scanner results, git guards, and an access audit.",
    ],
    rows: [
      { area: "Source of truth", incumbent: "A file inside or next to the repo.", vibevault: "A local encrypted macOS vault outside the repo." },
      { area: "Agent access", incumbent: "The agent may read the whole file if it can inspect the workspace.", vibevault: "Agents request named secrets through CLI, MCP, or scoped command injection." },
      { area: "Leak prevention", incumbent: "Depends on ignore files and discipline.", vibevault: "Adds repo scanning, git guard setup, and missing-secret import guidance." },
      { area: "Audit", incumbent: "No built-in record of which agent used which value.", vibevault: "Records metadata for agent, project, secret name, result, and time." },
      { area: "Sharing", incumbent: "Copied files, messages, or ad hoc onboarding.", vibevault: "Local-first Solo workflow with explicit provider sync and paid team rollout path." },
    ],
    vibeWins: [
      "A developer can run vibevault scan before an agent session and see required names without exposing values.",
      "Secrets can be injected only for the command or agent session that needs them.",
      "The same workflow covers add, generate, import, cursor prepare, guard, sync, and audit.",
    ],
    incumbentWins: [
      ".env.example remains the right place to document safe defaults.",
      "A temporary throwaway prototype may not need a vault.",
      "Language frameworks already know how to read env names once values are injected.",
    ],
    migration: [
      "Run vibevault scan in a real repo.",
      "Move one real API key from .env into Vibe Vault.",
      "Keep .env.example with names only.",
      "Run vibevault cursor prepare or vibevault run for scoped agent access.",
      "Install the git guard so future secret files are caught before commit.",
    ],
    sources: [
      { label: "GitGuardian State of Secrets Sprawl 2026", href: "https://blog.gitguardian.com/the-state-of-secrets-sprawl-2026/" },
      { label: "Lakera Claude settings scan", href: "https://www.lakera.ai/blog/your-ai-coding-assistant-just-shipped-your-api-keys" },
    ],
  },
  "vs-1password": {
    slug: "vs-1password",
    competitor: "1Password",
    metaTitle: "Vibe Vault vs 1Password | AI coding agent credentials",
    metaDescription: "Compare Vibe Vault and 1Password for AI coding agents, local repo workflows, browser delegation, vault storage, and audit.",
    eyebrow: "Vibe Vault vs 1Password",
    h1: "Use 1Password as a human vault. Use Vibe Vault as the local boundary for AI coding.",
    lead: "1Password is a mature password manager and is moving quickly into AI-agent credential access. Vibe Vault is narrower: it focuses on API keys, repos, local agents, MCP setup, provider import, and per-agent audit on macOS.",
    quickTake: "They can coexist. Keep 1Password for human passwords and browser logins. Add Vibe Vault when a coding agent needs named API-key access without a copied .env file or pasted secret.",
    incumbentBestFor: [
      "Primary password management for people and teams.",
      "Browser login and one-time-code workflows.",
      "Broad enterprise password governance.",
    ],
    vibeBestFor: [
      "Local macOS AI coding sessions with API keys.",
      "Replacing plaintext .env workflows in repos.",
      "Scanner, MCP, Cursor rules, provider import, and agent access audit.",
    ],
    rows: [
      { area: "Primary job", incumbent: "Store and govern credentials for people, browsers, and teams.", vibevault: "Gate local API-key access for AI coding agents." },
      { area: "AI surface", incumbent: "Claude/browser delegation and a broader trusted access layer.", vibevault: "Cursor, Claude Code, Codex, Gemini CLI, VS Code, and terminal agent workflows." },
      { area: "Repo workflow", incumbent: "Not centered on scanning repo env requirements before coding.", vibevault: "Runs scan, guard install, cursor prepare, MCP setup, and audit from the repo." },
      { area: "Solo setup", incumbent: "Account-backed password manager workflow.", vibevault: "Local-first Solo use with no Vibe Vault cloud account." },
      { area: "Best replacement", incumbent: "Replaces scattered human password storage.", vibevault: "Replaces raw .env files and prompt-pasted API keys for agent work." },
    ],
    vibeWins: [
      "Purpose-built onboarding from repo scan to first protected agent read.",
      "Per-agent and per-project audit language maps directly to coding workflows.",
      "Browser importer catches newly generated provider API keys and stores them locally.",
    ],
    incumbentWins: [
      "Much broader password manager maturity and platform support.",
      "Strong browser credential autofill and Claude browser delegation story.",
      "Enterprise password management trust, policy, and admin depth.",
    ],
    migration: [
      "Keep 1Password as the human credential source where it already works.",
      "Use Vibe Vault for API keys that agents need during local coding.",
      "Run vibevault scan to identify which keys a repo expects.",
      "Import or generate those keys in Vibe Vault.",
      "Prepare the agent runtime and verify the audit trail after one read.",
    ],
    sources: [
      { label: "1Password for Claude", href: "https://1password.com/blog/1password-for-claude" },
      { label: "1Password developer docs", href: "https://www.1password.dev/" },
    ],
  },
  "vs-bitwarden-mcp": {
    slug: "vs-bitwarden-mcp",
    competitor: "Bitwarden MCP and Agent Access SDK",
    metaTitle: "Vibe Vault vs Bitwarden MCP | AI agent credential access",
    metaDescription: "Compare Vibe Vault with Bitwarden MCP and Agent Access SDK for local-first AI agent credential workflows.",
    eyebrow: "Vibe Vault vs Bitwarden MCP",
    h1: "Bitwarden validates local-first agent access. Vibe Vault packages the coding workflow around it.",
    lead: "Bitwarden's MCP server and Agent Access SDK are important moves toward secure agent credential access. Vibe Vault competes on the day-one developer flow: scan a repo, move secrets out of .env, prepare Cursor or MCP, import provider keys, and audit local agent reads.",
    quickTake: "Bitwarden is stronger if your team already standardizes on Bitwarden as the password vault. Vibe Vault is sharper when the immediate job is protecting AI coding agents on a Mac without redesigning team-wide password management.",
    incumbentBestFor: [
      "Teams already committed to Bitwarden.",
      "Password-vault-backed MCP experiments.",
      "SDK exploration for future agent credential standards.",
    ],
    vibeBestFor: [
      "A packaged macOS app, CLI, MCP server, and browser importer.",
      "Repo scanning and .env migration before agent work starts.",
      "Solo developers who want local-first setup with no cloud account.",
    ],
    rows: [
      { area: "Product shape", incumbent: "Password manager plus MCP server and SDK capabilities.", vibevault: "Dedicated AI coding credential tool for macOS." },
      { area: "Setup focus", incumbent: "Connect an agent to a password vault.", vibevault: "Protect a repo with scan, guard, cursor prepare, import, sync, and audit." },
      { area: "Agent access", incumbent: "MCP and SDK patterns for secure credential use.", vibevault: "CLI, MCP, scoped run injection, local approval, and project-aware audit." },
      { area: "Browser workflow", incumbent: "Agent Access browser extension was described as coming soon in public materials.", vibevault: "Chrome Web Store importer is live for capturing newly generated provider keys." },
      { area: "Category role", incumbent: "Broad open credential-access standard and password-manager ecosystem.", vibevault: "Narrow productized wedge for local AI coding." },
    ],
    vibeWins: [
      "Clear install-to-first-agent-read path for macOS developers.",
      "Scanner and git guard make repo hygiene part of the workflow.",
      "Provider import and provider sync are included in the same local tool.",
    ],
    incumbentWins: [
      "Broader password manager installed base and cross-platform reach.",
      "Zero-knowledge password-vault foundation for existing Bitwarden teams.",
      "Open SDK direction may become an important standard layer.",
    ],
    migration: [
      "If Bitwarden is your human vault, keep it.",
      "Use Vibe Vault for repo-local API keys that agents need during coding.",
      "Run vibevault agents prepare so Codex, Claude, Gemini, Cursor, and local agents prefer vault access over new plaintext env files.",
      "Use the Chrome importer when generating a new provider API key.",
      "Review the local audit after the agent session.",
    ],
    sources: [
      { label: "Bitwarden MCP server", href: "https://bitwarden.com/blog/bitwarden-mcp-server/" },
      { label: "Bitwarden Agent Access SDK", href: "https://bitwarden.com/blog/introducing-agent-access-sdk/" },
    ],
  },
  "vs-doppler": {
    slug: "vs-doppler",
    competitor: "Doppler",
    metaTitle: "Vibe Vault vs Doppler | Secrets for AI agents",
    metaDescription: "Compare Vibe Vault and Doppler for AI agent secrets, local development, centralized secrets management, MCP, and developer workflows.",
    eyebrow: "Vibe Vault vs Doppler",
    h1: "Doppler centralizes secrets for teams. Vibe Vault protects local agent access before deployment.",
    lead: "Doppler is a centralized secrets platform for humans, AI agents, MCP servers, and workflows. Vibe Vault starts on the developer machine, where AI coding agents inspect repos, request API keys, and risk turning local secrets into committed files.",
    quickTake: "Use Doppler when you want centralized cloud secrets management across teams and environments. Use Vibe Vault when you want a local macOS credential boundary for AI coding agents, with optional explicit sync to deployment providers.",
    incumbentBestFor: [
      "Centralized secrets management across environments.",
      "Team-wide cloud secrets operations.",
      "MCP access connected to an existing secrets platform.",
    ],
    vibeBestFor: [
      "Local AI coding sessions where the risk starts before deploy.",
      "No-account Solo setup and encrypted local storage.",
      "Repo scan, browser import, local approval, and agent audit in one tool.",
    ],
    rows: [
      { area: "Architecture", incumbent: "Centralized secrets platform.", vibevault: "Local-first macOS vault with explicit provider sync." },
      { area: "Primary user", incumbent: "Teams managing apps, environments, workflows, and non-human identities.", vibevault: "Developers using AI coding agents on local repos." },
      { area: "Agent story", incumbent: "MCP server and agent-scoped access for centralized secrets.", vibevault: "MCP plus repo scanner, Cursor preparation, git guard, and local audit." },
      { area: "First action", incumbent: "Create or connect a centralized project/environment.", vibevault: "Run vibevault scan in the repo and move one key out of .env." },
      { area: "Cloud stance", incumbent: "Cloud platform is the control plane.", vibevault: "Solo vault works locally; cloud/provider sync is explicit and paid team licensing is separate from vault storage." },
    ],
    vibeWins: [
      "A smaller trust surface for solo AI-coding workflows.",
      "Local scanner and guardrails meet the agent where it edits files.",
      "Provider import catches newly generated API keys directly from supported browser pages.",
    ],
    incumbentWins: [
      "Mature centralized team secrets management.",
      "Multi-environment operations and compliance posture.",
      "Better fit when secrets must be governed from a cloud control plane.",
    ],
    migration: [
      "Use Vibe Vault first to remove secrets from local .env files.",
      "Prepare the local agent workflow and verify audited reads.",
      "Push selected deployment values to providers only when needed.",
      "Adopt Doppler or another centralized platform when the team needs cloud control-plane workflows.",
    ],
    sources: [
      { label: "Doppler homepage", href: "https://www.doppler.com/" },
      { label: "Doppler MCP documentation", href: "https://docs.doppler.com/" },
    ],
  },
  "vs-infisical": {
    slug: "vs-infisical",
    competitor: "Infisical",
    metaTitle: "Vibe Vault vs Infisical | Developer and AI agent secrets",
    metaDescription: "Compare Vibe Vault and Infisical for developer secrets, AI agents, privileged access, local-first workflows, and repo scanning.",
    eyebrow: "Vibe Vault vs Infisical",
    h1: "Infisical is a broad security platform. Vibe Vault is the local AI-coding wedge.",
    lead: "Infisical positions around application secrets, certificates, privileged access, cloud, on-prem, and AI infrastructure. Vibe Vault intentionally does less: it protects API keys on a Mac during AI-assisted development and keeps the workflow fast enough for daily agent use.",
    quickTake: "Use Infisical when you need a team security platform across infrastructure. Use Vibe Vault when the immediate risk is agents reading, writing, or committing local secrets while coding.",
    incumbentBestFor: [
      "Secrets, certificates, and privileged access across infrastructure.",
      "Central team administration and audit.",
      "Cloud or self-hosted platform rollout.",
    ],
    vibeBestFor: [
      "Single-developer and small-team AI coding workflows.",
      "Mac-local encrypted storage with no Solo cloud account.",
      "Repo scan, MCP, Cursor rules, browser import, provider sync, and audit.",
    ],
    rows: [
      { area: "Scope", incumbent: "All-in-one security infrastructure for developers and agents.", vibevault: "Focused local credential boundary for AI coding agents." },
      { area: "Deployment model", incumbent: "Platform across cloud, on-prem, and AI infrastructure.", vibevault: "macOS-first app, CLI, MCP server, and browser importer." },
      { area: "First value", incumbent: "Centralize and audit application secrets across teams.", vibevault: "Remove real keys from .env and give agents named local access." },
      { area: "Agent workflow", incumbent: "Part of a broader identity/security platform.", vibevault: "Productized agent setup with scanner, guard, cursor prepare, and audit." },
      { area: "Buyer fit", incumbent: "Security/platform teams.", vibevault: "AI-native solo developers, startup leads, and agencies using local coding agents." },
    ],
    vibeWins: [
      "Less platform overhead for a solo or small team starting with one repo.",
      "Agent-specific onboarding and browser key import are front-and-center.",
      "Local-first trust story is easier to explain for developers skeptical of cloud vaults.",
    ],
    incumbentWins: [
      "Broader enterprise and infrastructure coverage.",
      "More complete platform scope for certificates, privileged access, and centralized governance.",
      "Better fit when security teams already need a shared control plane.",
    ],
    migration: [
      "Start by protecting the local agent workflow with Vibe Vault.",
      "Keep .env.example for safe documentation only.",
      "Use provider sync for selected deployment targets.",
      "Move to a broader platform when team governance, certs, or privileged access become the main constraint.",
    ],
    sources: [
      { label: "Infisical homepage", href: "https://infisical.com/" },
    ],
  },
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const path = cleanPath(url.pathname);

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

    if (request.method === "GET" || request.method === "HEAD") {
      if (path === "/alternatives") {
        return html(alternativesHTML(), 200, {
          "cache-control": "public, max-age=3600",
        });
      }

      const comparison = COMPARISON_PAGES[path.slice(1)];
      if (comparison) {
        return html(comparisonHTML(comparison), 200, {
          "cache-control": "public, max-age=3600",
        });
      }

      const assetPath = CLEAN_STATIC_ROUTES[path];
      if (assetPath) {
        const staticURL = new URL(assetPath, url);
        return env.ASSETS.fetch(new Request(staticURL, request));
      }
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

function cleanPath(path: string): string {
  if (path.length > 1 && path.endsWith("/")) return path.slice(0, -1);
  return path;
}

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

function alternativesHTML(): string {
  const cards = COMPARISON_ORDER.map((slug) => {
    const page = COMPARISON_PAGES[slug];
    return `<a class="alt-card" href="/${page.slug}">
      <span>${escapeHTML(page.eyebrow)}</span>
      <strong>${escapeHTML(page.competitor)}</strong>
      <p>${escapeHTML(page.quickTake)}</p>
    </a>`;
  }).join("");

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Vibe Vault Alternatives | Compare AI agent credential workflows</title>
  <meta name="description" content="Compare Vibe Vault with .env files, 1Password, Bitwarden MCP, Doppler, and Infisical for AI coding agent credential workflows.">
  <link rel="canonical" href="https://vibevault.lunaos.ai/alternatives">
  <link rel="icon" href="/assets/vibe-vaulta-app-icon.png" type="image/png">
  ${comparisonStyles()}
</head>
<body>
  ${comparisonNav()}
  <main>
    <section class="hero">
      <div class="shell hero-grid">
        <div>
          <p class="eyebrow">Alternatives</p>
          <h1>Compare Vibe Vault with the tools developers already use for secrets.</h1>
          <p class="lede">The category is moving fast. The useful question is not whether existing vaults are good - many are. It is which tool creates the right boundary when AI coding agents touch repos, terminals, provider dashboards, and local config.</p>
          <div class="cta-row">
            <a class="btn primary" href="/download">Install Vibe Vault</a>
            <a class="btn secondary" href="/scan">Run the scanner</a>
          </div>
        </div>
        <aside class="quick-card">
          <span>Positioning</span>
          <strong>Local credential boundary for AI coding agents on macOS.</strong>
          <p>Use Vibe Vault to scan a repo, move secrets out of plaintext files, prepare MCP/Cursor, import newly generated provider keys, and audit agent access.</p>
        </aside>
      </div>
    </section>

    <section>
      <div class="shell">
        <div class="section-head">
          <div>
            <p class="eyebrow">Comparison pages</p>
            <h2>Choose by workflow, not by category label.</h2>
          </div>
          <p class="section-copy">These pages are based on public materials checked on ${COMPARISON_UPDATED}. They are written to clarify fit, not to claim that one tool replaces every feature of another.</p>
        </div>
        <div class="alt-grid">${cards}</div>
      </div>
    </section>

    <section>
      <div class="shell">
        <div class="section-head">
          <div>
            <p class="eyebrow">Watch list</p>
            <h2>The market is converging on agent credential access.</h2>
          </div>
          <p class="section-copy">1Password, Bitwarden, Doppler, Infisical, Keeper, HashiCorp Vault, and Aembit are all moving around AI-agent access, MCP, identity, or non-human credentials. That validates the problem while making Vibe Vault's local developer wedge more important to state clearly.</p>
        </div>
      </div>
    </section>
  </main>
  ${comparisonFooter()}
</body>
</html>`;
}

function comparisonHTML(page: ComparisonPage): string {
  const related = COMPARISON_ORDER
    .filter((slug) => slug !== page.slug)
    .map((slug) => {
      const relatedPage = COMPARISON_PAGES[slug];
      return `<a href="/${relatedPage.slug}">${escapeHTML(relatedPage.competitor)}</a>`;
    })
    .join("");

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHTML(page.metaTitle)}</title>
  <meta name="description" content="${escapeAttr(page.metaDescription)}">
  <link rel="canonical" href="https://vibevault.lunaos.ai/${escapeAttr(page.slug)}">
  <link rel="icon" href="/assets/vibe-vaulta-app-icon.png" type="image/png">
  ${comparisonStyles()}
</head>
<body>
  ${comparisonNav()}
  <main>
    <section class="hero">
      <div class="shell hero-grid">
        <div>
          <p class="eyebrow">${escapeHTML(page.eyebrow)}</p>
          <h1>${escapeHTML(page.h1)}</h1>
          <p class="lede">${escapeHTML(page.lead)}</p>
          <div class="cta-row">
            <a class="btn primary" href="/download">Install Vibe Vault</a>
            <a class="btn secondary" href="/alternatives">All comparisons</a>
          </div>
        </div>
        <aside class="quick-card">
          <span>Quick take</span>
          <strong>${escapeHTML(page.competitor)}</strong>
          <p>${escapeHTML(page.quickTake)}</p>
        </aside>
      </div>
    </section>

    <section>
      <div class="shell split">
        <article class="panel">
          <span>Use ${escapeHTML(page.competitor)} when</span>
          ${listHTML(page.incumbentBestFor)}
        </article>
        <article class="panel accent">
          <span>Use Vibe Vault when</span>
          ${listHTML(page.vibeBestFor)}
        </article>
      </div>
    </section>

    <section>
      <div class="shell">
        <div class="section-head">
          <div>
            <p class="eyebrow">Feature fit</p>
            <h2>What changes in the day-to-day workflow.</h2>
          </div>
          <p class="section-copy">The practical distinction is where access is controlled: a broad password or secrets platform, a plaintext repo file, or a local boundary designed for coding agents.</p>
        </div>
        <div class="table-wrap">
          <table>
            <thead>
              <tr><th>Area</th><th>${escapeHTML(page.competitor)}</th><th>Vibe Vault</th></tr>
            </thead>
            <tbody>${page.rows.map((row) => `<tr><td>${escapeHTML(row.area)}</td><td>${escapeHTML(row.incumbent)}</td><td>${escapeHTML(row.vibevault)}</td></tr>`).join("")}</tbody>
          </table>
        </div>
      </div>
    </section>

    <section>
      <div class="shell split">
        <article class="panel">
          <span>Where ${escapeHTML(page.competitor)} wins</span>
          ${listHTML(page.incumbentWins)}
        </article>
        <article class="panel accent">
          <span>Where Vibe Vault wins</span>
          ${listHTML(page.vibeWins)}
        </article>
      </div>
    </section>

    <section>
      <div class="shell">
        <div class="section-head">
          <div>
            <p class="eyebrow">Migration path</p>
            <h2>Start with one protected repo.</h2>
          </div>
          <p class="section-copy">The lowest-friction adoption path is not a platform migration. It is one repo, one key, one agent read, and one audit row.</p>
        </div>
        <ol class="steps">${page.migration.map((step) => `<li>${escapeHTML(step)}</li>`).join("")}</ol>
      </div>
    </section>

    <section>
      <div class="shell">
        <div class="section-head">
          <div>
            <p class="eyebrow">Sources</p>
            <h2>Public references checked on ${COMPARISON_UPDATED}.</h2>
          </div>
          <p class="section-copy">Competitor capabilities change quickly. Re-check official materials before using this copy in paid ads, sales collateral, or direct claims.</p>
        </div>
        <div class="sources">${page.sources.map((source) => `<a href="${escapeAttr(source.href)}">${escapeHTML(source.label)}</a>`).join("")}</div>
      </div>
    </section>

    <section class="related">
      <div class="shell">
        <p class="eyebrow">More comparisons</p>
        <div>${related}</div>
      </div>
    </section>
  </main>
  ${comparisonFooter()}
</body>
</html>`;
}

function comparisonNav(): string {
  return `<div class="shell">
    <nav class="topbar" aria-label="Primary">
      <a class="brand" href="/">
        <img src="/assets/vibe-vaulta-app-icon.png" width="30" height="30" alt="">
        Vibe Vault
      </a>
      <div class="nav-links">
        <a href="/agents">Agents</a>
        <a href="/scan">Scanner</a>
        <a href="/security">Security</a>
        <a href="/alternatives">Alternatives</a>
        <a class="download" href="/download">Install</a>
      </div>
    </nav>
  </div>`;
}

function comparisonFooter(): string {
  return `<footer>
    <div class="shell footer-inner">
      <span>(c) LunaOS | macOS 14+</span>
      <span><a href="https://github.com/lunaos-ai/luna-vault">GitHub</a> | <a href="/security">Security</a> | <a href="/download">Install</a></span>
    </div>
  </footer>`;
}

function listHTML(items: string[]): string {
  return `<ul>${items.map((item) => `<li>${escapeHTML(item)}</li>`).join("")}</ul>`;
}

function comparisonStyles(): string {
  return `<style>
    :root {
      color-scheme: dark;
      --bg: #090909;
      --panel: #141516;
      --panel-2: #1B1C1D;
      --line: rgba(248, 248, 248, 0.13);
      --text: #F8F8F8;
      --muted: #B7B7B7;
      --dim: #777A7E;
      --accent: #A5B4FC;
      --green: #91C8A9;
      --font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", "Helvetica Neue", Helvetica, sans-serif;
      --radius: 8px;
      --shell: 1080px;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: var(--font);
      line-height: 1.55;
      letter-spacing: 0;
      -webkit-font-smoothing: antialiased;
    }
    a { color: inherit; }
    .shell { width: min(var(--shell), calc(100% - 48px)); margin: 0 auto; }
    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      min-height: 72px;
      gap: 18px;
    }
    .brand, .nav-links, .btn {
      display: inline-flex;
      align-items: center;
    }
    .brand {
      gap: 10px;
      color: var(--text);
      text-decoration: none;
      font-weight: 650;
    }
    .brand img { width: 30px; height: 30px; border-radius: var(--radius); }
    .nav-links { gap: 4px; }
    .nav-links a, .btn {
      min-height: 42px;
      border-radius: var(--radius);
      padding: 10px 13px;
      text-decoration: none;
      color: var(--muted);
      font-size: 14px;
      font-weight: 620;
    }
    .nav-links a:hover { color: var(--text); background: rgba(255, 255, 255, 0.05); }
    .nav-links .download, .btn.primary {
      color: #090909;
      background: var(--accent);
    }
    .btn.secondary {
      color: var(--text);
      border: 1px solid rgba(248, 248, 248, 0.18);
      background: rgba(255, 255, 255, 0.04);
    }
    .hero {
      padding: 86px 0 72px;
      border-top: 1px solid var(--line);
      border-bottom: 1px solid var(--line);
      background:
        linear-gradient(90deg, rgba(9, 9, 9, 0.98), rgba(9, 9, 9, 0.72), rgba(9, 9, 9, 0.96)),
        url("/assets/vibe-vault-open-graph.png") center right / cover no-repeat;
    }
    .hero-grid {
      display: grid;
      grid-template-columns: minmax(0, 0.92fr) minmax(280px, 0.48fr);
      gap: 42px;
      align-items: end;
    }
    .eyebrow {
      margin: 0 0 12px;
      color: var(--accent);
      text-transform: uppercase;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0;
    }
    h1, h2, h3, p { letter-spacing: 0; }
    h1 {
      max-width: 760px;
      margin: 0;
      font-size: 58px;
      line-height: 1.02;
      font-weight: 700;
    }
    h2 {
      margin: 0;
      font-size: 38px;
      line-height: 1.08;
      font-weight: 660;
    }
    .lede {
      max-width: 720px;
      margin: 20px 0 0;
      color: var(--muted);
      font-size: 19px;
    }
    .cta-row { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 28px; }
    .quick-card, .panel, .alt-card {
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: rgba(20, 21, 22, 0.94);
    }
    .quick-card { padding: 24px; }
    .quick-card span, .panel span, .alt-card span {
      color: var(--accent);
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
    }
    .quick-card strong {
      display: block;
      margin-top: 14px;
      font-size: 21px;
      line-height: 1.22;
    }
    .quick-card p, .section-copy, .panel li, .alt-card p {
      color: var(--muted);
      font-size: 15px;
    }
    section { padding: 72px 0; border-bottom: 1px solid var(--line); }
    .section-head {
      display: grid;
      grid-template-columns: minmax(0, 0.74fr) minmax(260px, 0.42fr);
      gap: 42px;
      align-items: end;
      margin-bottom: 28px;
    }
    .section-copy { margin: 0; }
    .split {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 1px;
      overflow: hidden;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: var(--line);
    }
    .panel {
      border: 0;
      border-radius: 0;
      padding: 26px;
      background: var(--panel);
    }
    .panel.accent {
      background: linear-gradient(180deg, rgba(79, 70, 229, 0.16), rgba(79, 70, 229, 0)), var(--panel);
    }
    .panel ul { margin: 18px 0 0; padding: 0; list-style: none; }
    .panel li {
      padding: 12px 0;
      border-top: 1px solid var(--line);
    }
    .panel li:first-child { border-top: 0; }
    .table-wrap {
      overflow-x: auto;
      border: 1px solid var(--line);
      border-radius: var(--radius);
    }
    table {
      width: 100%;
      min-width: 760px;
      border-collapse: collapse;
      background: var(--panel);
    }
    th, td {
      padding: 16px;
      border-top: 1px solid var(--line);
      border-left: 1px solid var(--line);
      text-align: left;
      vertical-align: top;
      font-size: 14px;
    }
    th:first-child, td:first-child { border-left: 0; }
    thead th { border-top: 0; color: var(--text); background: #101113; }
    tbody td { color: var(--muted); }
    tbody td:first-child { color: var(--text); font-weight: 640; }
    .steps {
      margin: 0;
      padding: 0;
      display: grid;
      gap: 1px;
      list-style: none;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      overflow: hidden;
      background: var(--line);
      counter-reset: steps;
    }
    .steps li {
      counter-increment: steps;
      display: grid;
      grid-template-columns: 48px minmax(0, 1fr);
      gap: 14px;
      align-items: center;
      padding: 18px;
      background: var(--panel);
      color: var(--muted);
    }
    .steps li::before {
      content: counter(steps, decimal-leading-zero);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 38px;
      height: 38px;
      color: var(--accent);
      border: 1px solid rgba(165, 180, 252, 0.34);
      border-radius: var(--radius);
      font-size: 12px;
      font-weight: 700;
    }
    .sources, .related div {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
    }
    .sources a, .related a {
      display: inline-flex;
      align-items: center;
      min-height: 38px;
      padding: 8px 11px;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      color: var(--text);
      background: rgba(255, 255, 255, 0.04);
      text-decoration: none;
      font-size: 14px;
    }
    .alt-grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 1px;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      overflow: hidden;
      background: var(--line);
    }
    .alt-card {
      min-height: 228px;
      border: 0;
      border-radius: 0;
      padding: 24px;
      text-decoration: none;
      background: var(--panel);
    }
    .alt-card strong {
      display: block;
      margin-top: 18px;
      color: var(--text);
      font-size: 21px;
      line-height: 1.2;
    }
    .footer-inner {
      display: flex;
      justify-content: space-between;
      gap: 18px;
      padding: 34px 0 54px;
      color: var(--dim);
      font-size: 13px;
    }
    footer a { color: var(--muted); }
    @media (max-width: 880px) {
      .nav-links a:not(.download) { display: none; }
      .hero-grid, .section-head, .split, .alt-grid { grid-template-columns: 1fr; }
      .hero { padding: 58px 0 52px; }
      h1 { font-size: 42px; }
      h2 { font-size: 31px; }
      .shell { width: min(100% - 36px, var(--shell)); }
      .footer-inner { flex-direction: column; }
    }
  </style>`;
}

function escapeHTML(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function escapeAttr(value: string): string {
  return escapeHTML(value);
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
