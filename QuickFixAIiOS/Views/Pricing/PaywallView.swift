import SwiftUI

struct PaywallView: View {
    @Environment(UserViewModel.self)      private var userVM
    @Environment(AuthViewModel.self)      private var authVM
    @Environment(RevenueCatService.self)  private var revenueCatService

    @State private var isAnnual          = false
    @State private var showAllPlans      = false
    @State private var purchaseError: String? = nil
    @State private var showPurchaseError = false

    private var starterPlan: AppConfig.PlanInfo? { AppConfig.plan(for: "starter") }
    private var proPlan:     AppConfig.PlanInfo? { AppConfig.plan(for: "pro") }
    private var premiumPlan: AppConfig.PlanInfo? { AppConfig.plan(for: "premium") }
    private var isTrialEligible: Bool { userVM.profile?.isTrialEligible ?? true }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    if isTrialEligible, let starter = starterPlan {
                        trialContent(plan: starter)
                    } else {
                        noTrialContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 56)
            }
        }
        .overlay {
            if revenueCatService.purchaseInProgress {
                LoadingOverlayView(message: "Processing…")
            }
        }
        .alert("Purchase Error", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "Unable to complete purchase. Please try again.")
        }
        .onChange(of: revenueCatService.purchaseError) { _, error in
            if let error {
                purchaseError    = error
                showPurchaseError = true
                revenueCatService.purchaseError = nil
            }
        }
    }

    // MARK: - Trial Flow

    private func trialContent(plan: AppConfig.PlanInfo) -> some View {
        VStack(spacing: 28) {

            // 1. Headline
            VStack(spacing: 10) {
                (Text("Start your \(AppConfig.trialPeriodDays)-day ")
                    .foregroundStyle(.primary)
                + Text("FREE")
                    .foregroundStyle(Color.brand)
                + Text(" trial."))
                    .font(.system(size: 34, weight: .heavy))
                    .multilineTextAlignment(.center)

                Text("No payment due now. Cancel anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 2. Timeline
            trialTimeline(plan: plan)

            // 3. Trust badge
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.success)
                Text("No Payment Due Now")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Color.success.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.success.opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(24)

            // 4. Primary CTA
            Button {
                purchaseViaApple(productId: AppConfig.StoreKitProducts.starterMonthly)
            } label: {
                Text("Start My \(AppConfig.trialPeriodDays)-Day Free Trial")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.brandBlue, Color.brand],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.brand.opacity(0.35), radius: 12, y: 5)
            }
            .disabled(revenueCatService.purchaseInProgress)

            // 5. Restore + sign-out
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("Already purchased?")
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await revenueCatService.restorePurchases() }
                    } label: {
                        Text("Restore")
                            .foregroundStyle(Color.brand)
                    }
                }
                .font(.subheadline)
            }

            // 6. Legal
            Text("\(AppConfig.trialPeriodDays) days free, then $\(Int(plan.monthlyPrice))/month. Billed monthly. Cancel in App Store Settings anytime before Day \(AppConfig.trialPeriodDays + 1). Subscriptions auto-renew.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            // 7. Other plans disclosure
            otherPlansSection

            // 8. Footer links
            footerLinks
        }
    }

    // MARK: - Trial Timeline

    private func trialTimeline(plan: AppConfig.PlanInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow(
                icon: "checkmark.circle.fill",
                iconColor: Color.success,
                title: "Today",
                description: "Unlock all AI repair features — completely free"
            )
            timelineConnector
            timelineRow(
                icon: "bell.fill",
                iconColor: Color.brandBlue,
                title: "Day \(AppConfig.trialPeriodDays - 1) — Reminder",
                description: "We'll remind you before your trial ends"
            )
            timelineConnector
            timelineRow(
                icon: "creditcard.fill",
                iconColor: Color.secondary,
                title: "Day \(AppConfig.trialPeriodDays + 1) — Billing Starts",
                description: "$\(Int(plan.monthlyPrice))/month unless you cancel"
            )
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }

    private func timelineRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 18, weight: .medium))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 10)

            Spacer()
        }
    }

    private var timelineConnector: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 2, height: 22)
                .frame(width: 44)
            Spacer()
        }
    }

    // MARK: - No Trial Flow (trial already used)

    private var noTrialContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("Choose your plan")
                    .font(.system(size: 32, weight: .heavy))
                    .multilineTextAlignment(.center)
                Text("Unlock AI-powered repair guidance anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            billingToggle

            HStack(spacing: 12) {
                if let pro = proPlan {
                    planCard(plan: pro, accentColor: Color.brandBlue, badge: "Best Value")
                }
                if let premium = premiumPlan {
                    planCard(plan: premium, accentColor: Color.brand, badge: nil)
                }
            }

            if let starter = starterPlan {
                starterFallbackRow(plan: starter)
            }

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("Already purchased?")
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await revenueCatService.restorePurchases() }
                    } label: {
                        Text("Restore")
                            .foregroundStyle(Color.brand)
                    }
                }
                .font(.subheadline)
            }

            footerLinks
        }
    }

    // MARK: - Other Plans Section (trial flow)

    private var otherPlansSection: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { showAllPlans.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(showAllPlans ? "Hide other plans" : "Explore other plans")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: showAllPlans ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if showAllPlans {
                VStack(spacing: 14) {
                    billingToggle

                    HStack(spacing: 12) {
                        if let pro = proPlan {
                            planCard(plan: pro, accentColor: Color.brandBlue, badge: "Best Value")
                        }
                        if let premium = premiumPlan {
                            planCard(plan: premium, accentColor: Color.brand, badge: nil)
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack {
            Text("Billing")
                .font(.subheadline.weight(.medium))
            Spacer()
            HStack(spacing: 8) {
                Text("Annual")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isAnnual ? Color.brand : .secondary)
                Toggle("Annual", isOn: $isAnnual)
                    .labelsHidden()
                    .tint(Color.brand)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Plan Card

    private func planCard(plan: AppConfig.PlanInfo, accentColor: Color, badge: String?) -> some View {
        let price     = isAnnual ? plan.annualPrice : plan.monthlyPrice
        let productId = AppConfig.StoreKitProducts.productId(plan: plan.id, billing: isAnnual ? "annual" : "monthly")

        return VStack(alignment: .leading, spacing: 12) {
            if let badge {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(accentColor.opacity(0.12))
                    .cornerRadius(10)
            } else {
                Color.clear.frame(height: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.displayName)
                    .font(.headline.weight(.bold))
                Text(plan.credits == 100 ? "Premium AI" : plan.credits == 25 ? "Advanced AI" : "Standard AI")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "$%.0f", price))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(accentColor)
                Text("/mo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isAnnual, let savings = annualSavings(plan: plan) {
                Text(savings)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.success)
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(plan.features.prefix(4), id: \.self) { feature in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.success)
                            .font(.caption)
                        Text(feature)
                            .font(.caption)
                            .lineLimit(2)
                        Spacer()
                    }
                }
            }

            Spacer()

            Button {
                purchaseViaApple(productId: productId)
            } label: {
                Text("Choose \(plan.displayName)")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .disabled(revenueCatService.purchaseInProgress)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: accentColor.opacity(0.08), radius: 8, y: 3)
    }

    // MARK: - Starter Fallback Row

    private func starterFallbackRow(plan: AppConfig.PlanInfo) -> some View {
        let price     = isAnnual ? plan.annualPrice : plan.monthlyPrice
        let productId = AppConfig.StoreKitProducts.productId(plan: "starter", billing: isAnnual ? "annual" : "monthly")

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Starter Plan")
                    .font(.subheadline.weight(.semibold))
                Text(String(format: "$%.0f / month", price))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                purchaseViaApple(productId: productId)
            } label: {
                Text("Get Starter")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Color.brand)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .disabled(revenueCatService.purchaseInProgress)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 12) {
            Button {
                authVM.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func purchaseViaApple(productId: String) {
        Task {
            do {
                try await revenueCatService.purchase(productId: productId)
            } catch {
                purchaseError    = error.localizedDescription
                showPurchaseError = true
            }
        }
    }

    private func annualSavings(plan: AppConfig.PlanInfo) -> String? {
        let saved = (plan.monthlyPrice * 12) - plan.annualTotal
        return saved > 0 ? String(format: "Save $%.0f/yr", saved) : nil
    }
}
