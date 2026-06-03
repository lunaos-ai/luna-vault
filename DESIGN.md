---
name: Vibe Vault
description: A native macOS secret manager for AI-coding workflows — calm, precise, quiet.
colors:
  accent: "#4F46E5"
  accent-deep: "#3730A3"
  warm: "#F97716"
  mint: "#10B981"
  rose: "#E11448"
  status-success: "#34C759"
  status-warning: "#FF9500"
  status-danger: "#FF3B30"
  status-info: "#0A84FF"
  surface-background: "#F5F5F7"
  surface-elevated: "#FFFFFF"
  surface-separator: "#D1D1D6"
  text-primary: "#1D1D1F"
  text-secondary: "#6E6E73"
  text-tertiary: "#8E8E93"
typography:
  display:
    fontFamily: "-apple-system, SF Pro Display, system-ui"
    fontSize: "34pt"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "normal"
  largeTitleMono:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: "26pt"
    fontWeight: 600
    lineHeight: 1.15
  title:
    fontFamily: "-apple-system, SF Pro Display, system-ui"
    fontSize: "22pt"
    fontWeight: 600
    lineHeight: 1.2
  headline:
    fontFamily: "-apple-system, SF Pro Text, system-ui"
    fontSize: "17pt"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "-apple-system, SF Pro Text, system-ui"
    fontSize: "13pt"
    fontWeight: 400
    lineHeight: 1.45
  bodyMono:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: "13pt"
    fontWeight: 500
    lineHeight: 1.45
  caption:
    fontFamily: "-apple-system, SF Pro Text, system-ui"
    fontSize: "11pt"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "-apple-system, SF Pro Text, system-ui"
    fontSize: "11pt"
    fontWeight: 600
    letterSpacing: "0.5pt"
rounded:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
  xxxl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.surface-elevated}"
    rounded: "{rounded.sm}"
    padding: "8px 14px"
  button-primary-hover:
    backgroundColor: "{colors.accent-deep}"
    textColor: "{colors.surface-elevated}"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.sm}"
    padding: "6px 10px"
  surface-card:
    backgroundColor: "{colors.surface-elevated}"
    rounded: "{rounded.md}"
    padding: "0"
  surface-elevated-tile:
    backgroundColor: "{colors.surface-elevated}"
    rounded: "{rounded.sm}"
    padding: "12px"
  chip-danger:
    backgroundColor: "{colors.status-danger}"
    textColor: "{colors.status-danger}"
    rounded: "{rounded.pill}"
    padding: "3px 8px"
  chip-warning:
    backgroundColor: "{colors.status-warning}"
    textColor: "{colors.status-warning}"
    rounded: "{rounded.pill}"
    padding: "3px 8px"
  chip-accent:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent}"
    rounded: "{rounded.pill}"
    padding: "3px 8px"
  list-row:
    backgroundColor: "transparent"
    textColor: "{colors.text-primary}"
    padding: "4px 12px"
  toggle-switch:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.text-primary}"
  segmented-control:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.sm}"
    padding: "4px 10px"
---

# Design System: Vibe Vault

## 1. Overview

**Creative North Star: "The Locksmith's Bench"**

Vibe Vault is the quiet workshop of a craftsman who keeps other people's keys. The bench is uncluttered: tools at hand, evidence of care in the details, no theater. The light is honest, the surfaces are matte, and nothing draws the eye except the work in progress. When a developer opens the app at midnight to copy a token into a terminal, the room is already arranged for the task — no welcome card, no celebration, no animation competing with thought.

The system rejects the saturated purple-on-black reflex of consumer password managers (1Password, Bitwarden, LastPass), the navy-and-green ops-dashboard look of HashiCorp Vault, and the hero-metric-tile cosplay of generic SaaS dashboards. It also refuses the "AI-powered ✨" tone — no gradient text, no glassmorphism for decoration, no emoji in chrome. What it borrows instead is the first-party calm of macOS Mail and Notes, the dev-tool restraint of Raycast, and the hand-tuned spacing of Things 3 and Linear.

The palette is intentional silence: tonal layering on system surfaces, a graphite-indigo accent reserved for action and selection only, and status colors that arrive only when something needs attention. Type is system SF, with SF Mono carrying every identifier so secret names never get mistaken for prose.

**Key Characteristics:**
- Tonal layering over shadows — depth comes from semantic surface stacking, not box-shadows.
- Accent on action only — indigo `#4F46E5` appears on primary buttons, selection, and active focus; nowhere else.
- Monospace for identifiers — every secret name, value, and command renders in SF Mono.
- Content is the chrome — no hero tiles, no dashboard widgets, no "welcome back" cards.
- One material surface per detail pane — never stack cards inside cards.
- Status earns its color — red only for expired, orange only for rotation-due, green only for live session.

