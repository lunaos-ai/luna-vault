import SwiftUI

struct LoginFeaturesList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            FeatureRow(icon: "cloud", text: "Encrypted cloud backups")
            FeatureRow(icon: "clock.arrow.circlepath", text: "Automatic scheduled backups")
            FeatureRow(icon: "iphone", text: "Sync across all your devices")
            FeatureRow(icon: "arrow.counterclockwise", text: "Easy restore from any backup")
        }
        .padding()
        .background(Tokens.Surface.elevated.opacity(0.3))
        .cornerRadius(Tokens.Radius.md)
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.bottom, Tokens.Space.lg)
    }
}
