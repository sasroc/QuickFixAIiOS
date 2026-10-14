import SwiftUI

struct PostAuthOnboardingView: View {
    @Environment(AuthViewModel.self) private var authVM

    @Environment(UserViewModel.self) private var userVM

    @State private var userHomeType   = ""
    @State private var userDIYLevel   = ""
    @State private var userRepairType = ""

    @State private var step: OnboardingStep = .welcome
    @State private var animateEntrance = false
    @State private var goingBack = false

    private enum OnboardingStep {
        case welcome, homeType, skillLevel, repairType, personalizing, summary, ahaDemo
    }

    private var firstName: String {
        let name = authVM.firebaseUser?.displayName ?? ""
        return name.components(separatedBy: " ").first.flatMap { $0.isEmpty ? nil : $0 } ?? "there"
    }

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeStepView(firstName: firstName, animate: $animateEntrance) {
                    advance(to: .homeType)
                }
                .transition(stepTransition)

            case .homeType:
                QuestionStepView(
                    progress: 1/3.0,
                    stepLabel: "Step 1 of 3",
                    question: "What type of home do you have?",
                    options: homeTypeOptions,
                    selectedValue: $userHomeType,
                    onBack: { retreat(to: .welcome) },
                    onAdvance: { advance(to: .skillLevel) }
                )
                .transition(stepTransition)

            case .skillLevel:
                QuestionStepView(
                    progress: 2/3.0,
                    stepLabel: "Step 2 of 3",
                    question: "How would you describe your DIY skills?",
                    options: skillLevelOptions,
                    selectedValue: $userDIYLevel,
                    onBack: { retreat(to: .homeType) },
                    onAdvance: { advance(to: .repairType) }
                )
                .transition(stepTransition)

            case .repairType:
                QuestionStepView(
                    progress: 3/3.0,
                    stepLabel: "Step 3 of 3",
                    question: "What repairs do you deal with most?",
                    options: repairTypeOptions,
                    selectedValue: $userRepairType,
                    onBack: { retreat(to: .skillLevel) },
                    onAdvance: { advance(to: .personalizing) }
                )
                .transition(stepTransition)

            case .personalizing:
                PersonalizingStepView {
                    advance(to: .summary)
                }
                .transition(stepTransition)

            case .summary:
                SummaryStepView(
                    homeType: userHomeType,
                    diyLevel: userDIYLevel,
                    repairType: userRepairType,
                    onComplete: { advance(to: .ahaDemo) }
                )
                .transition(stepTransition)

            case .ahaDemo:
                AhaDemoStepView(
                    repairType: userRepairType,
                    onComplete: {
                        Task {
                            await userVM.completeOnboarding(
                                homeType: userHomeType,
                                diyLevel: userDIYLevel,
                                repairType: userRepairType
                            )
                        }
                    }
                )
                .transition(stepTransition)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { animateEntrance = true }
        }
    }

    // MARK: - Navigation

    private var stepTransition: AnyTransition {
        goingBack
            ? .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal:   .move(edge: .trailing).combined(with: .opacity)
              )
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
              )
    }

    private func advance(to next: OnboardingStep) {
        goingBack = false
        withAnimation(.easeInOut(duration: 0.4)) { step = next }
    }

    private func retreat(to prev: OnboardingStep) {
        goingBack = true
        withAnimation(.easeInOut(duration: 0.4)) { step = prev }
    }

    // MARK: - Question Data

    private let homeTypeOptions: [OptionItem] = [
        OptionItem(value: "house",     label: "House",      subtitle: nil, icon: "house.fill"),
        OptionItem(value: "apartment", label: "Apartment",  subtitle: nil, icon: "building.2.fill"),
        OptionItem(value: "condo",     label: "Condo",      subtitle: nil, icon: "building.fill"),
        OptionItem(value: "other",     label: "Other",      subtitle: nil, icon: "questionmark.square.fill"),
    ]

    private let skillLevelOptions: [OptionItem] = [
        OptionItem(value: "beginner", label: "Just starting out", subtitle: "Total beginner",          icon: "hand.wave.fill"),
        OptionItem(value: "some",     label: "Some experience",   subtitle: "Done a few repairs",      icon: "wrench.fill"),
        OptionItem(value: "handy",    label: "Pretty handy",      subtitle: "Handle most things",      icon: "hammer.fill"),
        OptionItem(value: "expert",   label: "DIY expert",        subtitle: "Can fix almost anything", icon: "star.fill"),
    ]

    private let repairTypeOptions: [OptionItem] = [
        OptionItem(value: "plumbing",   label: "Plumbing",            subtitle: nil, icon: "drop.fill"),
        OptionItem(value: "electrical", label: "Electrical",          subtitle: nil, icon: "bolt.fill"),
        OptionItem(value: "hvac",       label: "HVAC & Appliances",   subtitle: nil, icon: "thermometer.medium"),
        OptionItem(value: "general",    label: "General Maintenance", subtitle: nil, icon: "wrench.and.screwdriver.fill"),
    ]
}

