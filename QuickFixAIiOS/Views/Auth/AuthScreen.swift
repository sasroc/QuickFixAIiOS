import SwiftUI
import GoogleSignIn
import AuthenticationServices

/// Full-screen auth gate shown to unauthenticated users.
/// Shows branding + two sign-in options; email form presented as a sheet.
struct AuthScreen: View {
    var startInSignUpMode: Bool = false

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
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 120)
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
                    SignInWithAppleButton(.continue) { request in
                        authVM.prepareAppleSignInRequest(request)
                    } onCompletion: { result in
                        Task { await authVM.handleAppleSignInResult(result) }
                    }
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .cornerRadius(14)
                    .disabled(authVM.isLoading)

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
                                .frame(width: 40, height: 40)
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
            AuthView(initialMode: startInSignUpMode ? .signUp : .signIn)
                .environment(authVM)
        }
    }
}

/// Renders the Google "G" logo by loading the PNG directly from the SDK bundle.
/// Pure SwiftUI — offset/padding modifiers work correctly.
private struct GoogleGIcon: View {
    var body: some View {
        if let img = googleLogoImage() {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .offset(y: -2)
        }
    }

    private func googleLogoImage() -> UIImage? {
        let bundleName = "GoogleSignIn_GoogleSignIn"
        let resourceBundle: Bundle?
        if let path = Bundle.main.path(forResource: bundleName, ofType: "bundle") {
            resourceBundle = Bundle(path: path)
        } else {
            let fb = Bundle(for: GIDSignIn.self)
            if let path = fb.path(forResource: bundleName, ofType: "bundle") {
                resourceBundle = Bundle(path: path)
            } else {
                resourceBundle = nil
            }
        }
        guard let url = resourceBundle?.url(forResource: "google", withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
