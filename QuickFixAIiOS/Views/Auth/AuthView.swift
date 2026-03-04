import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var isLogin        = true
    @State private var email          = ""
    @State private var password       = ""
    @State private var confirmPass    = ""
    @State private var displayName    = ""
    @State private var showPassword   = false
    @State private var agreedToTerms  = false
    @State private var showTerms      = false
    @State private var showPrivacy    = false
    @State private var shakeError     = false

    private var passwordsMatch: Bool? {
        guard isLogin || confirmPass.isEmpty else {
            return password == confirmPass
        }
        return nil
    }

    private var canSubmit: Bool {
        let emailOK    = !email.isEmpty
        let passOK     = password.count >= 6
        let confirmOK  = isLogin || password == confirmPass
        let termsOK    = isLogin || agreedToTerms
        return emailOK && passOK && confirmOK && termsOK
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 80)
                        Text(isLogin ? "Welcome Back" : "Create Account")
                            .font(.title).fontWeight(.bold)
                        Text(isLogin ? "Sign in to continue fixing things" : "Join thousands of homeowners")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    // Toggle
                    Picker("Mode", selection: $isLogin) {
                        Text("Sign In").tag(true)
                        Text("Sign Up").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Form
                    VStack(spacing: 14) {
                        if !isLogin {
                            TextField("Display Name (optional)", text: $displayName)
                                .textContentType(.name)
                                .textFieldStyle(.roundedBorder)
                        }

                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textFieldStyle(.roundedBorder)

                        // Password field
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .textContentType(isLogin ? .password : .newPassword)

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        if !isLogin {
                            HStack {
                                SecureField("Confirm Password", text: $confirmPass)
                                    .textContentType(.newPassword)

                                if let match = passwordsMatch {
                                    Image(systemName: match ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(match ? .green : .red)
                                }
                            }
                            .textFieldStyle(.roundedBorder)

                            // Terms checkbox
                            HStack(alignment: .top, spacing: 8) {
                                Button {
                                    agreedToTerms.toggle()
                                } label: {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(agreedToTerms ? Color.brand : Color.secondary)
                                }

                                Text("I agree to the ")
                                    .font(.footnote)
                                + Text("Terms of Service")
                                    .font(.footnote).foregroundColor(.brand)
                                + Text(" and ")
                                    .font(.footnote)
                                + Text("Privacy Policy")
                                    .font(.footnote).foregroundColor(.brand)
                            }
                            .onTapGesture(count: 1, perform: {})   // allows sub-buttons to work
                            .overlay(
                                HStack {
                                    Spacer().frame(width: 28)
                                    HStack(spacing: 0) {
                                        Color.clear
                                            .frame(width: 100)
                                            .contentShape(Rectangle())
                                            .onTapGesture { showTerms = true }
                                        Color.clear
                                            .frame(width: 30)
                                        Color.clear
                                            .frame(width: 90)
                                            .contentShape(Rectangle())
                                            .onTapGesture { showPrivacy = true }
                                        Spacer()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Error
                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .shake(trigger: shakeError)
                    }

                    // Submit button
                    Button {
                        Task { await submit() }
                    } label: {
                        if authVM.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isLogin ? "Sign In" : "Create Account")
                        }
                    }
                    .primaryButtonStyle(disabled: !canSubmit || authVM.isLoading)
                    .disabled(!canSubmit || authVM.isLoading)
                    .padding(.horizontal)

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                        Text("or").font(.footnote).foregroundStyle(.secondary)
                        Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                    }
                    .padding(.horizontal)

                    // Google Sign-In
                    GoogleSignInCustomButton {
                        Task { await authVM.signInWithGoogle() }
                    }
                    .padding(.horizontal)

                    // Apple Sign-In
                    SignInWithAppleButton(.continue) { request in
                        authVM.prepareAppleSignInRequest(request)
                    } onCompletion: { result in
                        Task { await authVM.handleAppleSignInResult(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .cornerRadius(4)
                    .disabled(authVM.isLoading)
                    .padding(.horizontal)

                    // Forgot password
                    if isLogin {
                        Button {
                            Task { await forgotPassword() }
                        } label: {
                            Text("Forgot Password?")
                                .font(.footnote)
                                .foregroundStyle(Color.brand)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showTerms)   { TermsView() }
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
            .onChange(of: authVM.isSignedIn) { _, signedIn in
                if signedIn { dismiss() }
            }
        }
    }

    // MARK: - Actions

    private func submit() async {
        if isLogin {
            await authVM.signIn(email: email, password: password)
        } else {
            await authVM.signUp(email: email, password: password, displayName: displayName)
        }
        if authVM.errorMessage != nil { shakeError = true; shakeError = false }
    }

    private func forgotPassword() async {
        guard !email.isEmpty else {
            authVM.errorMessage = "Enter your email address first."
            return
        }
        let sent = await authVM.sendPasswordReset(to: email)
        if sent {
            authVM.errorMessage = nil
            // Show a success alert
        }
    }
}

// MARK: - Custom Google Sign-In button

/// Loads the Google G logo directly from the GoogleSignIn SDK bundle and renders
/// a button that matches Google's branding while giving us precise layout control.
private struct GoogleSignInCustomButton: View {
    let action: () -> Void

    /// The same logo the SDK uses, loaded from its resource bundle.
    private var googleLogo: Image? {
        guard let bundle = googleSignInBundle(),
              let url = bundle.url(forResource: "google", withExtension: "png"),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let logo = googleLogo {
                    logo
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .offset(y: -5)
                }
                Text("Sign in with Google")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(white: 0.25))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .gray.opacity(0.4), radius: 2, x: 0, y: 2)
        }
    }

    private func googleSignInBundle() -> Bundle? {
        let bundleName = "GoogleSignIn_GoogleSignIn"
        if let mainPath = Bundle.main.path(forResource: bundleName, ofType: "bundle") {
            return Bundle(path: mainPath)
        }
        let classBundle = Bundle(for: GIDSignIn.self)
        if let classPath = classBundle.path(forResource: bundleName, ofType: "bundle") {
            return Bundle(path: classPath)
        }
        return nil
    }
}
