import SwiftUI

struct LoginView: View {
    @EnvironmentObject var cloudAuth: CloudAuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var confirmPassword = ""
    @State private var showPassword = false

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            // Close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Tokens.Text.secondary)
                }
                .buttonStyle(.borderless)
                .padding(.top, Tokens.Space.sm)
                .padding(.trailing, Tokens.Space.sm)
            }
            
            LoginHeaderView(isRegistering: isRegistering)

            LoginFormView(
                email: $email,
                password: $password,
                confirmPassword: $confirmPassword,
                showPassword: $showPassword,
                isRegistering: isRegistering
            )

            errorBanner

            actionButton

            toggleButton

            oauthDivider

            LoginOAuthButtons(cloudAuth: cloudAuth)

            Spacer()

            LoginFeaturesList()
        }
        .frame(maxWidth: 400)
        .background(LiquidBackdrop())
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = cloudAuth.lastError {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tokens.Status.warning)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Tokens.Status.warning)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.sm)
            .background(Tokens.Status.warning.opacity(0.1))
            .cornerRadius(Tokens.Radius.sm)
        }
    }

    private var actionButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if cloudAuth.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(isRegistering ? "Create Account" : "Sign In")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.md)
        }
        .buttonStyle(.glassProminent)
        .disabled(email.isEmpty || password.isEmpty || cloudAuth.isLoading)
        .padding(.horizontal, Tokens.Space.xl)
    }

    private var toggleButton: some View {
        Button {
            isRegistering.toggle()
            cloudAuth.lastError = nil
        } label: {
            Text(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Create one")
                .font(.subheadline)
                .foregroundStyle(Tokens.Palette.accent)
        }
        .buttonStyle(.borderless)
    }

    private var oauthDivider: some View {
        HStack(spacing: Tokens.Space.md) {
            Divider().frame(maxWidth: .infinity)
            Text("OR")
                .font(.caption)
                .foregroundStyle(Tokens.Text.tertiary)
            Divider().frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Tokens.Space.xl)
        .padding(.vertical, Tokens.Space.sm)
    }

    private func submit() async {
        if isRegistering {
            guard password == confirmPassword else {
                cloudAuth.lastError = "Passwords do not match"
                return
            }
            let success = await cloudAuth.register(email: email, password: password)
            if success {
                dismiss()
            }
        } else {
            let success = await cloudAuth.login(email: email, password: password)
            if success {
                dismiss()
            }
        }
    }
}