// MARK: - Data Model

private struct OptionItem: Identifiable {
    let id = UUID()
    let value: String
    let label: String
    let subtitle: String?
    let icon: String
}

private struct DemoContent {
    let title: String
    let icon: String
    let description: String
    let steps: [String]
    let tools: [String]
    let materials: [String]
}

// MARK: - Welcome Step

private struct WelcomeStepView: View {
    let firstName: String
    @Binding var animate: Bool
    let onNext: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandBlue, Color.brand],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 120, height: 120)
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 12) {
                        Text("Welcome, \(firstName)!")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Let's personalize your QuickFix AI experience in just a few quick questions.")
                            .font(.system(size: 17))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    HStack(spacing: 16) {
                        Label("Takes 30 sec", systemImage: "clock.fill")
                        Label("No commitment", systemImage: "checkmark.shield.fill")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 32)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 40)
                .animation(.easeOut(duration: 0.6), value: animate)

                Spacer()
                Spacer()

                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text("Let's go")
                            .fontWeight(.bold)
                            .font(.system(size: 18))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(.white)
                    .foregroundStyle(Color.brandBlue)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
                .opacity(animate ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: animate)
            }
        }
    }
}

// MARK: - Question Step

private struct QuestionStepView: View {
    let progress: Double
    let stepLabel: String
    let question: String
    let options: [OptionItem]
    @Binding var selectedValue: String
    let onBack: () -> Void
    let onAdvance: () -> Void

    @State private var localSelection = ""
    @State private var pendingAdvance = false
    @State private var headerVisible = false
    @State private var questionVisible = false
    @State private var cardsVisible = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header row + progress bar
                VStack(spacing: 10) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.brand)
                                .frame(width: 36, height: 36)
                                .background(Color.brand.opacity(0.08))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text(stepLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Color.clear.frame(width: 36, height: 36)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 5)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.brandBlue, Color.brand],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * progress, height: 5)
                                .animation(.easeInOut(duration: 0.5), value: progress)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 28)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : -8)
                .animation(.easeOut(duration: 0.3), value: headerVisible)

                // Question text
                Text(question)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                    .opacity(questionVisible ? 1 : 0)
                    .offset(y: questionVisible ? 0 : 14)
                    .animation(.easeOut(duration: 0.35).delay(0.06), value: questionVisible)

                // Option cards with staggered entrance
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        OptionCard(option: option, isSelected: localSelection == option.value) {
                            guard !pendingAdvance else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                localSelection = option.value
                            }
                            pendingAdvance = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                                selectedValue = option.value
                                pendingAdvance = false
                                onAdvance()
                            }
                        }
                        .opacity(cardsVisible ? 1 : 0)
                        .scaleEffect(cardsVisible ? 1 : 0.88)
                        .offset(y: cardsVisible ? 0 : 22)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.72)
                                .delay(0.12 + Double(index) * 0.07),
                            value: cardsVisible
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear {
            headerVisible   = true
            questionVisible = true
            cardsVisible    = true
        }
    }
}

// MARK: - Option Card

private struct OptionCard: View {
    let option: OptionItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    Image(systemName: option.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(isSelected ? Color.brand : Color.secondary)
                        .frame(height: 36)

                    VStack(spacing: 4) {
                        Text(option.label)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        if let subtitle = option.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.brand.opacity(0.06) : Color.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color.brand : Color.secondary.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1.5
                        )
                )
                .shadow(
                    color: isSelected ? Color.brand.opacity(0.12) : Color.black.opacity(0.04),
                    radius: 6, y: 2
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brand)
                        .font(.system(size: 18))
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Personalizing Step

private struct PersonalizingStepView: View {
    let onComplete: () -> Void

