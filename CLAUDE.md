# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

QuickFixAI iOS — a SwiftUI iOS app that mirrors the QuickFix AI web app. It calls the existing Railway backend (Express/Node.js) and uses Firebase Auth + Firestore for auth and data.

## Build & Test

```bash
# Regenerate Xcode project after editing project.yml
xcodegen generate

# Build for simulator
xcodebuild -scheme QuickFixAIiOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -scheme QuickFixAIiOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test suite
xcodebuild -scheme QuickFixAIiOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:QuickFixAIiOSTests/QuickFixAIiOSTests test
```

Open `QuickFixAIiOS.xcodeproj` in Xcode for day-to-day development. **Never hand-edit the `.xcodeproj`** — edit `project.yml` and re-run `xcodegen`.

## Required Setup Before First Run

1. **Firebase** — `GoogleService-Info.plist` is **gitignored** (contains secrets). Add it to `QuickFixAIiOS/` in Xcode and ensure it is a member of the target. The `REVERSED_CLIENT_ID` URL scheme in `project.yml` is already set.

2. **Backend URL** — already set in `QuickFixAIiOS/Config/AppConfig.swift` to the Railway deployment.

3. **Signing** — set your Apple Developer Team in Xcode → Signing & Capabilities, or in `project.yml` under `DEVELOPMENT_TEAM`.

## Architecture

**Pattern:** MVVM with SwiftUI, `@Observable` macro (iOS 17+), environment-injected ViewModels.

**Entry point:** `QuickFixAIiOSApp.swift` configures Firebase, creates all ViewModels and `StoreKitService` as `@State`, injects them via `.environment()`, and starts/stops Firestore listeners when auth state changes. `AuthViewModel.init()` is intentionally empty — `startListening()` is called from `.task {}` in the app body, after Firebase is guaranteed to be configured via `AppDelegate`.

**Navigation:**
- `RootView.swift` navigation states: not signed in → `LandingView`; signed in + profile loading → gradient spinner; signed in + no active access → `PaywallView`; signed in + active access → `MainTabView`. All transitions use opacity animation.
- `LandingView` has a "Get Started" button that presents `AuthScreen` (full-screen branded gate). Tapping "Continue with Email" on `AuthScreen` opens `AuthView` (email/password form) as a sheet. Both views also offer Google and Sign in with Apple.
- `MainTabView` — 3 tabs: Repair, History, Account
- In-app purchases use StoreKit 2 natively (no browser). The `quickfixai://payment-success` deep link and `SFSafariViewController` (via `SafariView` wrapper in `PricingView.swift`) remain for Stripe web flows.

**ViewModels** (all `@MainActor @Observable`):
| ViewModel | Responsibility |
|---|---|
| `AuthViewModel` | Firebase Auth (email/password, Google Sign-In, Sign in with Apple), sign-out, delete account |
| `UserViewModel` | Real-time Firestore listener on `users/{uid}`, Stripe checkout/portal URLs, refund |
| `RepairViewModel` | POST `/api/ai/analyze`, image compression, save to Firestore `repairs/` |
| `HistoryViewModel` | Real-time Firestore listener on `repairs/` for current user |

**Key Services:**
- `APIService` (singleton) — async/await HTTP client with methods `post<T>()`, `get<T>()`, `patch<T>()`, `delete()`, `postMultipart()`. Attaches Firebase JWT Bearer token automatically; `requiresAuth: true` fails without token, `false` attaches opportunistically. 90s timeout.
- `FirestoreService.swift` — only contains `Timestamp: @retroactive FirestoreTimestampProtocol` conformance, bridging Firebase timestamps to Models without importing Firebase there.
- `RevenueCatService` (`@MainActor @Observable`, file: `Services/StoreKitService.swift`) — wraps RevenueCat SDK for IAP. Exposes `purchase(productId:)` and `restorePurchases()`. On a successful purchase, calls `/api/apple/verify-purchase` with the JWS token from `result.transaction?.jwsRepresentation` to keep Firestore in sync (until RC webhooks replace this). RC is configured in `AppDelegate`; user is identified via `Purchases.shared.logIn(uid)` / `logOut()` in `QuickFixAIiOSApp` when Firebase auth state changes. Injected as an environment object.

