import SwiftUI

struct PostAuthOnboardingView: View {
    @Environment(AuthViewModel.self) private var authVM

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userHomeType")   private var userHomeType   = ""
    @AppStorage("userDIYLevel")   private var userDIYLevel   = ""
    @AppStorage("userRepairType") private var userRepairType = ""

    @State private var step: OnboardingStep = .welcome
    @State private var animateEntrance = false
    @State private var goingBack = false

    private enum OnboardingStep {
        case welcome, homeType, skillLevel, repairType, summary
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
                    onAdvance: { advance(to: .summary) }
                )
                .transition(stepTransition)

            case .summary:
                SummaryStepView(
                    homeType: userHomeType,
                    diyLevel: userDIYLevel,
                    repairType: userRepairType,
                    onComplete: { hasCompletedOnboarding = true }
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
        OptionItem(value: "house",     label: "House",     subtitle: nil,              icon: "house.fill"),
        OptionItem(value: "apartment", label: "Apartment", subtitle: nil,              icon: "building.2.fill"),
        OptionItem(value: "condo",     label: "Condo",     subtitle: nil,              icon: "building.fill"),
        OptionItem(value: "other",     label: "Other",     subtitle: nil,              icon: "questionmark.square.fill"),
    ]

    private let skillLevelOptions: [OptionItem] = [
        OptionItem(value: "beginner", label: "Just starting out", subtitle: "Total beginner",        icon: "hand.wave.fill"),
        OptionItem(value: "some",     label: "Some experience",   subtitle: "Done a few repairs",    icon: "wrench.fill"),
        OptionItem(value: "handy",    label: "Pretty handy",      subtitle: "Handle most things",    icon: "hammer.fill"),
        OptionItem(value: "expert",   label: "DIY expert",        subtitle: "Can fix almost anything", icon: "star.fill"),
    ]

    private let repairTypeOptions: [OptionItem] = [
        OptionItem(value: "plumbing",    label: "Plumbing",           subtitle: nil, icon: "drop.fill"),
        OptionItem(value: "electrical",  label: "Electrical",         subtitle: nil, icon: "bolt.fill"),
        OptionItem(value: "hvac",        label: "HVAC & Appliances",  subtitle: nil, icon: "thermometer.medium"),
        OptionItem(value: "general",     label: "General Maintenance", subtitle: nil, icon: "wrench.and.screwdriver.fill"),
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
                    // Icon cluster
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 120, height: 120)
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    // Greeting
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

                    // Trust chips
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

                // CTA
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

    @State private var pendingAdvance = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: back button + progress
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
                        // Spacer to balance the back button
                        Color.clear.frame(width: 36, height: 36)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 5)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.brandBlue, Color.brand],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 5)
                                .animation(.easeInOut(duration: 0.4), value: progress)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 28)

                // Question
                Text(question)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)

                // Option grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(options) { option in
                        OptionCard(
                            option: option,
                            isSelected: selectedValue == option.value
                        ) {
                            guard !pendingAdvance else { return }
                            selectedValue = option.value
                            pendingAdvance = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                pendingAdvance = false
                                onAdvance()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
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
                .background(
                    isSelected ? Color.brand.opacity(0.06) : Color.cardBackground
                )
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

                // Checkmark badge
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

// MARK: - Summary Step

private struct SummaryStepView: View {
    let homeType: String
    let diyLevel: String
    let repairType: String
    let onComplete: () -> Void

    @State private var animateCheck = false
    @State private var animateCard = false

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

    private var bullets: [(String, String)] {
        [
            ("Tailored for \(homeTypeLabel)",          "house.fill"),
            ("Step-by-step guides for \(skillLabel)", "list.bullet.clipboard.fill"),
            ("Specialized \(repairLabel) expertise",  "wrench.fill"),
            ("AI-powered answers, available 24/7",    "bolt.fill"),
        ]
    }

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
                    // Animated checkmark
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

                    // Headline
                    Text("Your QuickFix AI\nis ready!")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(animateCheck ? 1 : 0)
                        .offset(y: animateCheck ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: animateCheck)

                    // Personalized bullets card
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(18)
                    .opacity(animateCard ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: animateCard)
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()

                // CTA
                VStack(spacing: 12) {
                    Button(action: onComplete) {
                        HStack(spacing: 8) {
                            Text("See My Plan")
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

                    Text("Takes 30 seconds to get started")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { animateCard = true }
        }
    }
}