    @State private var phase = -1

    private let items: [(String, String)] = [
        ("Analyzing your home profile",    "house.fill"),
        ("Customizing your repair guides", "wrench.and.screwdriver.fill"),
        ("Building your AI experience",    "sparkles"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandBlue, Color.brand],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 36) {
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(.white.opacity(0.06 - Double(i) * 0.015))
                                .frame(width: CGFloat(90 + i * 28), height: CGFloat(90 + i * 28))
                                .scaleEffect(phase >= 0 ? 1.0 : 0.4)
                                .opacity(phase >= 0 ? 1 : 0)
                                .animation(.easeOut(duration: 0.7).delay(Double(i) * 0.12), value: phase >= 0)
                        }
                        Image(systemName: "sparkles")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(.white)
                            .scaleEffect(phase >= 0 ? 1 : 0.3)
                            .opacity(phase >= 0 ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: phase >= 0)
                    }

                    VStack(spacing: 6) {
                        Text("Personalizing your")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("experience...")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(.yellow)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(phase >= 0 ? 1 : 0)
                    .offset(y: phase >= 0 ? 0 : 14)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: phase >= 0)

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(0.2))
                                        .frame(width: 38, height: 38)
                                    if phase > index {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    } else if phase == index {
                                        ProgressView().tint(.white).scaleEffect(0.75)
                                    } else {
                                        Image(systemName: item.1)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white.opacity(0.35))
                                    }
                                }
                                .animation(.easeInOut(duration: 0.25), value: phase)

                                Text(item.0)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(phase >= index ? 1.0 : 0.45))
                                    .animation(.easeOut(duration: 0.3), value: phase)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(.white.opacity(0.12))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2), lineWidth: 1))
                    .opacity(phase >= 0 ? 1 : 0)
                    .offset(y: phase >= 0 ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: phase >= 0)
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            let schedule: [(Double, Int)] = [(0.3, 0), (1.1, 1), (1.9, 2), (2.7, 3)]
            for (delay, p) in schedule {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation { phase = p }
                    if p == 3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onComplete() }
                    }
                }
            }
        }
    }
}

// MARK: - Summary Step

private struct SummaryStepView: View {
    let homeType: String
    let diyLevel: String
    let repairType: String
    let onComplete: () -> Void

    @State private var animateCheck = false
    @State private var animateCard  = false

    private var homeTypeLabel: String {
        switch homeType {
        case "house":     return "house owners"
        case "apartment": return "apartment residents"
        case "condo":     return "condo owners"
        default:          return "homeowners"
        }
    }

    private var skillLabel: String {
        switch diyLevel {
        case "beginner": return "beginners"
        case "some":     return "those with some experience"
        case "handy":    return "experienced DIYers"
        case "expert":   return "DIY experts"
        default:         return "all skill levels"
        }
    }

    private var repairLabel: String {
        switch repairType {
        case "plumbing":   return "plumbing"
        case "electrical": return "electrical"
        case "hvac":       return "HVAC & appliances"
        default:           return "general maintenance"
        }
    }

    private var bullets: [(String, String)] {[
        ("Tailored for \(homeTypeLabel)",          "house.fill"),
        ("Step-by-step guides for \(skillLabel)",  "list.bullet.clipboard.fill"),
        ("Specialized \(repairLabel) expertise",   "wrench.fill"),
        ("AI-powered answers, available 24/7",     "bolt.fill"),
    ]}

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandBlue, Color.brand],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 110, height: 110)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                            .scaleEffect(animateCheck ? 1 : 0.3)
                            .opacity(animateCheck ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateCheck)
                    }

                    Text("Your QuickFix AI\nis ready!")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(animateCheck ? 1 : 0)
                        .offset(y: animateCheck ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: animateCheck)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(bullets.enumerated()), id: \.offset) { index, bullet in
                            HStack(spacing: 14) {
                                Image(systemName: bullet.1)
                                    .foregroundStyle(.white)
                                    .font(.system(size: 16))
                                    .frame(width: 22)
                                Text(bullet.0)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                            .opacity(animateCard ? 1 : 0)
                            .offset(x: animateCard ? 0 : 20)
                            .animation(
                                .easeOut(duration: 0.4).delay(0.35 + Double(index) * 0.08),
                                value: animateCard
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(.white.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.3), lineWidth: 1))
                    .cornerRadius(18)
                    .opacity(animateCard ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: animateCard)
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()

                VStack(spacing: 12) {
                    Button(action: onComplete) {
                        HStack(spacing: 8) {
                            Text("See It In Action")
                                .fontWeight(.bold)
                                .font(.system(size: 18))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white)
                        .foregroundStyle(Color.brandBlue)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    }

                    Text("One more thing before you start")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
                .opacity(animateCard ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.65), value: animateCard)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { animateCheck = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { animateCard  = true }
        }
    }
}

