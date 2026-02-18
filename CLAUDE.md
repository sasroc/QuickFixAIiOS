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

**Entry point:** `QuickFixAIiOSApp.swift` configures Firebase, creates all ViewModels as `@State`, injects them via `.environment()`, and starts/stops Firestore listeners when auth state changes.

**Navigation:**
- Unauthenticated → `LandingView` (full marketing page)
- Authenticated → `MainTabView` (4 tabs: Repair, History, Community, Account)
- Stripe checkout opens in `SFSafariViewController`; payment success detected via `quickfixai://payment-success` deep link

**ViewModels** (all `@MainActor @Observable`):
| ViewModel | Responsibility |
|---|---|
| `AuthViewModel` | Firebase Auth (email/password, Google Sign-In), sign-out, delete account |
| `UserViewModel` | Real-time Firestore listener on `users/{uid}`, Stripe checkout/portal URLs, refund |
| `RepairViewModel` | POST `/api/ai/analyze`, image compression, save to Firestore `repairs/` |
| `HistoryViewModel` | Real-time Firestore listener on `repairs/` for current user |
| `CommunityViewModel` | Real-time listener on `community_posts/`, likes, create/delete posts |

**Key Services:**
- `APIService` — async/await HTTP client; attaches Firebase JWT Bearer token automatically
- `FirestoreService.swift` — only contains the `Timestamp: @retroactive FirestoreTimestampProtocol` conformance

**Firestore collections:** `users/{uid}`, `repairs/{repairId}`, `community_posts/{postId}`, `feedback/{feedbackId}`

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
| `POST /api/support/contact` | None | Send support email |
| `POST /api/feedback/submit` | None | Multipart feedback with screenshots |
| `POST /api/welcome` | None | Send welcome email |

## Subscription / Credits Logic

- `SubscriptionPlan`: `.none` (3 credits), `.starter` (10), `.pro` (25), `.premium` (100)
- History caps: Starter=10, Pro=50, Premium=unlimited
- Trial: 5-day Starter, one-time per account (`wasOnTrial` prevents reuse)
- Lifetime access: `hasLifetimeAccess: true` → behaves like Starter, immune to Stripe webhooks
- Credits reset is handled by Stripe webhook on the backend; frontend reads live Firestore data

## Color Convention

Colors are defined in `Extensions/Color+Extensions.swift` and match the webapp CSS variables exactly:

| Token | Hex | Usage |
|---|---|---|
| `Color.brandBlue` | `#3b82f6` | Hero gradient start, step number circles |
| `Color.brand` | `#20c997` (teal) | Buttons, badges, all interactive elements |
| `Color.brandGreen` / `Color.success` | `#10b981` | Checkmarks, success states |
| `Color.appBackground` | `#f3f4f6` | Page background (light) |
| `Color.cardBackground` | white / `#1f2937` | Cards (adaptive light/dark) |

- Always use `Color.brand` explicitly (not shorthand `.brand`) in `foregroundStyle()` — Swift cannot infer the type
- `Color.cardBackground` / `Color.inputBackground` use `UIColor` adaptive initializers (requires `import UIKit` — SourceKit may show a false-positive "No such module UIKit" warning that does not affect compilation)
- `Color.brandGradient` (blue→teal) for hero sections; `Color.ctaGradient` for CTA buttons

## SPM Dependencies

- `firebase-ios-sdk` v11+ → FirebaseAuth, FirebaseFirestore, FirebaseAnalytics
- `GoogleSignIn-iOS` v8+ → GoogleSignIn, GoogleSignInSwift