## 2. Colors

The palette is a graphite stage with one focused light. Tonal neutrals carry every surface and every glyph at rest; the accent appears only when the user can act on something.

### Primary
- **Graphite Indigo** (`#4F46E5`): The single accent. Used for the primary button, the selected sidebar row, focused field rings, and active MCP indicators. Never used for body text, never used for decoration, never used for status. Approx. OKLCH `oklch(0.55 0.21 271)`.
- **Graphite Indigo (Deep)** (`#3730A3`): The hover and pressed state for the primary button. Only ever paired with the base accent.

### Status (reserved, semantic)
- **Alert Red** (`#FF3B30`): Expired secrets, destructive confirmations, audit-tab "error" rows. Never for emphasis, never for marketing.
- **Caution Orange** (`#FF9500`): Rotation-due, "warn-within window" badges, lock icon when session is locked.
- **Confirm Green** (`#34C759`): Session-unlocked indicator, "imported N" success states. Never as a default state on an idle element.
- **Link Blue** (`#0A84FF`): Reserved for inline hyperlinks (docs hints, footer credits). Not used for actions.

### Neutral (semantic — values mirror macOS system colors)
- **Window Background** (`#F5F5F7` light / `#1E1E1E` dark): The base canvas behind every panel. Always a semantic NSColor (`windowBackgroundColor`) at runtime, not a literal hex.
- **Elevated Surface** (`#FFFFFF` light / `#2C2C2E` dark): The detail-pane card, form sections, segmented control background. Used at most once per scene; nesting is prohibited.
- **Separator** (`#D1D1D6` light / `#38383A` dark): Hairline (0.5pt) dividers between rows inside the elevated surface, and the outer stroke on material cards.
- **Text Primary** (`#1D1D1F` light / `#F5F5F7` dark): Body, secret names, headlines. Backed by `NSColor.labelColor`.
- **Text Secondary** (`#6E6E73`): Subtitles, captions, "Updated 3h ago" lines, metadata-row labels.
- **Text Tertiary** (`#8E8E93`): Empty-state glyphs, sidebar footer copy, bullet separators (`·`).

### Named Rules

**The Accent-On-Action Rule.** The Graphite Indigo accent is used only where the user can act or is currently active: the primary button, the selected sidebar row, focused fields, the MCP-allowed sparkle. Every other surface, glyph, and stroke is monochrome. Decorative use of the accent is forbidden.

**The Status-Earns-Color Rule.** Red, orange, and green carry semantic weight. A row only goes red because it is expired. A chip only goes orange because rotation is due. A dot only goes green because the session is currently unlocked. Status colors are never used for emphasis, hierarchy, or decoration.

**The Semantic-Surface Rule.** Every neutral references an NSColor at runtime (`windowBackgroundColor`, `controlBackgroundColor`, `labelColor`, `separatorColor`). The hex values in this document are the light-mode equivalents for reference; the actual color adapts to the user's appearance setting automatically.

## 3. Typography

**Display Font:** SF Pro Display (`-apple-system`)
**Body Font:** SF Pro Text (`-apple-system`)
**Mono Font:** SF Mono (`ui-monospace`)

**Character:** First-party Apple system pairing. SF Display carries the structural type at large sizes; SF Text takes over below ~20pt with adjusted optical sizing. SF Mono carries every identifier — secret names, values, env vars, paths — because monospace is how developers read code. Body weight is regular; mono weight is medium so identifiers feel grounded against prose.

### Hierarchy
- **Display** (semibold, 34pt, line-height 1.1): Onboarding hero ("Vibe Vault"). Used once per scene.
- **Large Title Mono** (semibold, 26pt, line-height 1.15, `.system(.largeTitle, design: .monospaced)`): The secret name in the detail-pane hero. Drops to `minimumScaleFactor 0.6` so long names fit without truncation.
- **Title** (semibold, 22pt, line-height 1.2): Section titles in onboarding, empty-state primary line.
- **Headline** (semibold, 17pt, line-height 1.3): Sidebar count line ("7 secrets"), settings-section headers.
- **Body** (regular, 13pt, line-height 1.45): All standard content. Default in form rows, descriptive text, secondary status lines.
- **Body Mono** (medium, 13pt): Secret names in the vault list, env-var examples, code snippets. Same size as body so they sit on the same line without optical conflict.
- **Caption** (regular, 11pt): Metadata rows ("Updated 3h ago"), footnotes, helper text below toggles.
- **Label** (semibold, 11pt, uppercase, +0.5pt tracking): Section labels above grouped surfaces ("DETAILS", "ACCESS"). Used sparingly — at most one per scene.

