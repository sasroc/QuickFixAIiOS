import SwiftUI

struct RootView: View {
    @Environment(AuthViewModel.self)  private var authVM
    @Environment(UserViewModel.self)  private var userVM

    @State private var paymentSucceeded = false
    @State private var showFeedback     = false

    var body: some View {
        ZStack {
            content
                .animation(.easeInOut(duration: 0.3), value: authVM.isSignedIn)
                .animation(.easeInOut(duration: 0.3), value: userVM.hasActiveAccess)

            // Floating feedback button (only when using the full app)
            if authVM.isSignedIn && userVM.hasActiveAccess {
                VStack {
                    Spacer()
                    HStack {
                        Button {
                            showFeedback = true
                        } label: {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(Color.brand)
                                .clipShape(Circle())
                                .shadow(color: Color.brand.opacity(0.4), radius: 8, y: 3)
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 90)
                        Spacer()
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onOpenURL { url in
            if url.scheme == "quickfixai" && url.host == "payment-success" {
                paymentSucceeded = true
            }
        }
        .sheet(isPresented: $paymentSucceeded) {
            PaymentSuccessView()
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackModalView()
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
            MainTabView(showFeedback: $showFeedback)
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
