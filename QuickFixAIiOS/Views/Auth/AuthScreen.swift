import SwiftUI
import GoogleSignIn

/// Full-screen auth gate shown to unauthenticated users.
/// Shows branding + two sign-in options; email form presented as a sheet.
struct AuthScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var showEmailAuth = false

    var body: some View {
        ZStack {
            // Full-bleed gradient
            LinearGradient(
                colors: [Color.brandBlue, Color.brand],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + branding
                VStack(spacing: 18) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 80, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)

                    HStack(spacing: 0) {
                        Text("QuickFix")
                            .font(.system(size: 44, weight: .heavy))
                            .foregroundStyle(.white)
                        Text(" AI")
                            .font(.system(size: 44, weight: .heavy))
                            .foregroundStyle(.yellow)
                    }

                    Text("Your AI-powered home repair guide")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                Spacer()
                Spacer()

                // Sign-in buttons
                VStack(spacing: 14) {
                    Button {
                        Task { await authVM.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            GoogleGIcon()
                                .frame(width: 40, height: 40)
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.35), lineWidth: 1.5)
                        )
                        .cornerRadius(14)
                    }
                    .disabled(authVM.isLoading)

                    Button {
                        showEmailAuth = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                            Text("Continue with Email")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.35), lineWidth: 1.5)
                        )
                        .cornerRadius(14)
                    }
                    .disabled(authVM.isLoading)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            AuthView()
                .environment(authVM)
        }
    }
}

/// Renders the real Google "G" logo via GIDSignInButton (.iconOnly, non-interactive).
private struct GoogleGIcon: UIViewRepresentable {
    func makeUIView(context: Context) -> GIDSignInButton {
        let btn = GIDSignInButton()
        btn.style = .iconOnly
        btn.colorScheme = .light
        btn.isUserInteractionEnabled = false
        return btn
    }
    func updateUIView(_ uiView: GIDSignInButton, context: Context) {}
}
