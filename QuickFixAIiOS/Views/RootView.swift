import SwiftUI

struct RootView: View {
    @Environment(AuthViewModel.self)  private var authVM
    @Environment(UserViewModel.self)  private var userVM

    @State private var paymentSucceeded = false
    @State private var showFeedback     = false

    var body: some View {
        ZStack {
            if authVM.isSignedIn {
                MainTabView(showFeedback: $showFeedback)
                    .transition(.opacity)
            } else {
                LandingView()
                    .transition(.opacity)
            }

            // Floating feedback button (shown when signed in)
            if authVM.isSignedIn {
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
                                .shadow(radius: 6)
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 90)
                        Spacer()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.isSignedIn)
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
}
