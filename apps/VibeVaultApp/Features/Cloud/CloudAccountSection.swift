import SwiftUI

struct CloudAccountSection: View {
    @EnvironmentObject var cloudAuth: CloudAuthService
    @Binding var showLogin: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Account")
                .font(.headline)

            if cloudAuth.isAuthenticated {
                HStack {
                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        Text(cloudAuth.userEmail ?? "")
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            Circle()
                                .fill(cloudAuth.subscriptionStatus == "active" ? Tokens.Status.success : Tokens.Text.tertiary)
                                .frame(width: 8, height: 8)
                            Text(cloudAuth.subscriptionStatus.capitalized)
                                .font(.caption)
                                .foregroundStyle(Tokens.Text.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        cloudAuth.logout()
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                            .font(.caption)
                    }
                    .buttonStyle(.glass(tint: Tokens.Status.danger))
                }
                .padding()
                .glassCard(radius: Tokens.Radius.md, elevation: .resting)
            } else {
                Button {
                    showLogin = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Sign in to enable cloud features")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                }
                .buttonStyle(.glass)
            }
        }
    }
}
