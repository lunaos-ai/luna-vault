# Vibe Vault HIG Analysis

**Scope**: Vibe Vault (luna-vault) / Marketing landing + macOS SwiftUI app  
**Analysis Type**: compliance  
**Generated**: 2026-07-18  
**Agent**: Luna Apple HIG Designer  
**Compliance Score**: **6.2 / 10** overall (Landing **6.5** after 2026-07-18 HIG pass, App **6.8**)  
**Brand north star**: The Locksmith's Bench · Calm / Precise / Quiet · Accent `#4F46E5` on action only  

### Landing HIG pass (2026-07-18)

Applied top fixes to `workers/vibevault/public/index.html`:
1. Light + `prefers-color-scheme: dark` semantic palette (DESIGN.md surfaces)
2. Removed glow / pill CTAs / lift hover
3. Accent only on primary Download / Start Free / Buy Team
4. Product OG shot in hero (not glowing icon theater)
5. System SF stack, `:focus-visible`, 44px targets, no Google Fonts

Remaining app issues (Overview dashboard, luxuryCard) still open — see Critical C6–C9.  

---

## Executive Summary

The **macOS app** is mostly on-brand: `NavigationSplitView`, semantic `NSColor` surfaces, SF Mono for identifiers, reduce-motion guards, and a content-first secret detail hero. It still drifts into dashboard chrome (Overview quick-action grid, accent-tinted “luxury” cards, decorative indigo backdrop).

The **marketing landing** (`workers/vibevault/public/index.html`) is the opposite of Locksmith’s Bench: purple-on-near-black, Instrument Sans, pill CTAs, indigo glow, and SaaS pricing cards. That is the category reflex PRODUCT.md explicitly refuses. Fix the landing first; it is why the site feels “bad” next to the product voice.

---

## Overall HIG Score (Clarity / Deference / Depth)

| Surface | Clarity | Deference | Depth | Notes |
|---------|--------:|----------:|------:|-------|
| Landing (web HIG adaptation) | **4.0** | **3.0** | **4.5** | Wrong depth (glow/shadow), chrome competes with content |
| macOS SwiftUI app | **7.0** | **6.5** | **7.0** | Strong structure; Overview + material cards weaken deference |
| **Weighted overall** (app primary) | **6.2** | **5.6** | **6.3** | **Overall ≈ 5.4/10** |

### Core principles

- **Clarity**: App type hierarchy and mono-for-identifiers are clear. Landing uses a non-system font, soft muted text on `#07070a`, and decorative accent on labels/code, which muddies hierarchy.
- **Deference**: App detail panes lead with the secret name (good). Landing and Overview still sell the chrome (glow icon, metric tiles, quick-action card grid) instead of the work.
- **Depth**: App correctly prefers tonal layering over shadows in most places. Landing uses glow, lift transforms, and card hover elevation. App regressions: `ToastBanner` drop shadow, `luxuryCard` accent gradient stroke, `PremiumBackdrop` indigo wash.

---

## Critical issues (must-fix)

### Landing — `workers/vibevault/public/index.html`

| # | Issue | Why it fails HIG / brand | Location |
|---|--------|---------------------------|----------|
| C1 | **Purple-on-black stage** (`--bg: #07070a`, indigo glow) | PRODUCT anti-reference: “secret-manager → saturated purple-on-black.” Feels like 1Password category cosplay, not Locksmith’s Bench. | `:root` lines 19–30; `.hero-mark::before` 111–118; `.btn-primary` glow 162–166 |
| C2 | **Accent used for decoration** | Accent-On-Action Rule: indigo only for primary action / selection. Landing paints section labels, code, tier names, footer hover in `--accent-soft`. | `.section-label` 191–198; `code` 51–55; `.tier-name` 304–310; `footer a:hover` 413 |
| C3 | **No light appearance / forced dark** | Web HIG adaptation of a macOS-first product should respect `prefers-color-scheme` and map to DESIGN semantic surfaces (`#F5F5F7` / `#1E1E1E`). Forced noir fights calm. | Entire stylesheet; no `@media (prefers-color-scheme: light)` |
| C4 | **Glow + pill CTAs + lift hover** | DESIGN: no decorative glow, no pill buttons in product language; landing still reads as generic SaaS. Depth via shadow/glow, not tonal surfaces. | `.nav-links .dl` 91–97; `.btn` 148–166; `.tier:hover` 281–284; `@keyframes glow` 419–422 |
| C5 | **Hero is glowing app-icon theater, not product work** | First viewport should show brand + one claim + CTA + real product visual. Large icon + radial glow is brochure chrome; product shot is buried below the fold in `#product`. | `.hero` / `.hero-mark` 100–123; header 439–453 |

