import Foundation

enum AppConfig {
    // MARK: - Backend
    /// Replace with your Railway backend URL (no trailing slash)
    static let apiBaseURL = "https://quickfix-ai-powered-home-maintenance-advisor-production.up.railway.app"

    // MARK: - Stripe (web-based checkout, opened in Safari)
    static let stripeSuccessURL = "quickfixai://payment-success"
    static let stripeCancelURL  = "quickfixai://payment-cancel"

    // MARK: - Trial
    static let trialPeriodDays = 5

    // MARK: - Plans
    struct PlanInfo {
        let id: String        // "starter" | "pro" | "premium"
        let displayName: String
        let credits: Int
        let historyCap: Int?  // nil = unlimited
        let monthlyPrice: Double
        let annualPrice: Double   // per month
        let annualTotal: Double
        let aiModel: String
        let features: [String]
    }

    static let plans: [PlanInfo] = [
        PlanInfo(
            id: "starter",
            displayName: "Starter",
            credits: 10,
            historyCap: 10,
            monthlyPrice: 2.00,
            annualPrice: 2.00,
            annualTotal: 24.00,
            aiModel: "GPT-4.1 Nano",
            features: [
                "10 AI repairs / month",
                "GPT-4.1 Nano model",
                "10 saved repairs",
                "Image analysis"
            ]
        ),
        PlanInfo(
            id: "pro",
            displayName: "Pro",
            credits: 25,
            historyCap: 50,
            monthlyPrice: 10.00,
            annualPrice: 7.00,
            annualTotal: 84.00,
            aiModel: "GPT-4o Mini",
            features: [
                "25 AI repairs / month",
                "GPT-4o Mini model",
                "50 saved repairs",
                "Image analysis",
                "Priority support"
            ]
        ),
        PlanInfo(
            id: "premium",
            displayName: "Premium",
            credits: 100,
            historyCap: nil,
            monthlyPrice: 20.00,
            annualPrice: 15.00,
            annualTotal: 180.00,
            aiModel: "GPT-4o",
            features: [
                "100 AI repairs / month",
                "GPT-4o model",
                "Unlimited repair history",
                "Image analysis",
                "Priority support"
            ]
        )
    ]

    static func plan(for id: String) -> PlanInfo? {
        plans.first { $0.id == id }
    }
}
