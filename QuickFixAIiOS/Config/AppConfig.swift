import Foundation

enum AppConfig {
    // MARK: - Backend
    static let apiBaseURL = "https://quickfix-ai-powered-home-maintenance-advisor-production.up.railway.app"

    // MARK: - RevenueCat
    /// Public SDK key from RevenueCat dashboard → Project Settings → API Keys.
    static let revenueCatAPIKey = "appl_DneRXuzkugsEFOHdViSZyohwxUt"

    /// RevenueCat entitlement identifier — must match the entitlement ID you
    /// create in the RevenueCat dashboard (e.g. "pro_access").
    enum Entitlements {
        static let proAccess = "pro_access"
    }

    // MARK: - Experiments
    enum Experiments {
        /// RC offering ID for paywall variant B. Create this offering in the
        /// RevenueCat dashboard and use it as the treatment in an Experiment.
        static let paywallVariantBOfferingId = "paywall_v2"
    }

    // MARK: - Stripe (web-based checkout, opened in Safari)
    static let stripeSuccessURL = "quickfixai://payment-success"
    static let stripeCancelURL  = "quickfixai://payment-cancel"

    // MARK: - StoreKit Product IDs
    enum StoreKitProducts {
        static let proMonthly  = "com.quickfixai.pro.monthly"
        static let proLifetime = "com.quickfixai.pro.lifetime"

        static let all: [String] = [proMonthly, proLifetime]

        /// Returns the product ID for a given plan + billing combination.
        static func productId(plan: String, billing: String) -> String {
            "com.quickfixai.\(plan).\(billing)"
        }
    }

    // MARK: - Trial
    static let trialPeriodDays = 7

    // MARK: - Plans
    struct PlanInfo {
        let id: String
        let displayName: String
        let credits: Int       // monthly credits
        let historyCap: Int?   // nil = unlimited
        let monthlyPrice: Double
        let lifetimePrice: Double
        let aiModel: String
        let features: [String]
        let lifetimeFeatures: [String]
    }

    static let plans: [PlanInfo] = [
        PlanInfo(
            id: "pro",
            displayName: "Pro",
            credits: 10,
            historyCap: nil,
            monthlyPrice: 4.99,
            lifetimePrice: 49.99,
            aiModel: "GPT-4o Mini",
            features: [
                "10 AI repairs / month",
                "Unlimited repair history",
                "GPT-4o Mini model",
                "Image analysis",
                "Priority support"
            ],
            lifetimeFeatures: [
                "Unlimited AI repairs forever",
                "Unlimited repair history",
                "GPT-4o Mini model",
                "Image analysis",
                "Priority support"
            ]
        )
    ]

    static func plan(for id: String) -> PlanInfo? {
        plans.first { $0.id == id }
    }
}
