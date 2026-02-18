import SwiftUI

struct CreditsView: View {
    let used: Int
    let total: Int
    let plan: SubscriptionPlan

    private var remaining: Int { max(total - used, 0) }
    private var progress: Double { total > 0 ? Double(used) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(remaining) / \(total) credits", systemImage: "bolt.fill")
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundStyle(remaining == 0 ? .red : .brand)
                Spacer()
                Text(plan.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brand.opacity(0.15))
                    .foregroundStyle(Color.brand)
                    .cornerRadius(8)
            }

            ProgressView(value: progress)
                .tint(progress > 0.8 ? .red : .brand)
        }
        .padding(10)
        .background(Color.cardBackground)
        .cornerRadius(10)
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
