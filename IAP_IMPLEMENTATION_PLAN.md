# Apple IAP Implementation Plan

> **Trigger:** Use this plan if the App Store review rejects the Stripe-based payment flow.
> **Goal:** Replace in-app Stripe checkout with StoreKit 2 while keeping Stripe fully functional on the web. Cross-platform accounts sync transparently via Firestore.

---

## Overview

The core principle is simple: **Firestore `users/{uid}` is already the subscription source of truth.** Both Stripe (web) and Apple IAP (iOS) will write to the same fields. The app's real-time listeners, `UserProfile` computed properties, and all gated UI require zero changes.

### What Changes
| Layer | Change |
|---|---|
| **iOS app** | New `StoreKitService`, swap checkout calls in `UserViewModel`, update `PaywallView`/`PricingView`/`AccountSettingsView`, remove Stripe portal deep link from iOS |
| **Railway backend** | Add `/api/apple/verify-purchase` endpoint + App Store Server Notifications webhook |
| **Firestore schema** | Add `paymentProvider`, `appleOriginalTransactionId` fields to `users/{uid}` |
| **App Store Connect** | Create 6 subscription products (3 plans × 2 billing intervals) + configure 5-day trial offers |

### What Does NOT Change
- `UserProfile`, `SubscriptionStatus`, `SubscriptionPlan`, `BillingInterval` models
- `UserViewModel.startListening()` / real-time Firestore listener
- `hasActiveAccess`, `isTrialEligible`, `totalCredits` computed properties
- `SubscriptionGateView`, `CreditsView`, `RepairViewModel`, `HistoryViewModel`
- All Stripe endpoints on the backend (web app keeps working)
- Firestore security rules (no schema-breaking changes)

---

## Step 1 — App Store Connect Setup

### 1.1 Create Subscription Group
- Group name: **"QuickFix AI"**
- This groups all plans so a user can only hold one active subscription at a time

### 1.2 Create 6 Subscription Products

| Product ID | Display Name | Price | Duration |
|---|---|---|---|
| `com.quickfixai.starter.monthly` | Starter Monthly | $2.99/mo* | 1 month |
| `com.quickfixai.starter.annual` | Starter Annual | $24.99/yr* | 1 year |
| `com.quickfixai.pro.monthly` | Pro Monthly | $10.99/mo* | 1 month |
| `com.quickfixai.pro.annual` | Pro Annual | $84.99/yr* | 1 year |
| `com.quickfixai.premium.monthly` | Premium Monthly | $20.99/mo* | 1 month |
| `com.quickfixai.premium.annual` | Premium Annual | $179.99/yr* | 1 year |

> *Apple takes 15-30% cut. Adjust prices upward from current Stripe prices to maintain margin, or match exactly and absorb the cut. Decide before submission.

### 1.3 Configure Trial Introductory Offer
- Add a **"Free Trial"** introductory offer to all 6 products
- Duration: **5 days**
- Eligibility: First-time subscribers only (Apple enforces this automatically — no need for `wasOnTrial` flag with Apple IAP, but keep the flag for Stripe web users)

