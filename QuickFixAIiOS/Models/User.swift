import Foundation

// MARK: - Enums

enum SubscriptionStatus: String, Codable, Equatable {
    case inactive
    case active
    case canceled
    case pastDue   = "past_due"
    case trialing

    var isActiveOrTrialing: Bool {
        self == .active || self == .trialing
    }
}

enum SubscriptionPlan: String, Codable, Equatable {
    case none
    case starter
    case pro
    case premium

    var displayName: String {
        switch self {
        case .none:    return "Free"
        case .starter: return "Starter"
        case .pro:     return "Pro"
        case .premium: return "Premium"
        }
    }

    var credits: Int {
        switch self {
        case .none:    return 3
        case .starter: return 10
        case .pro:     return 25
        case .premium: return 100
        }
    }

    var historyCap: Int? {
        switch self {
        case .none:    return nil
        case .starter: return 10
        case .pro:     return 50
        case .premium: return nil
        }
    }
}

enum BillingInterval: String, Codable {
    case monthly
    case annual
}

// MARK: - UserProfile

struct UserProfile: Equatable {
    let uid: String
    var email: String
    var displayName: String
    var subscriptionStatus: SubscriptionStatus
    var credits: Int
    var plan: SubscriptionPlan
    var isAdmin: Bool
    var billingInterval: BillingInterval?
    var stripeCustomerId: String?
    var stripeSubscriptionId: String?
    var isOnTrial: Bool
    var wasOnTrial: Bool
    var trialStartDate: Date?
    var trialEndDate: Date?
    var hasLifetimeAccess: Bool
    var lastCreditReset: Date?
    var createdAt: Date?
    var paymentProvider: String?             // "stripe" | "apple" | nil
    var appleOriginalTransactionId: String?  // set by backend on IAP verify

    // MARK: Computed

    var hasActiveAccess: Bool {
        subscriptionStatus.isActiveOrTrialing || hasLifetimeAccess
    }

    var isTrialEligible: Bool {
        !wasOnTrial && !hasLifetimeAccess && subscriptionStatus != .active
    }

    var isAppleSubscriber: Bool {
        paymentProvider == "apple"
    }

    var totalCredits: Int {
        hasLifetimeAccess ? SubscriptionPlan.starter.credits : plan.credits
    }

    // MARK: Init from Firestore data

    init(uid: String, data: [String: Any]) {
        self.uid = uid
        self.email              = data["email"] as? String ?? ""
        self.displayName        = data["displayName"] as? String ?? ""
        self.isAdmin            = data["isAdmin"] as? Bool ?? false
        self.credits            = data["credits"] as? Int ?? 0
        self.hasLifetimeAccess  = data["hasLifetimeAccess"] as? Bool ?? false
        self.isOnTrial          = data["isOnTrial"] as? Bool ?? false
        self.wasOnTrial         = data["wasOnTrial"] as? Bool ?? false
        self.stripeCustomerId            = data["stripeCustomerId"] as? String
        self.stripeSubscriptionId       = data["stripeSubscriptionId"] as? String
        self.paymentProvider            = data["paymentProvider"] as? String
        self.appleOriginalTransactionId = data["appleOriginalTransactionId"] as? String

        self.subscriptionStatus = SubscriptionStatus(rawValue: data["subscriptionStatus"] as? String ?? "inactive") ?? .inactive
        self.plan               = SubscriptionPlan(rawValue: data["plan"] as? String ?? "none") ?? .none
        self.billingInterval    = BillingInterval(rawValue: data["billingInterval"] as? String ?? "")

        // Firestore Timestamps → Date
        self.trialStartDate  = (data["trialStartDate"]  as? any FirestoreTimestampProtocol)?.dateValue()
        self.trialEndDate    = (data["trialEndDate"]    as? any FirestoreTimestampProtocol)?.dateValue()
        self.lastCreditReset = (data["lastCreditReset"] as? any FirestoreTimestampProtocol)?.dateValue()
        self.createdAt       = (data["createdAt"]       as? any FirestoreTimestampProtocol)?.dateValue()
    }
}

// Protocol so we can call .dateValue() without importing FirebaseFirestore in the Model layer
protocol FirestoreTimestampProtocol {
    func dateValue() -> Date
}
