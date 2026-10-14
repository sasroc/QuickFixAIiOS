import SwiftUI

struct PaywallVariantBView: View {
    @Environment(UserViewModel.self)      private var userVM
    @Environment(AuthViewModel.self)      private var authVM
    @Environment(RevenueCatService.self)  private var revenueCatService

    /// Set when shown as a dismissable sheet (locked repair guide): the X
    /// closes the sheet instead of signing out.
    var onClose: (() -> Void)? = nil

    @State private var selectedBilling: BillingChoice = .lifetime
    @State private var purchaseError: String? = nil
    @State private var showPurchaseError = false
    @State private var showTerms    = false
    @State private var showPrivacy  = false

    enum BillingChoice { case monthly, lifetime }

    private var plan: AppConfig.PlanInfo? { AppConfig.plans.first }
    private var isTrialEligible: Bool { userVM.profile?.canStartFreeTrial ?? AppConfig.offersFreeTrial }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection

                    VStack(alignment: .leading, spacing: 20) {
                        headlineSection
                        featuresSection
                        socialProofRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                    planCardsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 28)

                    ctaSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    footerSection
                        .padding(.top, 20)
                        .padding(.bottom, 44)
                }
            }
            .ignoresSafeArea(edges: .top)
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
        .sheet(isPresented: $showTerms)   { TermsView() }
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if UIImage(named: "PaywallHero") != nil {
                    Image("PaywallHero")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.06, green: 0.14, blue: 0.28), Color.brandBlue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .overlay(
                        VStack(spacing: 14) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("QuickFix AI")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    )
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 32,
                    bottomTrailingRadius: 32,
                    topTrailingRadius: 0
                )
            )

            // X: close the sheet, or sign out when this is the full-screen gate
            Button {
                if let onClose { onClose() } else { authVM.signOut() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 34, height: 34)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.top, 58)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Headline

    private var headlineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fix anything in your home")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.primary)
            Text(isTrialEligible
                 ? "Start free — no payment due today."
                 : "Choose a plan to unlock AI repair guidance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow("AI-powered repair guides")
            featureRow("Unlimited repair history")
            featureRow("Step-by-step instructions")
            featureRow("Photo & image analysis")
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brand)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Social Proof

    private var socialProofRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
            Text("4.8 · Loved by 2,400+ homeowners")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Plan Cards

    private var planCardsSection: some View {
        HStack(spacing: 12) {
            planOptionCard(
                title: "Monthly",
                line1: isTrialEligible ? "7-day free trial" : String(format: "$%.2f/mo", plan?.monthlyPrice ?? 9.99),
                line2: isTrialEligible ? String(format: "$%.2f/mo after", plan?.monthlyPrice ?? 9.99) : nil,
                badge: nil,
                isSelected: selectedBilling == .monthly
            ) { selectedBilling = .monthly }

            planOptionCard(
                title: "Lifetime",
                line1: String(format: "$%.2f", plan?.lifetimePrice ?? 49.99),
                line2: "FOREVER",
                badge: "Best Value",
                isSelected: selectedBilling == .lifetime
            ) { selectedBilling = .lifetime }
        }
    }

    private func planOptionCard(
        title: String,
        line1: String,
        line2: String?,
        badge: String?,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(isSelected ? Color.brand : Color.secondary.opacity(0.3), lineWidth: 2)
                                .frame(width: 22, height: 22)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.brand)
                            }
                        }
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.brand)
                            .foregroundStyle(.white)
                            .cornerRadius(6)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(line1)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.brand : .secondary)
                    if let line2 {
                        Text(line2)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 32)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.brand : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        Button {
            guard let p = plan else { return }
            let billingStr = selectedBilling == .lifetime ? "lifetime" : "monthly"
            let productId  = AppConfig.StoreKitProducts.productId(plan: p.id, billing: billingStr)
            Task {
                do {
                    try await revenueCatService.purchase(productId: productId)
                } catch {
                    purchaseError    = error.localizedDescription
                    showPurchaseError = true
                }
            }
        } label: {
            VStack(spacing: 4) {
                Text(ctaTitle)
                    .font(.system(size: 17, weight: .bold))
                Text(ctaSubtitle)
                    .font(.caption)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Color.brandBlue, Color.brand], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .cornerRadius(16)
            .shadow(color: Color.brand.opacity(0.3), radius: 10, y: 4)
        }
        .disabled(revenueCatService.purchaseInProgress)
    }

    private var ctaTitle: String {
        selectedBilling == .lifetime
            ? "Get Lifetime Access"
            : (isTrialEligible ? "Start 7-Day Free Trial" : "Start Monthly Plan")
    }

    private var ctaSubtitle: String {
        if selectedBilling == .lifetime { return "One-time payment · No subscription" }
        return isTrialEligible
            ? String(format: "Then $%.2f/mo · Cancel anytime", plan?.monthlyPrice ?? 9.99)
            : "Cancel anytime"
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 6) {
            Button {
                Task { await revenueCatService.restorePurchases() }
            } label: {
                Text("Restore Purchases")
            }

            Text("·").foregroundStyle(.tertiary)

            Button { showTerms = true } label: {
                Text("Terms")
            }

            Text("·").foregroundStyle(.tertiary)

            Button { showPrivacy = true } label: {
                Text("Privacy")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