### Named Rules

**The Mono-For-Identifiers Rule.** Every secret name, value, env var, file path, and CLI command renders in SF Mono. Prose, labels, and metadata render in SF Text. The mode switch tells the user at a glance whether something is a thing-they-can-paste or a thing-they-can-read.

**The One-Display Rule.** The display style (34pt semibold) appears at most once per scene, and only on welcoming/orienting surfaces (onboarding, empty states). Detail panes lead with Large Title Mono instead — because the secret name *is* the title.

**The 65ch Rule.** Body copy in descriptive sections (form footers, settings text) caps at ~65 characters per line via container width, never via fixed font size. Dynamic Type still scales the actual size up.

## 4. Elevation

This system is **flat by default with tonal layering**. There are no box-shadows. Depth comes from stacking semantic surfaces (window background → elevated surface → separator stroke) and from the macOS title bar's own vibrancy. A material card sits on a darker canvas with a 0.5pt separator-tinted stroke at its edge; that single edge is the only depth cue at rest.

The original design used `.regularMaterial` for vibrancy on cards. As of this spec, materials remain available for the sidebar and toolbar (where macOS expects them by convention) but card surfaces use the **elevated** semantic background directly, not vibrancy. This makes contrast more predictable across light/dark and across desktop backgrounds.

### Tonal Vocabulary
- **Canvas** (`windowBackgroundColor`): the resting surface behind every panel.
- **Elevated** (`controlBackgroundColor`): one step up — the detail-pane card, the form-section background, the segmented control track.
- **Inset** (`controlBackgroundColor` at 60% opacity over elevated): one step down inside an elevated surface — the secret-value reveal field, code blocks.

### Stroke Vocabulary
- **Hairline** (0.5pt, `separatorColor`): the perimeter of elevated cards and the dividers between rows inside a card.
- **Thin** (1pt, `separatorColor`): toolbar and sidebar bottom borders, focus rings on text fields.

### Named Rules

**The No-Shadow Rule.** No `box-shadow` or `dropShadow` modifiers anywhere in the app. Drop shadows are the first move of a SaaS dashboard and the first sign of "AI made that." Depth is built with semantic surfaces and 0.5pt strokes.

**The One-Elevation-Per-Pane Rule.** A detail pane carries one elevated surface, never two. Sections inside it are separated by hairlines, not by additional cards. Nested cards are always wrong.

## 5. Components

Components are quietly engineered: tactile and confident at the touch points, restrained everywhere else. Buttons feel built, not decorated. Cards look like furniture in a workshop, not pages from a brochure.

### Buttons
- **Shape:** softly rounded (`{rounded.sm}` = 8px on every variant). No pill buttons.
- **Primary:** Graphite Indigo background, white text, 8px radius, 8pt × 14pt padding. `.buttonStyle(.borderedProminent)` on macOS with `.tint(Tokens.Palette.accent)`. Hover/pressed darkens to `#3730A3` automatically via system styling. Used at most once per visible region.
- **Secondary / Ghost:** transparent background, primary-text foreground, system-default `.bordered` style. Used for "Refresh", "Cancel", "Check now". Never visually competes with primary.
- **Destructive:** `role: .destructive` only. System styles it red automatically. Confined to delete, lock-session, reset-reminders.
- **Focus:** the system-provided focus ring (blue keyboard focus). Do not override.

### Chips / Badges
- **Style:** capsule (`{rounded.pill}`) with the parent color at 12% background and the parent color as foreground text. 3pt × 8pt padding, caption2 weight.
- **Variants:** danger (`#FF3B30`), warning (`#FF9500`), accent (`#4F46E5`). No neutral chip — if a label has no semantic color, it is plain text, not a chip.
- **Position:** trailing on a row, never leading. The user reads the identifier first.

### Cards / Surfaces
- **Corner:** `{rounded.md}` = 12px. Continuous corner style.
- **Background:** elevated surface (`controlBackgroundColor`). Never material on a card.
- **Border:** 0.5pt hairline in `separatorColor` at 60% opacity. The single edge replaces a shadow.
- **Internal padding:** rows inside use `{spacing.md}` vertical, `{spacing.md}` horizontal. Headers add an extra `{spacing.sm}` of top padding for breathing room.
- **One per scene.** Never nest cards inside cards.

