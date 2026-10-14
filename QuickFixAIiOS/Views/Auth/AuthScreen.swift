import SwiftUI
import GoogleSignIn
import AuthenticationServices

/// Full-screen auth gate shown to unauthenticated users.
/// Branded hero with what the app does, and a bottom card with the sign-in
/// options; the email form is presented as a sheet.
struct AuthScreen: View {
    var startInSignUpMode: Bool = false

    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.colorScheme)       private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showEmailAuth = false
    @State private var showTerms     = false
    @State private var showPrivacy   = false
    @State private var appeared      = false

    private let demos: [RepairDemo] = [
        RepairDemo(icon: "drop.fill",             problem: "Leaky kitchen faucet",   fix: "Replace the worn cartridge",  steps: 6, time: "25 min"),
        RepairDemo(icon: "bolt.fill",             problem: "Outlet stopped working", fix: "Reset the GFCI and test it",  steps: 4, time: "10 min"),
        RepairDemo(icon: "fan.fill",              problem: "AC blowing warm air",    fix: "Clean the condenser coils",   steps: 7, time: "45 min"),
        RepairDemo(icon: "hammer.fill",           problem: "Hole in the drywall",    fix: "Patch, sand and paint",       steps: 5, time: "1 hr"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            background

            VStack(spacing: 0) {
                hero
                    .frame(maxHeight: .infinity)

                signInCard
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { appeared = true }
        .sheet(isPresented: $showEmailAuth) {
            AuthView(initialMode: startInSignUpMode ? .signUp : .signIn)
                .environment(authVM)
        }
        .sheet(isPresented: $showTerms)   { TermsView() }
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
    }

    // MARK: - Background

    /// Brand gradient with slowly drifting light blooms. Static under Reduce Motion.
    private var background: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.11, green: 0.31, blue: 0.85), Color.brandBlue, Color.brand],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                bloom(color: Color(red: 0.55, green: 0.85, blue: 1.0), size: 360, opacity: 0.35,
                      x: -120 + 60 * sin(t / 6), y: -280 + 40 * cos(t / 5))
                bloom(color: Color.brand, size: 320, opacity: 0.45,
                      x: 150 + 50 * cos(t / 7), y: -60 + 70 * sin(t / 6))
                bloom(color: Color(red: 0.45, green: 0.35, blue: 0.95), size: 300, opacity: 0.30,
                      x: -140 + 50 * sin(t / 8), y: 120 + 50 * cos(t / 7))
            }
        }
        .ignoresSafeArea()
    }

    private func bloom(color: Color, size: CGFloat, opacity: Double, x: Double, y: Double) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 60)
            .offset(x: x, y: y)
    }

    // MARK: - Hero

    /// Falls back to a compact hero (no demo card) on short screens.
    private var hero: some View {
        ViewThatFits(in: .vertical) {
            heroContent(showDemo: true)
            heroContent(showDemo: false)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
    }

    private func heroContent(showDemo: Bool) -> some View {
        VStack(spacing: 26) {
            VStack(spacing: 16) {
                GlowingLogo(animate: appeared && !reduceMotion)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.6), value: appeared)

                VStack(spacing: 8) {
                    ShimmerText(text: "QuickFix AI", animate: appeared && !reduceMotion)
                    Text("Snap it. Fix it. Done.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.6).delay(0.15), value: appeared)
            }

            if showDemo {
                LiveDemoCard(demos: demos, animate: !reduceMotion)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3), value: appeared)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sign-in Card

    private var signInCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Get started")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Sign in or create a free account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            SignInWithAppleButton(.continue) { request in
                authVM.prepareAppleSignInRequest(request)
            } onCompletion: { result in
                Task { await authVM.handleAppleSignInResult(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .id(colorScheme) // Apple's button doesn't restyle in place
            .disabled(authVM.isLoading)

            providerButton(title: "Continue with Google") {
                GoogleGIcon()
                    .frame(width: 20, height: 20)
            } action: {
                Task { await authVM.signInWithGoogle() }
            }

            providerButton(title: "Continue with Email") {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.brand)
                    .frame(width: 20, height: 20)
            } action: {
                showEmailAuth = true
            }

            if let error = authVM.errorMessage, !showEmailAuth {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                    .transition(.opacity)
            }

            legalText
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.12), radius: 24, y: -4)
        )
        .overlay {
            if authVM.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.cardBackground.opacity(0.6))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous))
            }
        }
        .offset(y: appeared ? 0 : 60)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.1), value: appeared)
        .animation(.easeInOut(duration: 0.2), value: authVM.errorMessage)
    }

    private func providerButton<Icon: View>(
        title: String,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(authVM.isLoading)
    }

    private var legalText: some View {
        (Text("By continuing, you agree to our ")
            + Text("[Terms](quickfixai-legal://terms)").underline()
            + Text(" and ")
            + Text("[Privacy Policy](quickfixai-legal://privacy)").underline()
            + Text("."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .tint(.secondary)
            .multilineTextAlignment(.center)
            .environment(\.openURL, OpenURLAction { url in
                if url.host == "terms" { showTerms = true }
                if url.host == "privacy" { showPrivacy = true }
                return .handled
            })
    }
}

// MARK: - Auth hero pieces

private struct RepairDemo {
    let icon: String
    let problem: String
    let fix: String
    let steps: Int
    let time: String
}

/// App logo tile with a soft pulsing halo.
private struct GlowingLogo: View {
    let animate: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.25))
                .frame(width: 128, height: 128)
                .blur(radius: 24)
                .scaleEffect(pulse ? 1.15 : 0.9)
                .opacity(pulse ? 0.9 : 0.5)

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .padding(8)
                .frame(width: 84, height: 84)
                .background(Color(red: 17 / 255, green: 24 / 255, blue: 42 / 255)) // logo's own navy
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                .offset(y: pulse ? -3 : 3)
        }
        .accessibilityHidden(true)
        .onAppear { startPulse() }
        .onChange(of: animate) { _, _ in startPulse() }
    }

    private func startPulse() {
        guard animate, !pulse else { return }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { pulse = true }
    }
}

