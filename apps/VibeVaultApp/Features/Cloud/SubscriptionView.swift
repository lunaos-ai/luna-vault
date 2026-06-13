import Foundation
import SwiftUI
import StoreKit

// MARK: - Subscription View

struct SubscriptionView: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            // Header
            VStack(spacing: Tokens.Space.md) {
                Image(systemName: "star.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Tokens.Palette.warm)

                Text("Vibe Vault Pro")
                    .font(.title.weight(.bold))

                Text("Unlock the full power of secure secret management")
                    .font(.subheadline)
                    .foregroundStyle(Tokens.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Tokens.Space.xxl)

            // Features
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                FeatureDetailRow(icon: "cloud.fill", title: "Cloud Backups", description: "Encrypted backups to the cloud")
                FeatureDetailRow(icon: "clock.arrow.circlepath", title: "Auto Backup", description: "Scheduled automatic backups")
                FeatureDetailRow(icon: "iphone", title: "Multi-Device", description: "Sync across all your devices")
                FeatureDetailRow(icon: "arrow.counterclockwise", title: "Restore", description: "Restore from any backup")
                FeatureDetailRow(icon: "wand.and.stars", title: "Priority Support", description: "Get help when you need it")
            }
            .padding()
            .background(Tokens.Surface.elevated.opacity(0.3))
            .cornerRadius(Tokens.Radius.md)
            .padding(.horizontal, Tokens.Space.xl)

            Spacer()

            // Products
            VStack(spacing: Tokens.Space.md) {
                if iapManager.isLoading {
                    ProgressView()
                } else if iapManager.products.isEmpty {
                    Text("Products not available")
                        .foregroundStyle(Tokens.Text.secondary)
                } else {
                    ForEach(iapManager.products) { product in
                        ProductButton(product: product)
                    }
                }

                if let error = iapManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.danger)
                }

                Button {
                    Task {
                        await iapManager.restorePurchases()
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .padding(.top, Tokens.Space.sm)
            }
            .padding(.horizontal, Tokens.Space.xl)
            .padding(.bottom, Tokens.Space.xxl)
        }
        .frame(maxWidth: 500)
        .background(LiquidBackdrop())
    }
}

struct ProductButton: View {
    let product: Product
    @EnvironmentObject var iapManager: IAPManager

    var isYearly: Bool {
        product.id.contains("yearly")
    }

    var body: some View {
        Button {
            Task {
                _ = await iapManager.purchase(product)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .fontWeight(.semibold)
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .fontWeight(.bold)

                    if isYearly {
                        Text("Save 33%")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Tokens.Palette.mint)
                            .cornerRadius(4)
                    } else {
                        Text("Monthly")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Tokens.Palette.accent, Tokens.Palette.accent.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .foregroundStyle(.white)
            .cornerRadius(Tokens.Radius.md)
        }
        .buttonStyle(.plain)
    }
}

struct FeatureDetailRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Tokens.Palette.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
    }
}

extension Product: Identifiable {
    public var id: String { self.id }
}