### Inputs / Fields
- **Style:** system-default `.textFieldStyle(.roundedBorder)` on macOS. Mono variant for identifier fields (`.font(.system(.body, design: .monospaced))`).
- **Focus:** system focus ring; no custom glow.
- **Secure fields:** `SecureField` always for values. Reveal toggle as a leading or trailing borderless button.

### List Rows (Vault list, Audit table)
- **Layout:** monochrome 13pt key glyph (size 13, weight medium, tertiary text color) — *not* a colored avatar tile — followed by the secret name in Body Mono, then a caption-sized status line in secondary text.
- **Selection:** system blue selection background (the user's macOS accent color in System Settings). Vibe Vault's own indigo accent does not override.
- **Trailing:** a single status glyph (triangle for issue, sparkle for MCP-allowed) at caption2 size. Never two.

### Toggle Switches
- **Style:** native `Toggle().toggleStyle(.switch)`. System styles "on" as Graphite Indigo when set via `.tint()`.
- **Layout:** label and helper-copy on the leading side, switch trailing. Helper copy in caption secondary text.

### Segmented Control (filter pills)
- **Style:** native `Picker().pickerStyle(.segmented)`. Used at the top of the vault sidebar for "All / Expiring / Rotate due / AI-allowed".
- **Position:** between the count line and the search bar — never below the list.

### Sidebar Rows
- **Style:** native `Label(text, systemImage:)` inside a `List(selection:)` with `.listStyle(.sidebar)`.
- **No colored icon tiles.** Glyphs render in secondary text color until the row is selected; selection inherits system accent.
- **Section headers:** plain text section titles ("Library", "Workflows", "System") — no custom typography.

### Signature: The Detail Hero
The detail pane opens with **Large Title Mono** (the secret name itself) on a transparent background, a single-line relative-time subtitle below ("Updated 3h ago"), and the **inset value field** below that. No avatar tile, no card wrapping the hero, no decorative gradient. The hero IS the secret name.

## 6. Do's and Don'ts

### Do:
- **Do** reserve Graphite Indigo (`#4F46E5`) for primary action and selection only. Body, glyphs, and decoration stay monochrome.
- **Do** render every identifier (secret name, value, env var, command) in SF Mono. Prose stays in SF Text.
- **Do** use 0.5pt hairline strokes (`separatorColor`) for the perimeter of elevated cards and the dividers between rows.
- **Do** stack tonal surfaces for depth: canvas → elevated → inset. Three tones is the maximum.
- **Do** keep one elevated card per detail pane. Section it with hairlines, not with nested cards.
- **Do** carry status meaning via icon + label + color together — never color alone (color-blind safe).
- **Do** respect `@Environment(\.accessibilityReduceMotion)` on every future animation; fall back to instant transitions.
- **Do** use native `Toggle`, `Picker(.segmented)`, `TextField(.roundedBorder)`, and `List(.sidebar)` styles. macOS HIG conventions are not negotiable.
- **Do** size the secret name with `minimumScaleFactor 0.6` so long identifiers fit without truncation.

### Don't:
- **Don't** use saturated purple-on-black or any 1Password-violet `#7C3AED`-style hue. We refused that category-reflex on purpose.
- **Don't** use gradients on text (`background-clip: text` or its SwiftUI equivalents). The Graphite Indigo is a solid color, always.
- **Don't** use glassmorphism as default. Materials belong on the sidebar and toolbar by macOS convention; cards use the elevated semantic background.
- **Don't** build hero-metric tiles. "Total / Rotate due / Expired / MCP" as four colored boxes is the SaaS-dashboard cliché. Inline counts in a single text line instead.
- **Don't** stack cards inside cards. The detail pane is one elevated surface.
- **Don't** add box-shadows. Depth is tonal, not lifted.
- **Don't** put a TextField inside a toolbar (current AuditLogView regression). Filters belong in popovers or column headers on macOS.
- **Don't** use colored icon tiles in the sidebar. Glyphs are tertiary monochrome until the row is selected.
- **Don't** use the Bitwarden / LastPass consumer chrome vocabulary — gradient buttons, in-app upsell, "Premium" badges. There is no upsell surface.
- **Don't** use the HashiCorp Vault navy-and-green ops aesthetic. Vibe Vault is for one developer at midnight, not an SRE team.
- **Don't** use em dashes in any UI copy or commit message. Use commas, colons, semicolons, periods, or parentheses.
- **Don't** use the friendly-bot tone in empty states ("Your vault is calm ✨"). Terse, factual: "Nothing selected. Pick a secret from the list, or add a new one."
- **Don't** animate CSS layout properties (or SwiftUI's frame). Transitions go on transform / opacity equivalents only.