### 1.4 App Store Server Notifications
- In App Store Connect → App → App Information → App Store Server Notifications
- Set Production URL: `https://[your-railway-url]/api/apple/server-notification`
- Set Sandbox URL: same endpoint (backend checks environment from Apple's payload)
- Version 2 notifications

---

## Step 2 — iOS App Changes

### 2.1 Add StoreKit to project.yml

```yaml
# In project.yml under target frameworks/capabilities
capabilities:
  com.apple.developer.in-app-payments: []
```

StoreKit 2 is built into iOS 15+ — no SPM dependency needed. Just import `StoreKit`.

---

### 2.2 Create `QuickFixAIiOS/Services/StoreKitService.swift`

New `@MainActor @Observable` class. Responsibilities:
- Load products from App Store on init
- Expose `products: [Product]` sorted by plan tier
- `purchase(_ product: Product) async throws -> Transaction`
- `restorePurchases() async`
- Listen for transaction updates (`Transaction.updates` async sequence)
- On each verified transaction: call backend to verify + update Firestore, then finish the transaction

**Key logic:**

```swift
// Product ID → SubscriptionPlan mapping
static let productPlanMap: [String: (plan: String, billing: String)] = [
    "com.quickfixai.starter.monthly":  (plan: "starter", billing: "monthly"),
    "com.quickfixai.starter.annual":   (plan: "starter", billing: "annual"),
    "com.quickfixai.pro.monthly":      (plan: "pro",     billing: "monthly"),
    "com.quickfixai.pro.annual":       (plan: "pro",     billing: "annual"),
    "com.quickfixai.premium.monthly":  (plan: "premium", billing: "monthly"),
    "com.quickfixai.premium.annual":   (plan: "premium", billing: "annual"),
]
```

**Transaction listener (runs for lifetime of app):**
```swift
// In init(), start a Task to listen:
for await result in Transaction.updates {
    if case .verified(let transaction) = result {
        await verifyWithBackend(transaction)
        await transaction.finish()
    }
}
```

**Purchase flow:**
```swift
func purchase(_ product: Product) async throws {
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
        if case .verified(let transaction) = verification {
            await verifyWithBackend(transaction)
            await transaction.finish()
        }
    case .userCancelled, .pending:
        break
    }
}
```

---

### 2.3 Modify `AppConfig.swift`

Add product ID constants (single source of truth):

```swift
struct StoreKitProducts {
    static let starterMonthly  = "com.quickfixai.starter.monthly"
    static let starterAnnual   = "com.quickfixai.starter.annual"
    static let proMonthly      = "com.quickfixai.pro.monthly"
    static let proAnnual       = "com.quickfixai.pro.annual"
    static let premiumMonthly  = "com.quickfixai.premium.monthly"
    static let premiumAnnual   = "com.quickfixai.premium.annual"

    static let all: [String] = [
        starterMonthly, starterAnnual,
        proMonthly, proAnnual,
        premiumMonthly, premiumAnnual
    ]
}
```

---

### 2.4 Modify `UserViewModel.swift`

**Add** `StoreKitService` as a dependency (injected or instantiated here).

**Add** new purchase methods (keep existing Stripe methods — they're still used by the web flow and backend):

```swift
// NEW: Apple IAP purchase
func purchaseAppleSubscription(productId: String) async {
    guard let product = storeKitService.products.first(where: { $0.id == productId }) else { return }
    isLoading = true
    defer { isLoading = false }
    do {
        try await storeKitService.purchase(product)
        // Firestore update happens inside StoreKitService via backend call
        // UserViewModel listener picks up the change automatically
    } catch {
        errorMessage = error.localizedDescription
    }
}

// NEW: Restore purchases (required by App Store guidelines — must have a button)
func restorePurchases() async {
    await storeKitService.restorePurchases()
}

// NEW: Open App Store subscription management (replaces Stripe portal for Apple subscribers)
func openAppleSubscriptionManagement() {
    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
        UIApplication.shared.open(url)
    }
}
```

**Determine payment provider** from `profile?.paymentProvider` to decide which management UI to show:

```swift
var isAppleSubscriber: Bool {
    profile?.paymentProvider == "apple"
}
```

---

### 2.5 Modify `PaywallView.swift`

- Replace `userVM.createCheckoutURL(plan:billing:)` calls with `userVM.purchaseAppleSubscription(productId:)`
- Map each plan card's CTA to the correct product ID from `AppConfig.StoreKitProducts`
- Remove "Payments securely processed by Stripe" footer text → replace with "Payments securely processed by Apple"
- Add **"Restore Purchases"** text button in footer (App Store requirement)
- Trial CTA: use the `.starter.monthly` product — Apple's 5-day free trial introductory offer fires automatically for eligible users; no separate trial endpoint needed
- Remove `SFSafariViewController` usage from paywall

**Billing toggle:** Keep monthly/annual toggle. It selects between `.monthly` and `.annual` product IDs.

---

### 2.6 Modify `PricingView.swift`

Same changes as PaywallView:
- Swap Stripe checkout calls for StoreKit purchase calls
- Update footer text
- Add "Restore Purchases" button
- Remove Stripe portal link entirely (Apple subscribers manage via App Store)

---

### 2.7 Modify `AccountSettingsView.swift`

**Subscription management section** — conditionally show based on payment provider:

```swift
if userVM.isAppleSubscriber {
    // Show "Manage Subscription" → opens App Store subscriptions page
    Button("Manage Subscription") {
        userVM.openAppleSubscriptionManagement()
    }
    // No refund button — Apple handles refunds via App Store
} else {
    // Existing Stripe portal button (for web subscribers)
    Button("Manage Subscription") { /* open Stripe portal */ }
    // Existing refund button
}
```

Add **"Restore Purchases"** button in the account section (required by App Store guidelines).

---

### 2.8 Modify `QuickFixAIiOSApp.swift`

Inject `StoreKitService` as an environment object alongside existing ViewModels:

```swift
@State private var storeKitService = StoreKitService()
// Pass into UserViewModel and/or environment
```

---

## Step 3 — Firestore Schema Additions

Add two new optional fields to `users/{uid}`. These are additive — no existing fields change.

| Field | Type | Values | Purpose |
|---|---|---|---|
| `paymentProvider` | String? | `"stripe"` \| `"apple"` | Which platform manages the subscription |
| `appleOriginalTransactionId` | String? | Apple transaction ID | Links Firestore user to Apple subscription for server notification matching |

**UserProfile model additions:**

```swift
var paymentProvider: String?               // "stripe" | "apple" | nil
var appleOriginalTransactionId: String?    // Set by backend on IAP verify
```

Update `init?(id:data:)` to decode these fields (both optional, so no breaking change).

---

## Step 4 — Railway Backend Changes

### 4.1 Add `POST /api/apple/verify-purchase`

Called by the iOS app immediately after a successful StoreKit transaction.

**Request body:**
```json
{
  "uid": "firebase_uid",
  "transactionId": "apple_transaction_id",
  "originalTransactionId": "apple_original_transaction_id",
  "productId": "com.quickfixai.pro.monthly"
}
```

**Backend logic:**
1. Verify the transaction with Apple's App Store Server API (use the signed JWT from StoreKit 2 — no receipt base64 needed)
2. Parse `productId` → map to `plan` + `billingInterval`
3. Update `users/{uid}` in Firestore:
   ```json
   {
     "subscriptionStatus": "active",
     "plan": "pro",
     "billingInterval": "monthly",
     "credits": 25,
     "paymentProvider": "apple",
     "appleOriginalTransactionId": "...",
     "isOnTrial": false,
     "wasOnTrial": true,
     "lastCreditReset": serverTimestamp()
   }
   ```
4. Return `{ success: true }`

**On trial purchase:** Set `isOnTrial: true`, `wasOnTrial: true`, `subscriptionStatus: "trialing"`, `trialEndDate: now + 5 days`

---

### 4.2 Add `POST /api/apple/server-notification`

Apple calls this for all subscription lifecycle events. Maps directly to the existing Stripe webhook Firestore update logic.

**Notification types to handle:**

| Apple Notification Type | Action |
|---|---|
| `SUBSCRIBED` | Set `subscriptionStatus: active`, reset credits |
| `DID_RENEW` | Set `subscriptionStatus: active`, reset credits |
| `DID_CHANGE_RENEWAL_STATUS` (auto-renew off) | No immediate change (subscription still active until period end) |
| `EXPIRED` | Set `subscriptionStatus: canceled` |
| `GRACE_PERIOD_EXPIRED` | Set `subscriptionStatus: pastDue` |
| `REFUND` | Set `subscriptionStatus: canceled`, credits to 0 |
| `DID_CHANGE_RENEWAL_PREF` (plan change) | Update `plan` + `billingInterval` on next renewal |

**Lookup user by `originalTransactionId`:** Query Firestore `users` collection where `appleOriginalTransactionId == notification.originalTransactionId`.

---

### 4.3 Keep All Existing Stripe Endpoints

No changes. Web app continues working identically.

---

## Step 5 — Testing Checklist

### Sandbox Testing
- [ ] All 6 products load in `StoreKitService` (use StoreKit Config file in Xcode for local testing first)
- [ ] Purchase flow completes and Firestore updates within ~2 seconds
- [ ] `UserViewModel` listener picks up update; `hasActiveAccess` returns `true`
- [ ] `PaywallView` dismisses after successful purchase
- [ ] Trial offer appears for new sandbox accounts; does not appear for accounts that already used trial
- [ ] `AccountSettingsView` shows "Manage Subscription" for Apple subscribers (not Stripe portal)
- [ ] "Restore Purchases" restores an active subscription on a fresh install
- [ ] Cancellation via App Store sandbox → `EXPIRED` notification → Firestore sets `subscriptionStatus: canceled`
- [ ] Renewal → `DID_RENEW` → credits reset in Firestore

### Cross-Platform Testing
- [ ] Subscribe via Stripe on web → sign into iOS app → `hasActiveAccess == true`
- [ ] Subscribe via Apple IAP on iOS → sign into web app → subscription reflected correctly
- [ ] Stripe subscriber sees Stripe portal option in Account, not App Store link
- [ ] Apple subscriber sees App Store management in Account, not Stripe portal

### App Store Compliance
- [ ] "Restore Purchases" button present and functional
- [ ] No mention of Stripe or external payment options anywhere in the iOS app UI
- [ ] No links to the website's pricing/subscription page from within the app
- [ ] Privacy policy and terms of service accessible from the app

---

## Step 6 — App Store Connect Additional Requirements

- [ ] Add `NSUserTrackingUsageDescription` if not already present (if using any attribution)
- [ ] Subscription renewal disclosure: "Subscription automatically renews unless canceled at least 24 hours before the end of the current period"
- [ ] Add this disclosure to `PaywallView` footer and `PricingView` footer
- [ ] In App Store Connect → App Review Information: provide sandbox test account credentials

---

## File Change Summary

| File | Action | Notes |
|---|---|---|
| `Services/StoreKitService.swift` | **CREATE** | StoreKit 2 product loading, purchase, transaction listener |
| `Config/AppConfig.swift` | **MODIFY** | Add `StoreKitProducts` constants |
| `Models/User.swift` | **MODIFY** | Add `paymentProvider`, `appleOriginalTransactionId` fields |
| `ViewModels/UserViewModel.swift` | **MODIFY** | Add `purchaseAppleSubscription()`, `restorePurchases()`, `openAppleSubscriptionManagement()`, `isAppleSubscriber` |
| `Views/Pricing/PaywallView.swift` | **MODIFY** | Swap Stripe → StoreKit calls, update footer, add Restore button |
| `Views/Pricing/PricingView.swift` | **MODIFY** | Same as PaywallView |
| `Views/Account/AccountSettingsView.swift` | **MODIFY** | Conditional Stripe portal vs. App Store management |
| `QuickFixAIiOSApp.swift` | **MODIFY** | Inject `StoreKitService` |
| `project.yml` | **MODIFY** | Add In-App Purchase capability |
| **Railway backend** | **MODIFY** | Add `/api/apple/verify-purchase` + `/api/apple/server-notification` |

---

## Notes

- **No Stripe code is deleted from the iOS app.** `UserViewModel`'s existing Stripe methods stay in place. They become dead code paths on iOS (only the web calls them), but removing them risks breaking the backend API integration if ever needed.
- **Trial flag `wasOnTrial`** — Apple enforces trial eligibility natively per Apple ID, but the Firestore `wasOnTrial` flag still prevents the trial UI from showing for users who previously trialed via Stripe on web. Both systems coexist correctly.
- **Refunds** — Apple processes refunds through the App Store. The `REFUND` server notification triggers the same Firestore update as the Stripe refund webhook. Remove the manual refund button in `AccountSettingsView` for Apple subscribers.
- **Upgrade/Downgrade** — StoreKit 2 handles plan changes natively. The `DID_CHANGE_RENEWAL_PREF` notification updates Firestore on the next renewal. For immediate downgrades, StoreKit prorates and the backend updates on the `SUBSCRIBED` notification for the new plan.