### macOS app

| # | Issue | Why it fails | Location |
|---|--------|--------------|----------|
| C6 | **Overview is a SaaS dashboard** | PRODUCT forbids hero-metric / quick-action card grids. “Good morning” + status chips + 5 tinted `QuickActionCard`s compete with content. | `apps/VibeVaultApp/Features/Vault/VaultOverviewView.swift` |
| C7 | **`luxuryCard` + material cards** | DESIGN: cards use elevated semantic background, not `.regularMaterial`; no accent gradient strokes; no nested card theater. | `Theme/Tokens.swift` (`luxuryCard`, `cardSurface`); `Theme/QuickActionCard.swift` |
| C8 | **Accent override on sidebar selection glyphs** | DESIGN: list selection uses system accent; glyphs stay secondary until selected by system, not custom indigo. | `Scenes/MainSidebar.swift` 94–97 |
| C9 | **Decorative purple / accent outside action** | MCP badge `.purple`; empty-state radial accent glow; audit event count in accent. Status / decoration misuse. | `Features/Vault/SecretBadges.swift`; `VaultEmptyStates.swift`; `AuditLogView.swift` 42–44 |

---

## Medium issues

### Landing

1. **Instrument Sans via Google Fonts** instead of SF / system stack (`-apple-system, BlinkMacSystemFont, "SF Pro Text", …`). Brand typography is SF; web should mirror it.
2. **Em dashes in user-facing copy** (`title`, OG image `alt`) — DESIGN forbids em dashes in UI/copy.
3. **Teal “Most Popular” chip** and popular-tier teal border — not in brand status vocabulary; adds marketing noise.
4. **Invalid / non-semantic `<n>` element** for step numbers — use `<span class="step-num">`.
5. **No `:focus-visible` styles** on links/buttons — keyboard users get browser default or nothing clear on dark UI.
6. **Pricing tier art with `alt=""`** — decorative is fine; ensure images are not the only price cue (they aren’t). Prefer omitting heavy art for a quieter bench look.
7. **`scroll-behavior: smooth`** — reduced-motion is handled (good); keep it that way if any new motion is added.
8. **FAQ `details` open by default** — fine for one item; ensure summary has a visible focus ring and larger hit area (≥44×44 CSS px).

### macOS app

1. **Hardcoded `font(.system(size: …))`** in sidebar brand, overview greeting, audit count — weak Dynamic Type vs semantic text styles.
2. **Icon-only Reveal / Copy** in `SecretDetailView` use `.help` but lack explicit `accessibilityLabel` / `accessibilityHint` (VoiceOver may get SF Symbol names only).
3. **`ToastBanner` drop shadow** — violates No-Shadow Rule (`Theme/ToastBanner.swift`).
4. **`PremiumBackdrop` indigo wash** — mild decorative accent on every detail pane; prefer plain `windowBackgroundColor`.
5. **Status chips on Overview** paint green for “ok” idle (Touch ID / Cloudflare / MCP) — Status-Earns-Color: green only for live session unlock, etc.
6. **Onboarding copy uses em dash** (“Devin. Opt-in…”) — `OnboardingScene.swift` line 51.
7. **Colored icon tiles** in sidebar brand and QuickAction cards — DESIGN: no colored icon tiles; monochrome glyphs.
8. **Sparse VoiceOver coverage** — labels exist on sidebar rows, some badges, MenuBar copy; many toggles/buttons rely on default labels only.
9. **`symbolEffect(.bounce)`** on sidebar — Motion.swift guards custom animation, but symbol effects should also gate on `accessibilityReduceMotion`.

