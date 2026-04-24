import SwiftUI

/// Wraps content in a subscription gate — shows PricingView if user lacks active access.
struct SubscriptionGateView<Content: View>: View {
    @Environment(UserViewModel.self) private var userVM
    @State private var showPricing = false

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if userVM.hasActiveAccess {
                content()
            } else {
                lockedView
            }
        }
        .sheet(isPresented: $showPricing) {
            PricingView(startTrial: userVM.profile?.isTrialEligible ?? false)
        }
    }

    private var lockedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brand)

            Text("Subscription Required")
                .font(.title2).fontWeight(.bold)

            Text("Get instant AI-powered repair guidance with a QuickFix AI subscription.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            VStack(spacing: 12) {
                Button { showPricing = true } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(userVM.profile?.isTrialEligible == true ? "Start \(AppConfig.trialPeriodDays)-Day Free Trial" : "View Plans")
                    }
                    .primaryButtonStyle()
                }
                .padding(.horizontal, 30)

                if userVM.isLoading {
                    ProgressView()
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
