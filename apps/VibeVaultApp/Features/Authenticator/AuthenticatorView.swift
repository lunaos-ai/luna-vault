import SwiftUI
import VaultCore

struct AuthenticatorView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selectedID: UUID?
    @State private var query = ""
    @State private var showAdd = false
    @State private var convertName: String?
    @State private var initialInput: String?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                header
                TextField("Search issuer or account", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.bottom, Tokens.Space.sm)
                List(selection: $selectedID) {
                    Section("Accounts") {
                        if filteredAccounts.isEmpty {
                            Text("No standalone authenticators")
                                .foregroundStyle(Tokens.Text.secondary)
                        }
                        ForEach(filteredAccounts) { account in
                            AuthenticatorRow(account: account).tag(account.id)
                        }
                    }
                    if !attachedSecrets.isEmpty {
                        Section("Attached to secrets") {
                            ForEach(attachedSecrets) { secret in
                                HStack {
                                    Image(systemName: "link")
                                    Text(secret.name).font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Text("Attached").font(.caption).foregroundStyle(Tokens.Text.secondary)
                                    Button("Convert") { convertName = secret.name }
                                        .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 280, idealWidth: 310, maxWidth: 380)

            if let account = selectedAccount {
                AuthenticatorDetailView(account: account).environmentObject(env)
            } else {
                ContentUnavailableView(
                    "Nothing selected", systemImage: "number.square",
                    description: Text("Pick an authenticator, or add a new one.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Authenticator")
        .sheet(isPresented: $showAdd) {
            AddAuthenticatorSheet(initialInput: initialInput).environmentObject(env)
        }
        .onAppear { env.refreshAuthenticators() }
        .onAppear { openPendingHandoff() }
        .onChange(of: env.pendingAuthenticatorInput) { _, _ in openPendingHandoff() }
        .confirmationDialog(
            "Convert attached authenticator?", isPresented: Binding(
                get: { convertName != nil }, set: { if !$0 { convertName = nil } }
            )
        ) {
            if let convertName {
                Button("Convert") {
                    let name = convertName
                    self.convertName = nil
                    Task { await env.convertAttachedAuthenticator(secretName: name) }
                }
            }
            Button("Cancel", role: .cancel) { convertName = nil }
        } message: {
            Text("The credential stays in the vault. Its MFA seed moves to a standalone authenticator account.")
        }
        .onChange(of: env.authenticatorAccounts) { _, accounts in
            if let selectedID, !accounts.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
        }
    }

    private func openPendingHandoff() {
        guard let input = env.pendingAuthenticatorInput else { return }
        initialInput = input
        env.pendingAuthenticatorInput = nil
        showAdd = true
    }

    private var header: some View {
        HStack {
            Text("\(env.authenticatorAccounts.count) account\(env.authenticatorAccounts.count == 1 ? "" : "s")")
                .font(.headline)
            Spacer()
            Button { showAdd = true } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .help("Add authenticator")
                .accessibilityLabel("Add authenticator")
        }
        .padding(Tokens.Space.md)
    }

    private var filteredAccounts: [AuthenticatorAccountMetadata] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return env.authenticatorAccounts }
        return env.authenticatorAccounts.filter {
            $0.issuer.localizedCaseInsensitiveContains(value)
                || $0.accountName.localizedCaseInsensitiveContains(value)
        }
    }

    private var attachedSecrets: [Secret] {
        env.secrets.filter(\.hasTOTP).filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedAccount: AuthenticatorAccountMetadata? {
        env.authenticatorAccounts.first { $0.id == selectedID }
    }
}

private struct AuthenticatorRow: View {
    let account: AuthenticatorAccountMetadata
    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            IssuerIcon(name: account.issuer, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.issuer).font(.system(.body, design: .monospaced))
                Text(account.accountName).font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
            if account.favorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                    .accessibilityLabel("Favorite")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.issuer), \(account.accountName)")
    }
}
