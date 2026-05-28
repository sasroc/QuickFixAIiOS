import SwiftUI

struct PaywallView: View {
    @Environment(UserViewModel.self)      private var userVM
    @Environment(AuthViewModel.self)      private var authVM
    @Environment(RevenueCatService.self)  private var revenueCatService

    @State private var isLifetime       = false
    @State private var purchaseError: String? = nil
    @State private var showPurchaseError = false

    private var plan: AppConfig.PlanInfo? { AppConfig.plans.first }
    private var isTrialEligible: Bool { userVM.profile?.isTrialEligible ?? true }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    if isTrialEligible, let p = plan {
                        trialContent(plan: p)
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
                purchaseViaApple(productId: AppConfig.StoreKitProducts.proMonthly)
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
            Text(String(format: "\(AppConfig.trialPeriodDays) days free, then $%.2f/month. Billed monthly. Cancel in App Store Settings anytime before Day \(AppConfig.trialPeriodDays + 1). Subscriptions auto-renew.", plan.monthlyPrice))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            // 7. Lifetime alternative
            orDivider
            planCard(plan: plan, accentColor: Color.brand, lifetime: true)

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
                description: String(format: "$%.2f/month unless you cancel", plan.monthlyPrice)
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

    // MARK: - No Trial Flow

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

            if let p = plan {
                planCard(plan: p, accentColor: Color.brandBlue)
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

    // MARK: - OR Divider

    private var orDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
            Text("OR")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack {
            Text("Billing")
                .font(.subheadline.weight(.medium))
            Spacer()
            HStack(spacing: 8) {
                Text("Lifetime")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isLifetime ? Color.brand : .secondary)
                Toggle("Lifetime", isOn: $isLifetime)
                    .labelsHidden()
                    .tint(Color.brand)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Plan Card

    private func planCard(plan: AppConfig.PlanInfo, accentColor: Color, lifetime: Bool? = nil) -> some View {
        let showLifetime = lifetime ?? isLifetime
        let price     = showLifetime ? plan.lifetimePrice : plan.monthlyPrice
        let billing   = showLifetime ? "lifetime" : "monthly"
        let productId = AppConfig.StoreKitProducts.productId(plan: plan.id, billing: billing)
        let features  = showLifetime ? plan.lifetimeFeatures : plan.features

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.displayName)
                    .font(.headline.weight(.bold))
                Text(showLifetime ? "Lifetime Access" : "Monthly Subscription")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "$%.2f", price))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(accentColor)
                Text(showLifetime ? " one-time" : "/mo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showLifetime, let savings = lifetimeSavings(plan: plan) {
                Text(savings)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.success)
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(features.prefix(5), id: \.self) { feature in
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

            Button {
                purchaseViaApple(productId: productId)
            } label: {
                Text(showLifetime ? "Get Lifetime Access" : "Subscribe Monthly")
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

    private func lifetimeSavings(plan: AppConfig.PlanInfo) -> String? {
        let saved = (plan.monthlyPrice * 12) - plan.lifetimePrice
        return saved > 0 ? String(format: "Save $%.2f vs. 1 year", saved) : nil
    }
}
