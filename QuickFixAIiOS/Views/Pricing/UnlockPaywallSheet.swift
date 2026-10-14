import SwiftUI

/// The pre-access paywall presented as a dismissable sheet when the user taps a
/// locked repair guide (paywall-after-diagnosis test). Uses the same design as
/// the upfront paywall so the test only varies timing.
struct UnlockPaywallSheet: View {
    @Environment(RevenueCatService.self) private var revenueCatService
    @Environment(\.dismiss)              private var dismiss

    var body: some View {
        if revenueCatService.paywallVariant == .treatment {
            PaywallVariantBView(onClose: { dismiss() })
        } else {
            originalPaywall
        }
    }

    private var originalPaywall: some View {
        PaywallView(isUnlockSheet: true)
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.cardBackground)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
                .padding(.top, 16)
                .padding(.trailing, 16)
            }
    }
}
