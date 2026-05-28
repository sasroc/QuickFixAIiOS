import SwiftUI

struct CreditsView: View {
    let used: Int
    let total: Int
    let plan: SubscriptionPlan

    private var isUnlimited: Bool { total >= UserProfile.unlimitedSentinel }
    private var remaining: Int { max(total - used, 0) }
    private var progress: Double { total > 0 ? Double(used) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: isUnlimited ? "infinity" : "bolt.fill")
                        .font(.caption)
                        .foregroundStyle((!isUnlimited && remaining == 0) ? .red : Color.brand)
                    Text(isUnlimited ? "Unlimited repairs" : "\(remaining) of \(total) repairs remaining")
                        .font(.footnote).fontWeight(.semibold)
                        .foregroundStyle((!isUnlimited && remaining == 0) ? .red : .primary)
                }
                Spacer()
                Text(plan.displayName)
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        LinearGradient(
                            colors: [Color.brandBlue.opacity(0.12), Color.brand.opacity(0.12)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundStyle(Color.brand)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brand.opacity(0.25), lineWidth: 1))
            }

            if !isUnlimited {
                // Custom gradient progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.inputBackground)
                            .frame(height: 7)
                        Capsule()
                            .fill(
                                remaining == 0
                                    ? LinearGradient(colors: [.red, .red], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.brandBlue, Color.brand], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(geo.size.width * progress, 0), height: 7)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 7)
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [Color.brandBlue.opacity(0.15), Color.brand.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct TrialStatusBannerView: View {
    let trialEndDate: Date?

    var body: some View {
        if let end = trialEndDate, end > Date() {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.fill")
                    .foregroundStyle(.yellow)
                Text("Trial ends \(end.relativeString)")
                    .font(.footnote).fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.12))
            .cornerRadius(8)
        }
    }
}
