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

    // MARK: - Stripe (web-based checkout, opened in Safari)
    static let stripeSuccessURL = "quickfixai://payment-success"
    static let stripeCancelURL  = "quickfixai://payment-cancel"

    // MARK: - StoreKit Product IDs
    enum StoreKitProducts {
        static let starterMonthly  = "com.quickfixai.starter.monthly"
        static let starterAnnual   = "com.quickfixai.starter.annual"
        static let proMonthly      = "com.quickfixai.pro.monthly"
        static let proAnnual       = "com.quickfixai.pro.annual"
        static let premiumMonthly  = "com.quickfixai.premium.monthly"
        static let premiumAnnual   = "com.quickfixai.premium.annual"

        static let all: [String] = [
            starterMonthly, starterAnnual,
            proMonthly, proAnnual,
            premiumMonthly, premiumAnnual,
        ]

        /// Returns the product ID for a given plan + billing combination.
        static func productId(plan: String, billing: String) -> String {
            "com.quickfixai.\(plan).\(billing)"
        }
    }

    // MARK: - Trial
    static let trialPeriodDays = 7

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