/// White title with a light sheen that sweeps across every few seconds.
private struct ShimmerText: View {
    let text: String
    let animate: Bool

    var body: some View {
        let label = Text(text)
            .font(.system(size: 38, weight: .heavy, design: .rounded))

        label
            .foregroundStyle(.white)
            .overlay {
                if animate {
                    TimelineView(.animation) { context in
                        // 3.5s cycle: sweep for the first 1.2s, then rest.
                        let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.5)
                        let progress = min(cycle / 1.2, 1)
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [.clear, Color(red: 0.75, green: 1.0, blue: 0.95).opacity(0.9), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 0.45)
                            .offset(x: -geo.size.width * 0.45 + (geo.size.width * 1.45) * progress)
                        }
                    }
                    .mask(label)
                    .allowsHitTesting(false)
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Glass card that cycles through example diagnoses to show what the app does.
private struct LiveDemoCard: View {
    let demos: [RepairDemo]
    let animate: Bool

    @State private var index = 0
    @State private var progress: CGFloat = 0
    @State private var livePulse = false

    private var demo: RepairDemo { demos[index] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("AI Diagnosis", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.55, green: 1.0, blue: 0.75))
                        .frame(width: 7, height: 7)
                        .opacity(livePulse ? 1 : 0.35)
                    Text(progress < 1 ? "Analyzing" : "Fix ready")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .contentTransition(.opacity)
                }
            }

            HStack(spacing: 14) {
                Image(systemName: demo.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 3) {
                    Text(demo.problem)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(demo.fix)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .id(index)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                Spacer(minLength: 0)
            }
            .clipped()

            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule()
                            .fill(LinearGradient(colors: [.white, Color(red: 0.6, green: 1.0, blue: 0.85)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 5)

                HStack(spacing: 8) {
                    chip("list.number", "\(demo.steps) steps")
                    chip("clock", demo.time)
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(demos.indices, id: \.self) { i in
                            Capsule()
                                .fill(.white.opacity(i == index ? 0.95 : 0.3))
                                .frame(width: i == index ? 14 : 5, height: 5)
                        }
                    }
                }
                .opacity(progress < 1 ? 0.55 : 1)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial.opacity(0.55))
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .environment(\.colorScheme, .dark) // keep the glass light-on-dark in both modes
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example: \(demo.problem). Fix: \(demo.fix), \(demo.steps) steps, \(demo.time).")
        .task(id: animate) { await run() }
    }

    private func chip(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
    }

    /// Fill the bar, hold on the result, then slide to the next example.
    private func run() async {
        guard animate else {
            progress = 1
            return
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { livePulse = true }
        while !Task.isCancelled {
            progress = 0
            withAnimation(.easeInOut(duration: 1.6)) { progress = 1 }
            try? await Task.sleep(for: .seconds(3.4))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                index = (index + 1) % demos.count
            }
            try? await Task.sleep(for: .seconds(0.35))
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
