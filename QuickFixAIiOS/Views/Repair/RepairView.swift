import SwiftUI
import SafariServices

struct RepairView: View {
    @Environment(AuthViewModel.self)  private var authVM
    @Environment(UserViewModel.self)  private var userVM
    @Environment(RepairViewModel.self) private var repairVM
    @Environment(HistoryViewModel.self) private var historyVM

    @State private var showHistory  = false
    @State private var showPricing  = false
    @State private var showMapsURL: URL? = nil

    var body: some View {
        NavigationStack {
            SubscriptionGateView {
                VStack(spacing: 0) {
                    // Credits & trial header
                    if let profile = userVM.profile {
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
                        RepairGuideView(guide: guide, isHistorical: false) {
                            repairVM.reset()
                        }
                    } else {
                        InputFormView()
                    }
                }
            }
            .navigationTitle("QuickFix AI")
            .navigationBarTitleDisplayMode(.inline)
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
                PricingView(startTrial: userVM.profile?.isTrialEligible ?? false)
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
    }
}
