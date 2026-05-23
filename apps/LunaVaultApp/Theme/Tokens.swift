import SwiftUI

enum Tokens {
    enum Color {
        static let primary = SwiftUI.Color(red: 0x7C / 255, green: 0x3A / 255, blue: 0xED / 255)   // #7C3AED
        static let cta = SwiftUI.Color(red: 0xF9 / 255, green: 0x77 / 255, blue: 0x16 / 255)        // #F97316
        static let surface = SwiftUI.Color(NSColor.windowBackgroundColor)
        static let surfaceElevated = SwiftUI.Color(NSColor.underPageBackgroundColor)
        static let textPrimary = SwiftUI.Color(NSColor.labelColor)
        static let textSecondary = SwiftUI.Color(NSColor.secondaryLabelColor)
        static let success = SwiftUI.Color.green
        static let warning = SwiftUI.Color.orange
        static let danger = SwiftUI.Color.red
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
    }

    enum FontName {
        static let body = "Inter"
        static let mono = "JetBrains Mono"
    }
}

extension View {
    func cardSurface() -> some View {
        self
            .padding(Tokens.Space.lg)
            .background(Tokens.Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }
}
