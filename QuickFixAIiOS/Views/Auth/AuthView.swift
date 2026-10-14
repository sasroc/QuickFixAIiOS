import SwiftUI

/// Email + password sign-in / sign-up form, presented as a sheet from
/// `AuthScreen`'s "Continue with Email". Apple and Google live on AuthScreen.
struct AuthView: View {
    enum Mode { case signIn, signUp }

    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var isLogin: Bool

    init(initialMode: Mode = .signIn) {
        _isLogin = State(initialValue: initialMode == .signIn)
    }

    private enum Field { case name, email, password, confirm }

    @State private var email          = ""
    @State private var password       = ""
    @State private var confirmPass    = ""
    @State private var displayName    = ""
    @State private var showPassword   = false
    @State private var agreedToTerms  = false
    @State private var showTerms      = false
    @State private var showPrivacy    = false
    @State private var shakeCount     = 0
    @State private var resetSentTo: String? = nil
    @FocusState private var focused: Field?

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
                VStack(alignment: .leading, spacing: 24) {
                    header
                    modeToggle
                    form
                    messages
                    submitButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.25), value: isLogin)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.cardBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showTerms)   { TermsView() }
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
            .onChange(of: authVM.isSignedIn) { _, signedIn in
                if signedIn { dismiss() }
            }
            .onChange(of: isLogin) { _, _ in
                authVM.errorMessage = nil
                resetSentTo = nil
            }
        }
        .background(Color.cardBackground)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isLogin ? "Welcome back" : "Create your account")
                .font(.system(size: 30, weight: .bold))
                .contentTransition(.opacity)
            Text(isLogin ? "Sign in to pick up where you left off." : "It takes less than a minute.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 4) {
            toggleOption("Sign In", selected: isLogin) { isLogin = true }
            toggleOption("Sign Up", selected: !isLogin) { isLogin = false }
        }
        .padding(4)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func toggleOption(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.cardBackground)
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Form

    private var form: some View {
        VStack(spacing: 14) {
            if !isLogin {
                inputField(icon: "person", field: .name) {
                    TextField("Name (optional)", text: $displayName)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .onSubmit { focused = .email }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            inputField(icon: "envelope", field: .email) {
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
            }

            VStack(alignment: .leading, spacing: 8) {
                inputField(icon: "lock", field: .password) {
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textContentType(isLogin ? .password : .newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(isLogin ? .go : .next)
                    .onSubmit {
                        if isLogin { Task { await submit() } } else { focused = .confirm }
                    }

                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }

                if isLogin {
                    HStack {
                        Spacer()
                        Button("Forgot password?") { Task { await forgotPassword() } }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.brand)
                    }
                } else {
                    Text("At least 6 characters")
                        .font(.footnote)
                        .foregroundStyle(password.isEmpty || password.count >= 6 ? Color.secondary : Color.red)
                        .padding(.leading, 4)
                }
            }

            if !isLogin {
                inputField(icon: "lock.rotation", field: .confirm) {
                    SecureField("Confirm password", text: $confirmPass)
                        .textContentType(.newPassword)
                        .submitLabel(.done)
                        .onSubmit { focused = nil }

                    if let match = passwordsMatch {
                        Image(systemName: match ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(match ? Color.success : Color.red)
                            .accessibilityLabel(match ? "Passwords match" : "Passwords don't match")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                termsCheckbox
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
    }

    private func inputField<Content: View>(
        icon: String,
        field: Field,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(focused == field ? Color.brand : Color.secondary)
                .frame(width: 20)
            content()
                .font(.system(size: 17))
                .focused($focused, equals: field)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(focused == field ? Color.brand : Color.secondary.opacity(0.18),
                        lineWidth: focused == field ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: focused)
    }

    private var termsCheckbox: some View {
        HStack(alignment: .top, spacing: 10) {
            Button { agreedToTerms.toggle() } label: {
                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(agreedToTerms ? Color.brand : Color.secondary)
            }
            .accessibilityLabel("Agree to the Terms of Service and Privacy Policy")
            .accessibilityAddTraits(agreedToTerms ? .isSelected : [])

            (Text("I agree to the ")
                + Text("[Terms of Service](quickfixai-legal://terms)")
                + Text(" and ")
                + Text("[Privacy Policy](quickfixai-legal://privacy)"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .tint(Color.brand)
                .environment(\.openURL, OpenURLAction { url in
                    if url.host == "terms" { showTerms = true }
                    if url.host == "privacy" { showPrivacy = true }
                    return .handled
                })
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messages: some View {
        if let error = authVM.errorMessage {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .modifier(ShakeEffect(animatableData: CGFloat(shakeCount)))
        } else if let sentTo = resetSentTo {
            Label("Password reset email sent to \(sentTo).", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(Color.success)
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        let enabled = canSubmit && !authVM.isLoading
        return Button {
            Task { await submit() }
        } label: {
            ZStack {
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(isLogin ? "Sign In" : "Create Account")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if enabled || authVM.isLoading {
                    LinearGradient(colors: [Color.brandBlue, Color.brand], startPoint: .leading, endPoint: .trailing)
                } else {
                    Color.gray.opacity(0.35)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: enabled ? Color.brand.opacity(0.3) : .clear, radius: 10, y: 4)
        }
        .disabled(!enabled)
    }

    // MARK: - Actions

    private func submit() async {
        guard canSubmit, !authVM.isLoading else { return }
        focused = nil
        resetSentTo = nil
        if isLogin {
            await authVM.signIn(email: email, password: password)
        } else {
            await authVM.signUp(email: email, password: password, displayName: displayName)
        }
        if authVM.errorMessage != nil {
            withAnimation(.linear(duration: 0.4)) { shakeCount += 1 }
        }
    }

    private func forgotPassword() async {
        resetSentTo = nil
        guard !email.isEmpty else {
            authVM.errorMessage = "Enter your email address first."
            focused = .email
            return
        }
        if await authVM.sendPasswordReset(to: email) {
            authVM.errorMessage = nil
            resetSentTo = email
        }
    }
}

// MARK: - Shake

/// Horizontal shake; each increment of `animatableData` plays one shake.
private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