---

## What’s already good

### Landing

- Single-column shell, readable max-width (~1080px), clear section jobs (Product / Pricing / Activate / FAQ).
- Hero content budget is mostly right: brand name, one lede, two CTAs, install command.
- **`prefers-reduced-motion`** kills animations and smooth scroll (correct).
- Semantic HTML landmarks: `nav`, `header.hero`, `section`, `footer`, `details`/`summary`.
- Primary CTA contrast (white on `#4F46E5`) is strong.
- Brew install shown as monospace — matches Mono-For-Identifiers spirit.

### macOS app

- **`NavigationSplitView` + `.listStyle(.sidebar)`** — correct macOS HIG chrome.
- **Semantic surfaces** via `NSColor.windowBackgroundColor` / `controlBackgroundColor` / `labelColor` in `Tokens.swift`.
- **Secret detail hero**: Large Title Mono + relative time + deep-inset value — matches DESIGN signature.
- **Hairline strokes** instead of shadows on detail surface.
- **Native controls**: `Toggle(.switch)`, `confirmationDialog`, `Table`, `ContentUnavailableView`, `.borderedProminent`.
- **`Motion` + `AppearFade` / `PressableScale`** honor `accessibilityReduceMotion`.
- **Empty states** are terse and factual (`VaultEmptyState`), not “✨ calm vault”.
- **Audit as first-class sidebar destination** — product principle upheld.
- **Menu bar** search + copy with accessibility label on copy actions.

---

## Landing page — concrete CSS/HTML fix recommendations (priority)

User feedback: landing looked bad. Implement these in order.

### Top 5 changes to implement immediately

1. **Flip to light Locksmith canvas (or dual theme)**  
   Replace noir with DESIGN neutrals; keep accent only on primary buttons.

```css
:root {
  --bg: #F5F5F7;
  --fg: #1D1D1F;
  --muted: #6E6E73;
  --dim: #8E8E93;
  --accent: #4F46E5;
  --accent-deep: #3730A3;
  --line: #D1D1D6;
  --elevated: #FFFFFF;
  --font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1E1E1E;
    --fg: #F5F5F7;
    --muted: #98989D;
    --dim: #8E8E93;
    --line: #38383A;
    --elevated: #2C2C2E;
  }
}
```

Remove `--glow`, `--accent-soft` as decorative fills, `--teal` popular badge styling.

2. **Kill glow, pills, and lift**  
   - Delete `.hero-mark::before` and `@keyframes glow`.  
   - Buttons: `border-radius: 8px` (not `999px`); primary = solid `--accent`, no `box-shadow`.  
   - `.tier:hover`: change border only (or none); remove `transform: translateY(-3px)`.  
   - Nav Download: same 8px radius as primary button.

```css
.btn, .nav-links .dl {
  border-radius: 8px;
  box-shadow: none;
}
.btn-primary { background: var(--accent); }
.btn-primary:hover { background: var(--accent-deep); }
.btn:hover { transform: none; }
.tier:hover { transform: none; border-color: var(--line); }
```

3. **Accent only on action**  
   - `.section-label`, `.tier-name`, `code`, footer links → `--muted` / `--fg`, not indigo.  
   - Keep indigo on: `.btn-primary`, `.nav-links .dl`, focused inputs only.

```css
.section-label { color: var(--dim); }
code { color: var(--fg); }
.tier-name { color: var(--dim); }
footer a:hover { color: var(--fg); }
```

4. **Hero: product shot first, quiet mark second**  
   Move `/assets/vibe-vault-open-graph.png` (or a real app screenshot) into the hero as a full-bleed-width shot under the lede/CTAs. Shrink the app icon to ~48–64px beside the wordmark in the nav only (or a small mark above the H1 without glow/shadow).

