import SwiftUI

/// Full-screen paywall shown to signed-in users who don't have an active subscription.
struct PaywallView: View {
    @Environment(UserViewModel.self)    private var userVM
    @Environment(AuthViewModel.self)    private var authVM
    @Environment(RevenueCatService.self)  private var revenueCatService

    @State private var isAnnual         = false
    @State private var purchaseError: String? = nil
    @State private var showPurchaseError = false

    private var starterPlan: AppConfig.PlanInfo? { AppConfig.plan(for: "starter") }
    private var proPlan:     AppConfig.PlanInfo? { AppConfig.plan(for: "pro") }
    private var premiumPlan: AppConfig.PlanInfo? { AppConfig.plan(for: "premium") }
    private var isTrialEligible: Bool { userVM.profile?.isTrialEligible ?? true }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    paywallHeader
                        .frame(height: geo.size.height * 0.25)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // 1. Featured trial card (if eligible)
                            if isTrialEligible, let starter = starterPlan {
                                trialCard(plan: starter)
                            }

                            // 2. Billing + paid plans
                            paidPlansSection

                            // 3. Starter without trial (if trial used)
                            if !isTrialEligible, let starter = starterPlan {
                                starterFallbackRow(plan: starter)
                            }

                            // 4. Footer
                            footerSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 48)
                    }
                    .background(Color.appBackground)
                }
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

    // MARK: - Header

    private var paywallHeader: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandBlue, Color.brand],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                    HStack(spacing: 0) {
                        Text("QuickFix")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.white)
                        Text(" AI")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.yellow)
                    }
                }

                Text("Unlock instant AI repair guidance")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                Text("Choose a plan to get started")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Trial Card

    private func trialCard(plan: AppConfig.PlanInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            // Badges row
            HStack {
                Label("MOST POPULAR", systemImage: "star.fill")
                    .font(.caption2).fontWeight(.black)
                    .foregroundStyle(Color(red: 0.5, green: 0.35, blue: 0))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.yellow.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.yellow.opacity(0.5), lineWidth: 1))
                    .cornerRadius(20)

                Spacer()

                Text("FREE TRIAL")
                    .font(.caption2).fontWeight(.heavy)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.success)
                    .cornerRadius(20)
            }

            // Pricing headline
            VStack(alignment: .leading, spacing: 4) {
                Text("5-Day Free Trial")
                    .font(.title2).fontWeight(.heavy)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$\(Int(plan.monthlyPrice))")
                        .font(.largeTitle).fontWeight(.heavy)
                        .foregroundStyle(Color.brand)
                    Text("/ month after trial ends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("No charge until Day 6  ·  Cancel anytime")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.4)

            // Features
            VStack(alignment: .leading, spacing: 10) {
                featureRow("10 AI repair analyses per month",  icon: "bolt.fill")
                featureRow("Step-by-step repair guides",       icon: "list.bullet.clipboard.fill")
                featureRow("Photo-based AI diagnosis",         icon: "camera.fill")
                featureRow("10 saved repairs in history",      icon: "clock.fill")
            }

            // CTA
            Button {
                purchaseViaApple(productId: AppConfig.StoreKitProducts.starterMonthly)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.brandBlue, Color.brand],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.brand.opacity(0.4), radius: 8, y: 4)

                    HStack(spacing: 8) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text("Start 5-Day Free Trial")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                }
                .frame(height: 54)
            }
            .disabled(revenueCatService.purchaseInProgress)

            Text("No charge for 5 days  ·  $\(Int(plan.monthlyPrice))/mo after  ·  Cancel anytime")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.brandBlue.opacity(0.55), Color.brand.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: Color.brandBlue.opacity(0.10), radius: 18, y: 6)
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.brand)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Paid Plans Section

    private var paidPlansSection: some View {
        VStack(spacing: 14) {
            // Header + billing toggle
            HStack(alignment: .center) {
                Text(isTrialEligible ? "Or choose a plan:" : "Choose a plan:")
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    Text("Annual")
                        .font(.caption)
                        .foregroundStyle(isAnnual ? Color.brand : .secondary)
                    Toggle("Annual", isOn: $isAnnual)
                        .labelsHidden()
                        .tint(Color.brand)
                }
            }

            if isAnnual {
                Text("Save up to 28% with annual billing")
                    .font(.caption)
                    .foregroundStyle(Color.success)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Pro + Premium side by side
            HStack(spacing: 12) {
                if let pro = proPlan {
                    planCard(plan: pro, isAnnual: isAnnual, accentColor: Color.brandBlue, badge: "Best Value")
                }
                if let premium = premiumPlan {
                    planCard(plan: premium, isAnnual: isAnnual, accentColor: Color.brand, badge: nil)
                }
            }
        }
    }

    private func planCard(
        plan: AppConfig.PlanInfo,
        isAnnual: Bool,
        accentColor: Color,
        badge: String?
    ) -> some View {
        let price     = isAnnual ? plan.annualPrice : plan.monthlyPrice
        let productId = AppConfig.StoreKitProducts.productId(plan: plan.id, billing: isAnnual ? "annual" : "monthly")

        return VStack(alignment: .leading, spacing: 12) {
            // Badge
            if let badge = badge {
                Text(badge)
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(accentColor.opacity(0.12))
                    .cornerRadius(10)
            } else {
                Color.clear.frame(height: 20) // alignment spacer
            }

            // Name + model
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.displayName)
                    .font(.headline).fontWeight(.bold)
                Text(plan.aiModel)
                    .font(.caption2).foregroundStyle(.secondary)
            }

            // Price
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "$%.0f", price))
                    .font(.title2).fontWeight(.heavy)
                    .foregroundStyle(accentColor)
                Text("/mo")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if isAnnual, let savings = annualSavings(plan: plan) {
                Text(savings)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(Color.success)
            }

            Divider().opacity(0.5)

            // Features
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

            // CTA
            Button {
                purchaseViaApple(productId: productId)
            } label: {
                Text("Choose \(plan.displayName)")
                    .font(.footnote).fontWeight(.semibold)
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

    // MARK: - Starter Fallback (trial used)

    private func starterFallbackRow(plan: AppConfig.PlanInfo) -> some View {
        let price     = isAnnual ? plan.annualPrice : plan.monthlyPrice
        let productId = AppConfig.StoreKitProducts.productId(plan: "starter", billing: isAnnual ? "annual" : "monthly")

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Starter Plan")
                    .font(.subheadline).fontWeight(.semibold)
                Text(String(format: "$%.0f / month", price))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                purchaseViaApple(productId: productId)
            } label: {
                Text("Get Starter")
                    .font(.footnote).fontWeight(.semibold)
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
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                Label("Cancel anytime",  systemImage: "checkmark.circle")
                Label("Apple secured",   systemImage: "lock.shield")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the period end.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                Task { await revenueCatService.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                authVM.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func purchaseViaApple(productId: String) {
        Task {
            do {
                try await revenueCatService.purchase(productId: productId)
                // On success, userVM Firestore listener updates hasActiveAccess
                // and the paywall dismisses automatically.
            } catch {
                purchaseError     = error.localizedDescription
                showPurchaseError = true
            }
        }
    }

    private func annualSavings(plan: AppConfig.PlanInfo) -> String? {
        let saved = (plan.monthlyPrice * 12) - plan.annualTotal
        return saved > 0 ? String(format: "Save $%.0f/yr", saved) : nil
    }
}
