import SwiftUI
import FirebaseAuth

struct AccountSettingsView: View {
    @Environment(AuthViewModel.self)  private var authVM
    @Environment(UserViewModel.self)  private var userVM
    @Environment(\.dismiss)          private var dismiss

    @State private var showDisplayNameEdit = false
    @State private var newDisplayName      = ""
    @State private var showDeleteAlert     = false
    @State private var showSignOutAlert    = false
    @State private var showPricing         = false
    @State private var showManagePortal    = false
    @State private var checkoutURL: URL?   = nil
    @State private var showSafari          = false
    @State private var showFAQ             = false
    @State private var showContact         = false
    @State private var showTerms           = false
    @State private var showPrivacy         = false

    @State private var refundEligibility: UserViewModel.RefundEligibility? = nil
    @State private var showRefundAlert     = false
    @State private var refundDone          = false

    private var profile: UserProfile? { userVM.profile }
    private var isGoogleUser: Bool {
        Auth.auth().currentUser?.providerData.first?.providerID == "google.com"
    }

    var body: some View {
        NavigationStack {
            List {
                profileSection
                subscriptionSection
                securitySection
                supportSection
                legalSection
                dangerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showPricing) {
            PricingView(startTrial: profile?.isTrialEligible ?? false)
        }
        .fullScreenCover(isPresented: $showSafari) {
            if let url = checkoutURL { SafariView(url: url).ignoresSafeArea() }
        }
        .sheet(isPresented: $showFAQ)     { FAQView() }
        .sheet(isPresented: $showContact) { ContactFormView() }
        .sheet(isPresented: $showTerms)   { TermsView() }
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) { authVM.signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { _ = await authVM.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all your data. This cannot be undone.")
        }
        .alert("Request Refund?", isPresented: $showRefundAlert) {
            Button("Request Refund", role: .destructive) {
                Task {
                    refundDone = await userVM.requestRefund()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your subscription will be cancelled and any payment will be refunded. This cannot be undone.")
        }
        .overlay { if userVM.isLoading { LoadingOverlayView(message: "Please wait…") } }
        .task { refundEligibility = await userVM.checkRefundEligibility() }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section("Profile") {
            LabeledContent("Email", value: profile?.email ?? authVM.firebaseUser?.email ?? "—")

            HStack {
                Text("Display Name")
                Spacer()
                Text(profile?.displayName ?? "—").foregroundStyle(.secondary)
                Button { showDisplayNameEdit = true } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(Color.brand)
                }
            }
            .sheet(isPresented: $showDisplayNameEdit) {
                displayNameSheet
            }

            if isGoogleUser {
                Label("Signed in with Google", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            LabeledContent("Status") {
                Text(profile?.subscriptionStatus.rawValue.capitalized ?? "Inactive")
                    .foregroundStyle(profile?.hasActiveAccess == true ? .green : .orange)
                    .fontWeight(.semibold)
            }
            LabeledContent("Plan", value: profile?.plan.displayName ?? "Free")

            if let end = profile?.trialEndDate, profile?.isOnTrial == true {
                LabeledContent("Trial Ends", value: end.shortFormatted)
            }

            if profile?.hasLifetimeAccess == true {
                Label("Lifetime Access", systemImage: "infinity").foregroundStyle(Color.brand)
            }

            // Credits
            if let profile = profile {
                CreditsView(
                    used: profile.totalCredits - profile.credits,
                    total: profile.totalCredits,
                    plan: profile.plan
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            Button {
                if userVM.hasActiveAccess {
                    Task {
                        if let url = await userVM.createPortalURL() {
                            checkoutURL = url
                            showSafari  = true
                        }
                    }
                } else {
                    showPricing = true
                }
            } label: {
                Label(
                    userVM.hasActiveAccess ? "Manage Subscription" : "View Plans",
                    systemImage: userVM.hasActiveAccess ? "creditcard" : "crown"
                )
            }

            // Refund
            if let eligibility = refundEligibility, eligibility.eligible {
                Button(role: .destructive) {
                    showRefundAlert = true
                } label: {
                    Label("Request Refund", systemImage: "arrow.uturn.backward")
                }
            } else if refundDone {
                Label("Refund Requested", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.success)
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            if !isGoogleUser {
                Button {
                    Task {
                        guard let email = authVM.firebaseUser?.email else { return }
                        _ = await authVM.sendPasswordReset(to: email)
                    }
                } label: {
                    Label("Send Password Reset Email", systemImage: "lock.rotation")
                }
            }
        }
    }

    private var supportSection: some View {
        Section("Support") {
            Button { showFAQ     = true } label: { Label("FAQ", systemImage: "questionmark.circle") }
            Button { showContact = true } label: { Label("Contact Support", systemImage: "envelope") }
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            Button { showTerms   = true } label: { Label("Terms of Service", systemImage: "doc.text") }
            Button { showPrivacy = true } label: { Label("Privacy Policy",   systemImage: "hand.raised") }
        }
    }

    private var dangerSection: some View {
        Section {
            Button { showSignOutAlert = true } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
            Button(role: .destructive) { showDeleteAlert = true } label: {
                Label("Delete Account", systemImage: "trash")
            }
        }
    }

    // MARK: - Display Name Sheet

    private var displayNameSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $newDisplayName)
                        .onAppear { newDisplayName = profile?.displayName ?? "" }
                }
            }
            .navigationTitle("Edit Display Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDisplayNameEdit = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            guard let uid = authVM.currentUID else { return }
                            _ = await userVM.updateDisplayName(newDisplayName, uid: uid)
                            _ = await authVM.updateDisplayName(newDisplayName)
                            showDisplayNameEdit = false
                        }
                    }
                    .disabled(newDisplayName.isEmpty)
                }
            }
        }
    }
}