**Firestore listener lifecycle:** `App.onChange(authVM.firebaseUser)` calls `userVM.startListening(uid)` and `historyVM.startListening()` on sign-in and their corresponding `stopListening()` on sign-out. Use `nonisolated(unsafe) var listenerHandle` for `ListenerRegistration` stored in `@MainActor` classes so `deinit` can remove them.

**Firestore collections:** `users/{uid}`, `repairs/{repairId}`, `feedback/{feedbackId}`

**Image handling:** Compressed to 800px max width, 0.7 JPEG quality before sending. Repair images are sent to the backend as `data:image/jpeg;base64,...` data URIs.

**Sign in with Apple:** `AuthViewModel.prepareAppleSignInRequest(_:)` and `handleAppleSignInResult(_:)` handle the ASAuthorization flow. Uses `SignInWithAppleButton` (SwiftUI native) in auth views.

## Backend API (existing Railway deployment)

All calls go to `AppConfig.apiBaseURL`. Key endpoints:

| Endpoint | Auth | Description |
|---|---|---|
| `POST /api/ai/analyze` | Optional | AI repair analysis. Body: `{description, image?, uid?}` |
| `POST /api/stripe/subscribe` | None | Create Stripe checkout. Body: `{uid, plan, billing}` |
| `POST /api/stripe/start-trial` | None | Start 5-day trial checkout |
| `POST /api/stripe/create-portal-session` | Required | Stripe customer portal URL |
| `POST /api/stripe/refund` | Required | Full refund (24-hr, 0-credit policy) |
| `GET /api/stripe/refund-eligibility/:uid` | Required | Check refund eligibility |
| `POST /api/apple/verify-purchase` | Required | Verify StoreKit JWS transaction server-side; updates Firestore subscription fields |
| `POST /api/support/contact` | None | Send support email |
| `POST /api/feedback/submit` | None | Multipart feedback with screenshots |
| `POST /api/welcome` | None | Send welcome email |

## Subscription / Credits Logic

- `SubscriptionPlan`: `.none` (3 credits), `.starter` (10), `.pro` (25), `.premium` (100)
- History caps: Starter=10, Pro=50, Premium=unlimited
- Trial: 5-day Starter, one-time per account (`wasOnTrial` prevents reuse)
- Lifetime access: `hasLifetimeAccess: true` → behaves like Starter, immune to Stripe/Apple webhooks
- Credits reset is handled server-side (Stripe webhook or Apple server notification); frontend reads live Firestore data
- `paymentProvider` field (`"stripe"` | `"apple"`) on `UserProfile` determines which management UI to show; `UserViewModel.isAppleSubscriber` exposes this. Apple subscribers manage via App Store; Stripe subscribers see the portal.
- **Local IAP testing:** `Products.storekit` (root of repo) is the StoreKit configuration file. In Xcode → scheme editor → Run → Options → StoreKit Configuration, point to this file to test purchases without hitting App Store Connect.
- **Product IDs:** `AppConfig.StoreKitProducts` enum holds all 6 IDs (starter/pro/premium × monthly/annual). Use `AppConfig.StoreKitProducts.productId(plan:billing:)` to look them up; never hardcode product IDs in views.

## Color Convention

Colors are defined in `Extensions/Color+Extensions.swift` and match the webapp CSS variables exactly:

| Token | Hex | Usage |
|---|---|---|
| `Color.brandBlue` | `#3b82f6` | Hero gradient start, step number circles |
| `Color.brand` | `#20c997` (teal) | Buttons, badges, all interactive elements |
| `Color.brandGreen` / `Color.success` | `#10b981` | Checkmarks, success states |
| `Color.appBackground` | `#f3f4f6` / `#111827` | Page background (adaptive light/dark) |
| `Color.cardBackground` | white / `#1f2937` | Cards (adaptive light/dark) |

