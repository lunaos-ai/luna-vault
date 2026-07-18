# Product

## Register

product

> Primary surface is the macOS app, CLI, and menu bar — design serves function.
> A marketing landing page may follow on the brand register; treat it separately when it lands.

## Users

Solo developers and small teams using AI-coding tools (Cursor, Claude Code, Windsurf) on macOS 14+. They live in two contexts that bleed into each other:

- **Active build sessions**: switching between IDE, terminal, and AI agent at midnight. They need a secret pasted into the next command in under three seconds, with zero modal friction.
- **Audit-after-the-fact**: someone (themselves, a co-founder, future-self) asks "which agent read CF_API_TOKEN last week?" — they need to answer it in one click.

Today they juggle `.env` files (which leak into commits), copy-paste from 1Password (no audit trail of which AI saw what), or pipe secrets through shell scripts (no rotation reminders). Vibe Vault replaces all three.

The job: **trust a single local source for every secret, audited per AI agent, with zero cloud accounts.**

## Product Purpose

A native macOS secret manager designed for the AI-coding workflow.

- Secrets live in an **encrypted local vault** (AES-GCM); the master key is held in **macOS Keychain**. Reads are Touch ID gated.
- Every read is **audited per AI agent** — Claude Code, Cursor, Windsurf are tagged on every access.
- **Local-first**: no telemetry, no account, no cloud unless the user explicitly pushes to Cloudflare/Vercel/etc.
- **One-command sync** to provider environments when needed, but never as a default.

Success looks like a developer who, three weeks in, stops thinking about secret hygiene because it's automatic. No more `.env` in git, no more "which key did I rotate, when?" lookups.

## Brand Personality

**Calm. Precise. Quiet.**

- **Voice**: terse, technical, factual. Sentences earn their place. No marketing adjectives, no "✨ AI-powered ✨", no emoji.
- **Tone**: like macOS Mail or Notes — the app stays out of the way until summoned. Errors are short and specific. Success states are silent or inline.
- **Energy**: low-stim. The primary emotion when a developer opens Vibe Vault at midnight is **relief — finally a calm tool**. Anti-stress. Predictable layout. Big hit targets. No surprises, no animations that compete with thought.

## Anti-references

- **1Password** — menu density, multi-vault dropdowns, modal-heavy flows, marketing inside the product. Vibe Vault is single-vault, inline, modal only when an action would otherwise be ambiguous.
- **Bitwarden / LastPass** — consumer chrome, gradient buttons, in-app upsell, "Premium" badges. Vibe Vault stays graphite-indigo on system materials.
- **HashiCorp Vault** — navy-and-green enterprise/ops aesthetic, role-management dialogs, policy YAML. Vibe Vault is for one developer, not an SRE team.
- **Generic SaaS dashboards** — hero-metric tiles, identical card grids, sparkline soup, gradient accents on everything. The design-system kit-of-parts look. Vibe Vault is content-first, list-and-detail, no dashboard cosplay.

First-order category reflex to refuse: **secret-manager → saturated purple-on-black**. Vibe Vault's accent is intentionally a calmer indigo (`#4F46E5`) on system materials, and accent is restricted to action affordances and selection — not decorative.

## Design Principles

1. **Calm by default, sharp on action.** Surfaces are quiet (system materials, semantic text, monochrome glyphs). Accent appears only where the user can act — primary button, selected row, focused field, status that demands attention.
2. **Content is the interface.** The secret name, value, and audit row are the UI. No chrome, no hero metrics, no "welcome back" cards. Detail panes carry one material surface, not three.
3. **One local vault.** Secrets ciphertext lives under Application Support; the master key and prefs live in Keychain. No cloud account for Solo. No shadow plist the user can lose.
4. **The audit log is a first-class surface.** Not a settings page. Every read is recorded, every agent tagged, every row queryable. Trust is built by making it easy to verify.
5. **Three seconds to the secret.** From command-N to "secret in clipboard" should be three keystrokes and one Touch ID prompt. Friction is a design failure.

## Accessibility & Inclusion

Target: **WCAG 2.2 AA + macOS HIG**.

- **Contrast**: ≥4.5:1 for body text against background materials; ≥3:1 for large text and UI components. Audited in both light and dark appearance.
- **Keyboard nav**: every interactive element reachable via Tab; ⌘N adds a secret, ⌘F focuses search, ⌘C copies the selected secret value (Touch-ID-gated). No mouse-only paths.
- **VoiceOver**: every button, badge, and toggle carries an `accessibilityLabel`. Status (`Session unlocked`, `Locked — Touch ID required`) is read as a single combined element.
- **Dynamic Type**: typography uses system text styles (`.title2`, `.body`, `.caption`) so it scales with the user's preferred size.
- **Reduced motion**: future animations (when `/impeccable animate` runs) must guard on `@Environment(\.accessibilityReduceMotion)` and fall back to instant transitions.
- **Color blindness**: status colors (red expired, orange rotate-due) are never the only signal — text labels and icons accompany every state.
