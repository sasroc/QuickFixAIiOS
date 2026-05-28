import SwiftUI

struct PlanCardView: View {
    let plan: AppConfig.PlanInfo
    let billing: BillingType
    let isCurrentPlan: Bool
    let onSelect: () -> Void

    enum BillingType { case monthly, lifetime }

    private var priceLabel: String {
        billing == .monthly
            ? String(format: "$%.2f/mo", plan.monthlyPrice)
            : String(format: "$%.2f one-time", plan.lifetimePrice)
    }

    private var lifetimeSavings: String? {
        guard billing == .lifetime else { return nil }
        let saved = (plan.monthlyPrice * 12) - plan.lifetimePrice
        return saved > 0 ? String(format: "Save $%.2f vs. 1 year", saved) : nil
    }

    private var displayedFeatures: [String] {
        billing == .lifetime ? plan.lifetimeFeatures : plan.features
    }

    private var isPro: Bool { plan.id == "pro" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Badge for recommended
            if isPro {
                Text("Most Popular")
                    .font(.caption2).fontWeight(.bold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.yellow)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0))
                    .cornerRadius(20)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.displayName)
                        .font(.title3).fontWeight(.bold)
                    Text(plan.aiModel)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceLabel)
                        .font(.title2).fontWeight(.heavy).foregroundStyle(Color.brand)
                    if let savings = lifetimeSavings {
                        Text(savings)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.success.opacity(0.15))
                            .foregroundStyle(Color.success)
                            .cornerRadius(4)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(displayedFeatures, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.success)
                            .font(.footnote)
                        Text(feature).font(.footnote)
                        Spacer()
                    }
                }
            }

            Button(action: onSelect) {
                Text(isCurrentPlan ? "Current Plan" : billing == .lifetime ? "Get Lifetime Access" : "Choose \(plan.displayName)")
                    .primaryButtonStyle(disabled: isCurrentPlan)
            }
            .disabled(isCurrentPlan)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isPro ? Color.brand : Color.clear, lineWidth: 2)
        )
        .shadow(color: isPro ? Color.brand.opacity(0.15) : Color.clear, radius: 8)
    }
}
