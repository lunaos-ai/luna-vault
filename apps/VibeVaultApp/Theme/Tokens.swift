import SwiftUI

/// HIG-aligned design tokens. SF system font, semantic colors, vibrancy materials.
enum Tokens {
    enum Palette {
        // Graphite indigo — calmer than 1Password purple, distinct from Bitwarden blue.
        // L≈48 chroma≈0.13 hue≈262 (OKLCH) — sits between Apple's stock indigo and macOS Mail blue.
        static let accent = SwiftUI.Color(red: 0x4F / 255, green: 0x46 / 255, blue: 0xE5 / 255)
        static let warm = SwiftUI.Color(red: 0xF9 / 255, green: 0x77 / 255, blue: 0x16 / 255)
        static let mint = SwiftUI.Color(red: 0x10 / 255, green: 0xB9 / 255, blue: 0x81 / 255)
        static let rose = SwiftUI.Color(red: 0xE1 / 255, green: 0x14 / 255, blue: 0x48 / 255)
    }

    enum Surface {
        static let background = SwiftUI.Color(NSColor.windowBackgroundColor)
        static let elevated = SwiftUI.Color(NSColor.controlBackgroundColor)
        static let separator = SwiftUI.Color(NSColor.separatorColor)
    }

    enum Text {
        static let primary = SwiftUI.Color(NSColor.labelColor)
        static let secondary = SwiftUI.Color(NSColor.secondaryLabelColor)
        static let tertiary = SwiftUI.Color(NSColor.tertiaryLabelColor)
    }

    enum Status {
        static let success = SwiftUI.Color.green
        static let warning = SwiftUI.Color.orange
        static let danger = SwiftUI.Color.red
        static let info = SwiftUI.Color.blue
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let pill: CGFloat = 999
    }

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let thin: CGFloat = 1
    }

    /// Liquid Glass tints — translucent fills layered over `.ultraThinMaterial`
    /// to give surfaces depth and a faint colored cast.
    enum Glass {
        static let tint = Palette.accent.opacity(0.06)
        static let highlight = SwiftUI.Color.white.opacity(0.22)
        static let edge = SwiftUI.Color.white.opacity(0.30)
        static let shadow = SwiftUI.Color.black.opacity(0.18)
    }

    /// Spring motion vocabulary. All consumers must gate on Reduce Motion.
    enum Motion {
        static let spring = SwiftUI.Animation.spring(response: 0.42, dampingFraction: 0.78)
        static let snappy = SwiftUI.Animation.spring(response: 0.30, dampingFraction: 0.82)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.45)
    }

    /// Floating elevation — drives shadow radius/offset for glass objects.
    enum Elevation {
        case resting, floating, lifted

        var radius: CGFloat {
            switch self { case .resting: 6; case .floating: 18; case .lifted: 30 }
        }
        var y: CGFloat {
            switch self { case .resting: 2; case .floating: 8; case .lifted: 16 }
        }
        var opacity: Double {
            switch self { case .resting: 0.10; case .floating: 0.18; case .lifted: 0.26 }
        }
    }
}

extension View {
    /// HIG-flavoured card: vibrancy material + hairline stroke + soft radius.
    func cardSurface(radius: CGFloat = Tokens.Radius.md) -> some View {
        self
            .padding(Tokens.Space.lg)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
            )
    }

    /// Soft tinted chip background for badges / status pills.
    func tintedChip(_ color: Color) -> some View {
        self
            .padding(.horizontal, Tokens.Space.sm)
            .padding(.vertical, Tokens.Space.xs)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    /// Section header label — small caps, secondary, tracking.
    func sectionLabel() -> some View {
        self
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Tokens.Text.secondary)
    }
}

/// Indigo-tinted backdrop gradient — barely visible depth that lifts the detail pane
/// off the canvas. Honors the No-Shadow Rule (gradient is tonal, not lifted).
struct PremiumBackdrop: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Tokens.Palette.accent.opacity(0.04), location: 0),
                .init(color: Tokens.Surface.background.opacity(1), location: 0.55),
                .init(color: Tokens.Surface.background.opacity(1), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// A "deep inset" container — one tonal step darker than the elevated card it sits in.
/// Used for the masked value field on the detail hero.
extension View {
    func deepInset(radius: CGFloat = Tokens.Radius.sm) -> some View {
        self
            .background(
                Tokens.Surface.background.opacity(0.7),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Tokens.Surface.separator.opacity(0.4), lineWidth: Tokens.Stroke.hairline)
            )
    }
}