// MARK: - Aha Demo Step

private struct AhaDemoStepView: View {
    @Environment(UserViewModel.self)     private var userVM
    @Environment(RevenueCatService.self) private var revenueCatService

    let repairType: String
    let onComplete: () -> Void

    /// Paywall-after-diagnosis test: the next screen is the app, not the paywall.
    private var goesToFreeDiagnosis: Bool {
        userVM.isInDiagnosisPreview(timing: revenueCatService.paywallTiming)
    }

    // ── Scan phase ──
    @State private var showHeader        = false
    @State private var showViewfinder    = false
    @State private var scanLineOffset: CGFloat = -80
    @State private var scanLineVisible   = false
    @State private var detectionPulse    = false
    @State private var showDetectionBox  = false
    @State private var cornersGlow       = false

    // ── Analyzing phase ──
    @State private var showAnalyzing     = false
    @State private var analyzePhase      = -1     // 0,1,2 checklist items
    @State private var analyzeProgress: Double = 0

    // ── Guide phase ──
    @State private var showGuide         = false
    @State private var confidence: Double = 0
    @State private var step1Visible      = false
    @State private var markCompletePulse = false
    @State private var step1Complete     = false
    @State private var nextPulse         = false
    @State private var showStep2         = false
    @State private var showTools         = false
    @State private var showCTA           = false

    private var demo: DemoContent {
        switch repairType {
        case "plumbing":
            return DemoContent(
                title: "Fix a Dripping Kitchen Faucet",
                icon: "drop.fill",
                description: "Dripping kitchen faucet detected",
                steps: [
                    "Turn off the water supply valves under the sink",
                    "Remove the handle and replace the worn cartridge",
                    "Reassemble and test — no more dripping"
                ],
                tools: ["Adjustable wrench", "Channel-lock pliers", "Flathead screwdriver"],
                materials: ["Replacement cartridge", "Plumber's grease", "Teflon tape"]
            )
        case "electrical":
            return DemoContent(
                title: "Replace a Faulty Outlet",
                icon: "bolt.fill",
                description: "Non-functional wall outlet detected",
                steps: [
                    "Turn off the circuit breaker for that outlet",
                    "Disconnect wires from old outlet, note wire colors",
                    "Connect wires to new outlet and secure in the box"
                ],
                tools: ["Flathead screwdriver", "Phillips screwdriver", "Voltage tester"],
                materials: ["Replacement outlet", "Wire nuts", "Electrical tape"]
            )
        case "hvac":
            return DemoContent(
                title: "Replace HVAC Air Filter",
                icon: "thermometer.medium",
                description: "Clogged HVAC air filter detected",
                steps: [
                    "Locate your air handler and note the filter size",
                    "Slide out the old filter and dispose of it",
                    "Insert new filter with arrow pointing toward the blower"
                ],
                tools: ["Measuring tape", "Work gloves", "Flashlight"],
                materials: ["Replacement filter (correct size)", "Filter disposal bag"]
            )
        default:
            return DemoContent(
                title: "Patch a Drywall Hole",
                icon: "wrench.and.screwdriver.fill",
                description: "Drywall damage detected",
                steps: [
                    "Cut a clean square around the damaged area",
                    "Secure a backer board and attach the patch",
                    "Apply joint compound, sand smooth, and paint"
                ],
                tools: ["Drywall saw", "Putty knife", "Sanding block"],
                materials: ["Drywall patch kit", "Joint compound", "Primer and paint"]
            )
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandBlue, Color.brand],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Header ──
                    VStack(spacing: 6) {
                        Text("Point. Scan. Fix.")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("AI generates a full repair guide instantly")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .opacity(showHeader ? 1 : 0)
                    .offset(y: showHeader ? 0 : 14)
                    .animation(.easeOut(duration: 0.4), value: showHeader)

                    // ── Scan viewfinder OR analyzing OR guide ──
                    if !showAnalyzing && !showGuide {
                        scanViewfinder
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }

                    if showAnalyzing && !showGuide {
                        analyzingCard
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                removal: .opacity
                            ))
                    }