```html
<header class="hero">
  <p class="brand-mark"><img … width="48" height="48" alt="" /> Vibe Vault</p>
  <h1>Local secrets for Cursor and Claude</h1>
  <p class="lede">…</p>
  <div class="cta-row">…</div>
  <pre class="brew">…</pre>
  <figure class="shot hero-shot">
    <img src="/assets/…" alt="Vibe Vault vault list and secret detail on macOS" />
  </figure>
</header>
```

```css
.hero { text-align: left; max-width: 40rem; } /* or centered type + full-bleed shot */
.hero-shot {
  margin-top: 40px;
  border-radius: 12px;
  border: 0.5px solid var(--line);
  background: var(--elevated);
  box-shadow: none;
}
.hero-mark img { box-shadow: none; border-radius: 12px; }
```

5. **System typography + focus rings + copy hygiene**  
   - Drop Google Fonts `<link>`s; use system stack above.  
   - Replace em dashes in `<title>` and `alt` with commas or periods.  
   - Add focus styles:

```css
a:focus-visible, .btn:focus-visible, summary:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}
```

   - Replace `<n>` with `<span class="step-num">`.  
   - Soften pricing: remove “Most Popular” teal chip; one elevated surface per tier with hairline border on `--elevated` over `--bg` (no hover lift).

### Additional landing fixes (soon after top 5)

| Fix | Sketch |
|-----|--------|
| Pricing cards | `background: var(--elevated); border: 0.5px solid var(--line); border-radius: 12px;` no art strip, or a single quiet product crop |
| Features checkmarks | Use text “—” or a muted glyph, not bright green ✓ decoration |
| Config warn | Keep caution orange; ensure ≥4.5:1 text contrast |
| Skip link | `<a class="skip" href="#product">Skip to content</a>` for keyboard |
| `color-scheme` | `<meta name="color-scheme" content="light dark">` |

---

## Accessibility gaps

### Contrast

| Item | Risk | Fix |
|------|------|-----|
| Landing `--muted` `#9898a6` on `#07070a` | Likely AA for body; `--dim` `#636372` on dark may fail for 12px footer/brew | Raise dim to ≥ `#8E8E93` on dark; recheck after light theme |
| `--accent-soft` `#818cf8` on black for labels | Decorative; after Accent-On-Action, use muted neutrals | See C2 |
| App semantic labels | Generally good via system colors | Prefer `secondaryLabelColor` over custom hex |
| Toast / materials | Vibrancy can drop contrast on busy wallpapers | Prefer elevated opaque cards per DESIGN |

### Touch / click targets

| Item | Risk | Fix |
|------|------|-----|
| Landing nav links `padding: 8px 12px` | ~30px tall; under 44px | Increase to `min-height: 44px; padding: 12px 14px` |
| Landing FAQ `summary` | Thin hit area | `min-height: 44px; display: flex; align-items: center` |
| App icon-only Reveal/Copy | Symbol buttons may be &lt;44pt | Expand hit with `.frame(minWidth: 44, minHeight: 44)` or `.contentShape` |
| Sidebar rows `padding.vertical: 3` | Dense; OK for macOS lists if full-row hit | Ensure `.contentShape(Rectangle())` remains (already present) |

### Reduce motion

| Surface | Status |
|---------|--------|
| Landing | **Good** — animations/transitions disabled under `prefers-reduced-motion` |
| App `Motion.swift` | **Good** for AppearFade / PressableScale / Toast |
| App `symbolEffect(.bounce)` | **Gap** — gate with `@Environment(\.accessibilityReduceMotion)` |
| App `SecretRow` hover scale | **Good** — checks reduceMotion |

### Focus (keyboard)

| Surface | Status |
|---------|--------|
| Landing | **Gap** — no custom `:focus-visible`; dark UI makes default rings hard to see |
| App | Relies on system focus rings (correct; do not override). Ensure custom plain buttons keep focusability |

### VoiceOver / screen readers

