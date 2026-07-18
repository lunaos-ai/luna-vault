import SwiftUI

struct ProvidersHubView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var tab: Tab = .cloudflare

    enum Tab: String, CaseIterable, Identifiable {
        case cloudflare, vercel, pushci
        var id: String { rawValue }
        var label: String {
            switch self {
            case .cloudflare: return "Cloudflare"
            case .vercel: return "Vercel"
            case .pushci: return "PushCI"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Tokens.Space.xxl)
            .padding(.top, Tokens.Space.lg)
            .padding(.bottom, Tokens.Space.sm)
            Group {
                switch tab {
                case .cloudflare: CloudflareSyncView()
                case .vercel: VercelSyncView()
                case .pushci: PushciSyncView()
                }
            }
        }
        .background(PremiumBackdrop())
        .navigationTitle("Providers")
        .onAppear { applyPendingTab() }
        .onChange(of: env.pendingProviderTab) { _, _ in applyPendingTab() }
    }

    private func applyPendingTab() {
        guard let raw = env.pendingProviderTab, let next = Tab(rawValue: raw) else { return }
        tab = next
        env.pendingProviderTab = nil
    }
}
