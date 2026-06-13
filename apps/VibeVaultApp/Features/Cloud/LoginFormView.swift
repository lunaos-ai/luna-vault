import SwiftUI

struct LoginFormView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var showPassword: Bool
    let isRegistering: Bool

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            // Email field
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                TextField("your@email.com", text: $email)
                    .textFieldStyle(.roundedBorder)
            }

            // Password field
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)

                HStack {
                    if showPassword {
                        TextField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(Tokens.Text.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Confirm password (registration only)
            if isRegistering {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text("Confirm Password")
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.xl)
    }
}