| Gap | File | Fix |
|-----|------|-----|
| Reveal / Copy icon buttons | `SecretDetailView.swift` | `.accessibilityLabel("Reveal value")` / `"Hide value"` / `"Copy value"` + hint for Touch ID |
| Session / biometric status | `SidebarStatusFooter.swift` | Combine into one accessibility element with spoken status |
| Overview status chips | `VaultOverviewView.swift` | Labels like “Touch ID available” / “Cloudflare not connected” |
| Pricing decorative images | `index.html` | Keep `alt=""`; ensure tier name + price are in text (they are) |
| Invalid `<n>` | `index.html` | Replace with `<span>` so AT doesn’t invent roles |

### Dynamic Type

- Prefer `.title2`, `.body`, `.caption` over fixed `size: 34` / `13` / `10` in sidebar brand and overview.
- Secret name already uses `.largeTitle` + `minimumScaleFactor` — keep that pattern.

---

## macOS app — SwiftUI fix sketches (secondary priority)

```swift
// Tokens.swift — cards: elevated, not material; no accent gradient stroke
func cardSurface(radius: CGFloat = Tokens.Radius.md) -> some View {
    self
        .padding(Tokens.Space.lg)
        .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
}

// Delete or stop using luxuryCard(); QuickActionCard should become plain List rows or bordered buttons.

// SecretDetailView — VoiceOver
Button { Task { await reveal() } } label: {
    Image(systemName: revealed ? "eye.slash" : "eye")
}
.accessibilityLabel(revealed ? "Hide value" : "Reveal value")
.accessibilityHint("Requires Touch ID")
.frame(minWidth: 44, minHeight: 44)

// MainSidebar — monochrome glyphs; let List selection paint system accent
Image(systemName: item.systemImage)
    .foregroundStyle(Tokens.Text.secondary)
// Remove custom accent fill on brand tile; use tertiary key glyph only.

// VaultOverviewView — replace QuickActionCard grid with one inline action line or sidebar destinations only.
```

---

## Compliance roadmap

| Phase | Focus | Outcome |
|-------|--------|---------|
| **0 (this week)** | Landing top 5 CSS/HTML | Site matches Locksmith’s Bench; stops looking like purple SaaS |
| **1** | Landing a11y (focus, targets, skip link, light/dark) | WCAG 2.2 AA on marketing |
| **2** | Retire `luxuryCard` / Overview grid; elevated cards only | App deference restored |
| **3** | VoiceOver pass on reveal/copy, status footer, badges | Audit-ready a11y |
| **4** | Dynamic Type sweep + reduceMotion on symbol effects | HIG polish |

---

## Scorecard vs DESIGN.md named rules

| Rule | Landing | App |
|------|---------|-----|
| Accent-On-Action | Fail | Partial fail (backdrop, luxury stroke, sidebar, badges) |
| Status-Earns-Color | Fail (teal/green checks) | Partial (overview chips, purple MCP) |
| Semantic-Surface | N/A (web) | Partial (materials on cards) |
| Mono-For-Identifiers | Partial (brew only) | Pass |
| One-Display | Pass (one H1) | Partial (Overview greeting = display) |
| No-Shadow | Fail | Mostly pass (toast exception) |
| One-Elevation-Per-Pane | Fail (pricing card stack) | Mostly pass on detail; Overview nested luxury cards fail |
| No colored icon tiles | Fail (hero glow icon) | Fail (QuickAction + sidebar brand) |
| No em dashes | Fail | Fail (onboarding) |
| Reduce motion | Pass | Mostly pass |

---

## Top 5 landing-page CSS/HTML changes (immediate checklist)

1. Light (or light+dark) semantic palette; remove noir + glow tokens.  
2. Remove hero glow animation, pill radii, button/tier lift shadows.  
3. Restrict `#4F46E5` to primary Download / Start Free / Buy Team only.  
4. Put a real product screenshot in the hero; shrink/quiet the app icon.  
5. System font stack, `:focus-visible` rings, drop Google Fonts + em dashes + `<n>`.

---

*End of report. Full path: `.luna/vibe-vault/hig-analysis.md`*
