import SwiftUI

struct RootView: View {
    @Environment(AuthViewModel.self)  private var authVM
    @Environment(UserViewModel.self)  private var userVM

    @State private var paymentSucceeded = false

    var body: some View {
        ZStack {
            content
                .animation(.easeInOut(duration: 0.3), value: authVM.isSignedIn)
                .animation(.easeInOut(duration: 0.3), value: userVM.hasActiveAccess)
        }
        .onOpenURL { url in
            if url.scheme == "quickfixai" && url.host == "payment-success" {
                paymentSucceeded = true
            }
        }
        .sheet(isPresented: $paymentSucceeded) {
            PaymentSuccessView()
        }
        .sheet(isPresented: Bindable(authVM).showDisplayNameModal) {
            DisplayNameModalView()
                .environment(authVM)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !authVM.isSignedIn {
            // Not signed in → clean auth screen
            AuthScreen()
                .transition(.opacity)

        } else if !userVM.profileLoaded {
            // Signed in but waiting for first Firestore response
            profileLoadingView
                .transition(.opacity)

        } else if userVM.hasActiveAccess {
            // Signed in + active subscription → full app
            MainTabView()
                .transition(.opacity)

        } else {
            // Signed in + no active subscription → paywall
            PaywallView()
                .transition(.opacity)
        }
    }

    private var profileLoadingView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandBlue, Color.brand],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)

                HStack(spacing: 0) {
                    Text("QuickFix")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(" AI")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.yellow)
                }

                ProgressView()
                    .tint(.white)
                    .padding(.top, 8)
            }
        }
    }
}
