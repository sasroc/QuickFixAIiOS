import Testing
@testable import QuickFixAIiOS

@Suite("QuickFix AI Tests")
struct QuickFixAIiOSTests {

    @Test("RepairGuide init from Firestore data")
    func repairGuideInit() {
        let data: [String: Any] = [
            "userId": "uid123",
            "title": "Fix leaky faucet",
            "steps": [
                ["description": "Turn off water supply", "image": nil as Any?]
            ],
            "tools": ["Wrench", "Pliers"],
            "materials": ["Plumber's tape"],
            "estimatedTime": 30,
            "confidenceScore": 90
        ]

        let guide = RepairGuide(id: "doc1", data: data)
        #expect(guide != nil)
        #expect(guide?.title == "Fix leaky faucet")
        #expect(guide?.steps.count == 1)
        #expect(guide?.tools == ["Wrench", "Pliers"])
        #expect(guide?.estimatedTime == 30)
    }

    @Test("UserProfile subscription check")
    func userProfileAccess() {
        let data: [String: Any] = [
            "email": "test@test.com",
            "displayName": "Test User",
            "subscriptionStatus": "active",
            "credits": 10,
            "plan": "starter",
            "isAdmin": false,
            "isOnTrial": false,
            "wasOnTrial": false,
            "hasLifetimeAccess": false
        ]
        let profile = UserProfile(uid: "uid1", data: data)
        #expect(profile.hasActiveAccess == true)
        #expect(profile.plan == .starter)
    }

    @Test("SubscriptionPlan credits")
    func planCredits() {
        #expect(SubscriptionPlan.starter.credits == 10)
        #expect(SubscriptionPlan.pro.credits == 25)
        #expect(SubscriptionPlan.premium.credits == 100)
    }

    @Test("SubscriptionPlan history caps")
    func planHistoryCaps() {
        #expect(SubscriptionPlan.starter.historyCap == 10)
        #expect(SubscriptionPlan.pro.historyCap == 50)
        #expect(SubscriptionPlan.premium.historyCap == nil)
    }
}
