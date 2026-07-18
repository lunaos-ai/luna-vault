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
        .onChange(of: env.openVercel) { _, open in
            if open {
                tab = .vercel
                env.openVercel = false
            }
        }
        .onChange(of: env.openPushci) { _, open in
            if open {
                tab = .pushci
                env.openPushci = false
            }
        }
        .onChange(of: env.openCloudflare) { _, open in
            if open {
                tab = .cloudflare
                // MainWindow also clears; keep hub in sync when already selected
            }
        }
    }
}
