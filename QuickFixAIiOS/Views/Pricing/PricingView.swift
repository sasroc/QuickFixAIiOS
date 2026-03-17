import SwiftUI
import SafariServices

struct PricingView: View {
    @Environment(UserViewModel.self)    private var userVM
    @Environment(AuthViewModel.self)    private var authVM
    @Environment(RevenueCatService.self)  private var revenueCatService
    @Environment(\.dismiss)            private var dismiss

    let startTrial: Bool

    @State private var billing: PlanCardView.BillingType = .monthly
    @State private var checkoutURL: URL?   = nil   // kept for Stripe portal (web subscribers)
    @State private var showSafari          = false
    @State private var showAuth            = false
    @State private var purchaseError: String? = nil
    @State private var showPurchaseError   = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose Your Plan")
                            .font(.title).fontWeight(.bold)

                        if startTrial {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                                Text("5-Day Free Trial Available")
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(20)
                        }
                    }
                    .padding(.top, 8)

                    // Billing toggle
                    HStack {
                        Text("Billing:")
                            .font(.subheadline).foregroundStyle(.secondary)

                        Picker("Billing", selection: $billing) {
                            Text("Monthly").tag(PlanCardView.BillingType.monthly)
                            Text("Annual (Save 28%)").tag(PlanCardView.BillingType.annual)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    // Trial ineligibility notice
                    if !startTrial && authVM.isSignedIn && userVM.profile?.wasOnTrial == true {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                            Text("You've already used your free trial. Choose a plan below.")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Plan cards
                    VStack(spacing: 16) {
                        ForEach(AppConfig.plans, id: \.id) { plan in
                            PlanCardView(
                                plan: plan,
                                billing: billing,
                                isCurrentPlan: userVM.profile?.plan.rawValue == plan.id
                            ) {
                                handlePlanSelection(planId: plan.id)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Manage subscription
                    if userVM.hasActiveAccess, authVM.isSignedIn {
                        Button {
                            if userVM.isAppleSubscriber {
                                userVM.openAppleSubscriptionManagement()
                            } else {
                                Task {
                                    if let url = await userVM.createPortalURL() {
                                        checkoutURL = url
                                        showSafari  = true
                                    }
                                }
                            }
                        } label: {
                            Label("Manage Subscription", systemImage: "creditcard")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.inputBackground)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }

                    // Footer
                    VStack(spacing: 10) {
                        Text("Cancel anytime. No hidden fees. Payments securely processed by Apple.")
                            .font(.caption).foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                        Text("Subscriptions auto-renew unless cancelled at least 24 hours before the period end.")
                            .font(.caption2).foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                        Button {
                            Task { await revenueCatService.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showAuth) { AuthView() }
            .fullScreenCover(isPresented: $showSafari) {
                if let url = checkoutURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
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
                    purchaseError     = error
                    showPurchaseError = true
                    revenueCatService.purchaseError = nil
                }
            }
        }
    }

    private func handlePlanSelection(planId: String) {
        guard authVM.isSignedIn else { showAuth = true; return }
        let billingStr = billing == .monthly ? "monthly" : "annual"
        let productId  = AppConfig.StoreKitProducts.productId(plan: planId, billing: billingStr)
        Task {
            do {
                try await revenueCatService.purchase(productId: productId)
            } catch {
                purchaseError     = error.localizedDescription
                showPurchaseError = true
            }
        }
    }
}

// MARK: - Safari wrapper (also used by AccountSettingsView for Stripe portal)

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Payment Success

struct PaymentSuccessView: View {
    @Environment(UserViewModel.self)  private var userVM
    @Environment(\.dismiss)          private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.brand)

            VStack(spacing: 10) {
                Text(userVM.profile?.isOnTrial == true ? "Your Trial Has Started!" : "You're All Set!")
                    .font(.title).fontWeight(.bold)

                Text(userVM.profile?.isOnTrial == true
                     ? "Enjoy 5 days of QuickFix AI Starter, on us."
                     : "Welcome to QuickFix AI \(userVM.profile?.plan.displayName ?? "")!")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Button {
                dismiss()
            } label: {
                Text("Start Fixing Things!")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(Color.brandGradient.ignoresSafeArea().opacity(0.08))
    }
}
