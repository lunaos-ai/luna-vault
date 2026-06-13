import SwiftUI

struct CloudSubscriptionSection: View {
    @EnvironmentObject var cloudAuth: CloudAuthService

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Subscription")
                .font(.headline)

            if cloudAuth.subscriptionStatus != "active" {
                VStack(spacing: Tokens.Space.md) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Tokens.Palette.warm)
                        Text("Upgrade to Vibe Vault Pro")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    Text("Unlock encrypted cloud backups, automatic scheduled backups, and sync across all your devices.")
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)

                    Button {
                        // Show IAP sheet
                    } label: {
                        HStack {
                            Image(systemName: "cart")
                            Text("Subscribe - $2.99/month")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding()
                .glassCard(radius: Tokens.Radius.md, elevation: .resting)
            } else {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Tokens.Status.success)
                    Text("Vibe Vault Pro Active")
                        .font(.subheadline)
                    Spacer()
                    Button {
                        // Manage subscription
                    } label: {
                        Text("Manage")
                            .font(.caption)
                    }
                    .buttonStyle(.glass)
                }
                .padding()
                .glassCard(radius: Tokens.Radius.md, elevation: .resting)
            }
        }
    }
}