- Always use `Color.brand` explicitly (not shorthand `.brand`) in `foregroundStyle()` — Swift cannot infer the type
- Always add `.background(Color.appBackground)` to every `ScrollView` and `NavigationStack` — without it, dark mode shows black behind content
- `Color.cardBackground` / `Color.inputBackground` use `UIColor` adaptive initializers (requires `import UIKit` — SourceKit may show a false-positive "No such module UIKit" warning that does not affect compilation)
- `Color.brandGradient` (blue→teal) for hero sections; `Color.ctaGradient` for CTA buttons

## Models

Each model has two init patterns and a Firestore write helper:
- `init(from AI response)` — takes typed fields from `AIAnalyzeResponse` or ViewModel logic
- `init?(id:data:)` — failable init from Firestore `[String: Any]` document data
- `firestoreData: [String: Any]` — computed property on `RepairGuide` for writing to Firestore

**Firestore schema constraints on `RepairGuide.firestoreData`** (must match Firestore security rules):
- `estimatedTime` is written as a **String** (`"45 minutes"`), not an Int — matches web app and security rule schema
- `steps` array only writes `description`; the `image` field is iOS-only and excluded
- `imageBase64` is intentionally omitted from Firestore writes (not in security rule schema)

`FirestoreTimestampProtocol` is declared in `Models/User.swift`; `FirestoreService.swift` provides the `@retroactive` conformance for `Timestamp`. Models import neither Firebase nor FirestoreService.

**`UserProfile` key computed properties:**
- `hasActiveAccess` — `subscriptionStatus.isActiveOrTrialing || hasLifetimeAccess`
- `isTrialEligible` — `!wasOnTrial && !hasLifetimeAccess && subscriptionStatus != .active`
- `totalCredits` — lifetime users get Starter credits (10) regardless of plan

## View Utilities

**`Extensions/View+Extensions.swift`:**
- `.cardStyle()` — padding + `cardBackground` + `cornerRadius(12)`
- `.primaryButtonStyle(disabled:)` — full-width, `brand` color (gray when disabled), 14pt vertical padding
- `.shake(trigger:)` — 8pt shake animation for validation errors
- `.if(condition) { }` — conditional ViewBuilder modifier

**`Extensions/Date+Extensions.swift`:**
- `.relativeString` — abbreviated relative format ("2 hr. ago")
- `.shortFormatted` — medium date, no time
- `.mediumFormatted` — medium date + short time
- `.isMoreThan(_ hours:since:)` — elapsed time check (used for refund eligibility)

**`Views/Common/SubscriptionGateView`** — generic wrapper that shows content for subscribed users or a locked paywall prompt otherwise. Wrap any gated feature content with `SubscriptionGateView { ... }`.

**`Views/Repair/InputFormView.swift`** — contains a nested `final class SpeechRecorder` that uses `SFSpeechRecognizer` + `AVAudioEngine` for real-time voice-to-text transcription of the repair description. Also contains a `CameraPicker` `UIViewControllerRepresentable`. Both require Info.plist permissions already set in `project.yml`: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.

**`AppConfig.plans`** — the source of truth for all plan pricing, credit counts, and feature lists shown in `PaywallView` and `PricingView`. Update pricing here, not in views.

## Tests

Tests use the **Swift Testing** framework (`import Testing`, `@Suite`, `@Test`, `#expect`) — not XCTest. Test files live in `QuickFixAIiOSTests/`. The single test suite name for `-only-testing:` is `QuickFixAIiOSTests/QuickFixAIiOSTests`.

## SPM Dependencies

- `firebase-ios-sdk` v11+ → FirebaseAuth, FirebaseFirestore, FirebaseAnalytics
- `GoogleSignIn-iOS` v8+ → GoogleSignIn, GoogleSignInSwift
- `purchases-ios` v5+ → RevenueCat
