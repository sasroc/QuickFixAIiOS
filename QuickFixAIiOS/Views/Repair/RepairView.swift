import SwiftUI
import SafariServices

struct RepairView: View {
    @Environment(AuthViewModel.self)  private var authVM
    @Environment(UserViewModel.self)  private var userVM
    @Environment(RepairViewModel.self) private var repairVM
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(RevenueCatService.self) private var revenueCatService

    @State private var showHistory  = false
    @State private var showPricing  = false
    @State private var showUnlockPaywall = false
    @State private var showMapsURL: URL? = nil

    private var isPreview: Bool {
        userVM.isInDiagnosisPreview(timing: revenueCatService.paywallTiming)
    }

    var body: some View {
        NavigationStack {
            SubscriptionGateView(previewAccess: isPreview) {
                VStack(spacing: 0) {
                    // Credits & trial header
                    if isPreview, let profile = userVM.profile {
                        FreeDiagnosisBanner(isAvailable: profile.canRunFreeDiagnosis)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    } else if let profile = userVM.profile {
                        VStack(spacing: 8) {
                            CreditsView(
                                used: profile.totalCredits - profile.credits,
                                total: profile.totalCredits,
                                plan: profile.plan
                            )
                            if profile.isOnTrial {
                                TrialStatusBannerView(trialEndDate: profile.trialEndDate)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    Divider().padding(.top, 8)

                    // Main content
                    if let guide = repairVM.currentGuide {
                        RepairGuideView(
                            guide: guide,
                            isHistorical: false,
                            onBack: { repairVM.reset() },
                            onUnlock: isPreview ? { showUnlockPaywall = true } : nil
                        )
                    } else if isPreview, userVM.profile?.canRunFreeDiagnosis == false {
                        FreeDiagnosisUsedView { showUnlockPaywall = true }
                    } else {
                        InputFormView()
                    }
                }
            }
            .navigationTitle("QuickFix AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                LinearGradient(colors: [Color.brandBlue, Color.brand], startPoint: .leading, endPoint: .trailing),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Label("History", systemImage: "clock")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showPricing = true
                    } label: {
                        Label("Plans", systemImage: "crown")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                RepairHistoryView()
            }
            .sheet(isPresented: $showPricing) {
                PricingView(startTrial: userVM.profile?.canStartFreeTrial ?? false)
            }
            .sheet(isPresented: $showUnlockPaywall) {
                UnlockPaywallSheet()
            }
            .onChange(of: userVM.hasActiveAccess) { _, hasAccess in
                if hasAccess { showUnlockPaywall = false }
            }
            .overlay {
                if repairVM.isAnalyzing {
                    LoadingOverlayView(message: "Analyzing... \(repairVM.timerDisplay)")
                }
            }
            .alert("Error", isPresented: .constant(repairVM.errorMessage != nil)) {
                Button("OK") { repairVM.errorMessage = nil }
            } message: {
                Text(repairVM.errorMessage ?? "")
            }
        }
        .background(Color.appBackground)
    }
}

// MARK: - Free Diagnosis (paywall-after-diagnosis test)

/// Replaces the credits header for users in the free-diagnosis preview.
private struct FreeDiagnosisBanner: View {
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isAvailable ? "gift.fill" : "lock.fill")
                .font(.caption)
                .foregroundStyle(Color.brand)
            Text(isAvailable ? "Your first diagnosis is free" : "Free diagnosis used")
                .font(.footnote).fontWeight(.semibold)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.brand.opacity(0.1))
        .cornerRadius(10)
    }
}

/// Shown in place of the input form once the free diagnosis has been spent.
private struct FreeDiagnosisUsedView: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brand)

            Text("You've used your free diagnosis")
                .font(.title3).fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Subscribe to unlock step-by-step fixes and diagnose more repairs.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button(action: onUnlock) {
                HStack {
                    Image(systemName: "lock.open.fill")
                    Text("Unlock QuickFix AI")
                }
                .primaryButtonStyle()
            }
            .padding(.horizontal, 30)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