                    if showGuide {
                        guideContent
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if showCTA {
                        ctaSection
                            .transition(.opacity.combined(with: .offset(y: 16)))
                    }

                    Spacer(minLength: 48)
                }
                .padding(.horizontal, 22)
                .padding(.top, 60)
                .padding(.bottom, 16)
            }
        }
        .onAppear { startSequence() }
    }

    // MARK: - Scan Viewfinder

    private var scanViewfinder: some View {
        VStack(spacing: 0) {
            // Phone frame
            ZStack {
                // Dark "camera feed" background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.82))
                    .frame(height: 240)

                // Real repair photo — fills the viewfinder
                Image("WallRepairDemo")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()
                    .overlay(Color.black.opacity(0.18))

                // Detection bounding box
                if showDetectionBox {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [Color.brand, Color.brandBlue],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 110, height: 72)
                        .offset(x: -18, y: -12)
                        .scaleEffect(detectionPulse ? 1.04 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                            value: detectionPulse
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                // Detection label
                if showDetectionBox {
                    VStack {
                        Spacer()
                        HStack {
                            Label(demo.description, systemImage: demo.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.brand.opacity(0.85))
                                .cornerRadius(8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }
                    .frame(height: 240)
                }

                // Sweeping scan line
                if scanLineVisible {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.brand.opacity(0.7), Color.clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .offset(y: scanLineOffset)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                // Corner brackets
                ViewfinderCorners(glowing: cornersGlow)
                    .frame(height: 240)
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(cornersGlow ? Color.brand.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.5)
                    .animation(.easeInOut(duration: 0.5), value: cornersGlow)
            )

            // Bottom hint bar
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brand)
                Text("Scanning for repair issues...")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                ProgressView().tint(Color.brand).scaleEffect(0.75)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.white.opacity(0.1))
            .cornerRadius(12)
            .padding(.top, 10)
        }
        .opacity(showViewfinder ? 1 : 0)
        .scaleEffect(showViewfinder ? 1 : 0.94)
        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.1), value: showViewfinder)
    }

    // MARK: - Analyzing Card

    private let analyzeItems: [(String, String)] = [
        ("Identifying issue type",       "magnifyingglass"),
        ("Researching repair steps",     "doc.text.magnifyingglass"),
        ("Building your repair guide",   "sparkles"),
    ]

    private var analyzingCard: some View {
        VStack(spacing: 18) {
            // Pulsing AI icon
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.brand.opacity(0.07 - Double(i) * 0.02))
                        .frame(width: CGFloat(64 + i * 22), height: CGFloat(64 + i * 22))
                        .scaleEffect(analyzePhase >= 0 ? 1.0 : 0.4)
                        .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.1), value: analyzePhase >= 0)
                }
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandBlue, Color.brand],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(analyzePhase >= 0 ? 1 : 0.4)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: analyzePhase >= 0)
            }

            VStack(spacing: 4) {
                Text("AI Analyzing Photo")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Generating your personalized repair guide")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12)).frame(height: 5)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.brandBlue, Color.brand],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * analyzeProgress, height: 5)
                        .animation(.easeInOut(duration: 0.6), value: analyzeProgress)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 4)

            // Checklist
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(analyzeItems.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 30, height: 30)
                            if analyzePhase > index {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.brand)
                                    .transition(.scale.combined(with: .opacity))
                            } else if analyzePhase == index {
                                ProgressView().tint(Color.brandBlue).scaleEffect(0.65)
                            } else {
                                Image(systemName: item.1)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary.opacity(0.4))
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: analyzePhase)

                        Text(item.0)
                            .font(.subheadline)
                            .foregroundStyle(analyzePhase >= index ? Color.primary : Color.secondary.opacity(0.5))
                            .animation(.easeOut(duration: 0.3), value: analyzePhase)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.appBackground)
            .cornerRadius(14)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
    }

    // MARK: - Guide Content

    private var guideContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Guide header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: demo.icon)
                        .foregroundStyle(Color.brand)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(demo.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                    Label("~30 min", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("AI", systemImage: "sparkles")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.brand)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.brand.opacity(0.1))
                    .cornerRadius(8)
            }

            // Confidence bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("AI Confidence")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(confidence * 100))%")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.brand)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 7)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color.brandBlue, Color.brand],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * confidence, height: 7)
                            .animation(.easeOut(duration: 1.0), value: confidence)
                    }
                }
                .frame(height: 7)
            }

            // Progress tracker
            HStack {
                Text("Progress")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(step1Complete ? 1 : 0)/\(demo.steps.count) steps")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .animation(.easeOut, value: step1Complete)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 6)
                    if step1Complete {
                        Capsule()
                            .fill(Color.success.opacity(0.8))
                            .frame(width: geo.size.width / CGFloat(demo.steps.count), height: 6)
                            .animation(.easeInOut(duration: 0.5), value: step1Complete)
                    }
                }
            }
            .frame(height: 6)

            Divider().opacity(0.35)

            // Step cards (step 1 → step 2)
            ZStack {
                if !showStep2 && step1Visible {
                    stepCard(
                        index: 0,
                        text: demo.steps[0],
                        isComplete: step1Complete,
                        markPulse: markCompletePulse
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id("step1")
                }
                if showStep2 {
                    stepCard(
                        index: 1,
                        text: demo.steps[1],
                        isComplete: false,
                        markPulse: false
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .id("step2")
                }
            }
            .frame(minHeight: 110)

            if step1Visible {
                HStack {
                    Label("Previous", systemImage: "chevron.left")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary.opacity(0.4))
                    Spacer()
                    Text("Step \(showStep2 ? 2 : 1) of \(demo.steps.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .animation(.easeOut, value: showStep2)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand)
                    .scaleEffect(nextPulse ? 1.18 : 1.0)
                    .animation(.easeInOut(duration: 0.14), value: nextPulse)
                }
                .transition(.opacity)
            }

            if showTools {
                Divider().opacity(0.35)
                HStack(alignment: .top, spacing: 12) {
                    toolsCard(title: "Tools",     icon: "wrench.fill",      items: demo.tools,     accentColor: Color.brand)
                    toolsCard(title: "Materials", icon: "shippingbox.fill", items: demo.materials, accentColor: Color.brandBlue)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(18)
        .background(Color.cardBackground)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
    }

    // MARK: - Step Card

    private func stepCard(index: Int, text: String, isComplete: Bool, markPulse: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    if isComplete {
                        Circle()
                            .fill(Color.success)
                            .frame(width: 34, height: 34)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.brandBlue, Color.brand],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 34, height: 34)
                            .shadow(color: Color.brand.opacity(0.3), radius: 4, y: 2)
                        Text("\(index + 1)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: isComplete)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(index + 1)")
                        .font(.headline)
                    Text(text)
                        .font(.body)
                        .foregroundStyle(isComplete ? Color.secondary : Color.primary)
                        .strikethrough(isComplete, color: Color.secondary.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeOut(duration: 0.3), value: isComplete)
                }

                Spacer()

                Label(
                    isComplete ? "Completed" : "Mark Complete",
                    systemImage: isComplete ? "checkmark.circle.fill" : "circle"
                )
                .font(.footnote)
                .foregroundStyle(isComplete ? Color.success : Color.secondary)
                .scaleEffect(markPulse ? 1.18 : 1.0)
                .animation(.easeInOut(duration: 0.14), value: markPulse)
                .animation(.easeOut(duration: 0.3), value: isComplete)
            }
        }
        .padding(14)
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isComplete ? Color.success.opacity(0.4) : Color.clear, lineWidth: 2)
                .animation(.easeOut(duration: 0.3), value: isComplete)
        )
    }

    // MARK: - Tools Card

    private func toolsCard(title: String, icon: String, items: [String], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accentColor)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .font(.system(size: 14))
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appBackground)
        .cornerRadius(12)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 10) {
            Button(action: onComplete) {
                HStack(spacing: 8) {
                    Text(goesToFreeDiagnosis ? "Try It Free" : "Unlock My Access")
                        .font(.system(size: 18, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.white)
                .foregroundStyle(Color.brandBlue)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            }

            Text(goesToFreeDiagnosis
                 ? "Your first diagnosis is on us"
                 : AppConfig.offersFreeTrial
                    ? "Start your \(AppConfig.trialPeriodDays)-day free trial on the next screen"
                    : "Choose your plan on the next screen")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Animation Sequence

    private func startSequence() {
        // Header
        at(0.2) { showHeader = true }

        // Viewfinder appears
        at(0.5) { showViewfinder = true }

        // Scan line sweeps
        at(0.9) {
            scanLineVisible = true
            scanLineOffset = -80
            withAnimation(.easeInOut(duration: 1.4)) { scanLineOffset = 80 }
        }
        // Second sweep
        at(2.4) {
            scanLineOffset = -80
            withAnimation(.easeInOut(duration: 1.2)) { scanLineOffset = 80 }
        }

        // Corners start glowing — issue detected
        at(1.8) { withAnimation(.easeInOut(duration: 0.4)) { cornersGlow = true } }

        // Detection bounding box pops in
        at(2.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                showDetectionBox = true
            }
            detectionPulse = true
        }

        // Transition: viewfinder → analyzing
        at(3.8) {
            withAnimation(.easeInOut(duration: 0.35)) {
                showAnalyzing = true
                scanLineVisible = false
            }
        }

        // Analyzing checklist
        at(4.1)  { withAnimation { analyzePhase = 0 }; analyzeProgress = 0.2 }
        at(4.9)  { withAnimation { analyzePhase = 1 }; analyzeProgress = 0.55 }
        at(5.7)  { withAnimation { analyzePhase = 2 }; analyzeProgress = 0.9 }
        at(6.3)  { withAnimation { analyzePhase = 3 }; analyzeProgress = 1.0 }

        // Transition: analyzing → guide
        at(6.8) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                showGuide = true
                showAnalyzing = false
            }
        }
        at(7.3) { confidence = 0.94 }
        at(7.8) { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { step1Visible = true } }
        at(8.6) { markCompletePulse = true }
        at(8.78) { markCompletePulse = false }
        at(8.9) { withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { step1Complete = true } }
        at(7.5) { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showTools = true } }
        at(9.5) { nextPulse = true }
        at(9.68) { nextPulse = false }
        at(9.8) { withAnimation(.easeInOut(duration: 0.35)) { showStep2 = true } }
        at(10.3) { withAnimation(.easeOut(duration: 0.4)) { showCTA = true } }
    }

    private func at(_ delay: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

// MARK: - Viewfinder Corner Brackets

private struct ViewfinderCorners: View {
    let glowing: Bool
    private let size: CGFloat = 22
    private let thickness: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = 18
            let color: Color = glowing ? Color.brand : Color.white.opacity(0.55)

            ZStack {
                // Top-left
                cornerBracket(rotation: 0, color: color)
                    .position(x: pad + size / 2, y: pad + size / 2)

                // Top-right
                cornerBracket(rotation: 90, color: color)
                    .position(x: w - pad - size / 2, y: pad + size / 2)

                // Bottom-left
                cornerBracket(rotation: 270, color: color)
                    .position(x: pad + size / 2, y: h - pad - size / 2)

                // Bottom-right
                cornerBracket(rotation: 180, color: color)
                    .position(x: w - pad - size / 2, y: h - pad - size / 2)
            }
            .animation(.easeInOut(duration: 0.4), value: glowing)
        }
    }

    private func cornerBracket(rotation: Double, color: Color) -> some View {
        Path { p in
            p.move(to:    CGPoint(x: 0,    y: size))
            p.addLine(to: CGPoint(x: 0,    y: 0))
            p.addLine(to: CGPoint(x: size, y: 0))
        }
        .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
    }
}
