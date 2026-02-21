import SwiftUI
import SafariServices

struct PricingView: View {
    @Environment(UserViewModel.self)  private var userVM
    @Environment(AuthViewModel.self)  private var authVM
    @Environment(\.dismiss)          private var dismiss

    let startTrial: Bool

    @State private var billing: PlanCardView.BillingType = .monthly
    @State private var checkoutURL: URL? = nil
    @State private var showSafari      = false
    @State private var showAuth        = false
    @State private var showError       = false

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

                    // Manage / Cancel
                    if userVM.hasActiveAccess, authVM.isSignedIn {
                        Button {
                            Task {
                                if let url = await userVM.createPortalURL() {
                                    checkoutURL = url
                                    showSafari  = true
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
                    Text("Cancel anytime. No hidden fees. Payments securely processed by Stripe.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
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
                if userVM.isLoading {
                    LoadingOverlayView(message: "Opening checkout…")
                }
            }
            .alert("Checkout Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(userVM.errorMessage ?? "Unable to open checkout. Please try again.")
            }
        }
    }

    private func handlePlanSelection(planId: String) {
        guard authVM.isSignedIn else { showAuth = true; return }
        let billingStr = billing == .monthly ? "monthly" : "annual"
        Task {
            if let url = await userVM.createCheckoutURL(
                plan: planId,
                billing: billingStr,
                isTrial: startTrial && planId == "starter"
            ) {
                checkoutURL = url
                showSafari  = true
            } else {
                showError = true
            }
        }
    }
}

// MARK: - Safari wrapper

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
