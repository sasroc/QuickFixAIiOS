import Foundation
import StoreKit
import SwiftUI

/// Owns every rule about when the App Store review prompt may be shown.
///
/// Call `requestReviewIfAppropriate(using:)` from a genuine success moment only —
/// the user has a completed AI repair guide *and* has explicitly confirmed it
/// helped. The manager records the success, applies the fatigue rules below, and
/// only then asks the system for the prompt.
///
/// The request is silent-failing by design: iOS decides whether to actually show
/// the dialog and never reports back, so nothing in the app may depend on it
/// appearing. There is deliberately no custom "rate us" pre-prompt — Apple's
/// guidelines discourage it.
///
/// Gates (all must pass):
/// - at least `minimumSuccessfulRepairs` confirmed successes (never on the first)
/// - at least `minimumDaysBetweenRequests` days since the last request
/// - fewer than `maximumRequestsPerYear` requests in the trailing 365 days
/// - the current app version has not already asked
@MainActor
final class ReviewRequestManager {
    static let shared = ReviewRequestManager()

    // MARK: - Tuning

    private let minimumSuccessfulRepairs    = 2
    private let minimumDaysBetweenRequests  = 90
    private let maximumRequestsPerYear      = 3  // Apple hard-caps at 3 per 365 days
    private let presentationDelay: Duration = .milliseconds(1_500)

    #if DEBUG
    /// Bypasses every gate so the prompt can be exercised during testing.
    /// Flip it in code, or launch with the `-forceReviewRequest YES` argument
    /// (Xcode → Edit Scheme → Run → Arguments → Arguments Passed On Launch).
    /// While forcing, no request is recorded, so the real gating state stays clean.
    static var forceReviewRequest = UserDefaults.standard.bool(forKey: "forceReviewRequest")
    #endif

    // MARK: - Storage

    private enum Key {
        static let successfulRepairCount       = "successfulRepairCount"
        static let lastReviewRequestDate       = "lastReviewRequestDate"
        static let reviewRequestDates          = "reviewRequestDates"
        static let lastReviewRequestAppVersion = "lastReviewRequestAppVersion"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Records a confirmed successful repair and, if every gate passes, asks the
    /// system to show the App Store review prompt after a short delay.
    ///
    /// Call this exactly once per positive confirmation. Safe to call whenever a
    /// success is confirmed — the gating is entirely internal.
    func requestReviewIfAppropriate(using requestReview: RequestReviewAction) {
        recordSuccessfulRepair()
        guard shouldRequestReview() else { return }

        Task {
            // Let the success state render first so the alert doesn't feel jarring.
            try? await Task.sleep(for: presentationDelay)
            recordReviewRequested()
            requestReview()
        }
    }

    // MARK: - Stored state

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var successfulRepairCount: Int {
        defaults.integer(forKey: Key.successfulRepairCount)
    }

    private var lastReviewRequestDate: Date? {
        defaults.object(forKey: Key.lastReviewRequestDate) as? Date
    }

    private var lastReviewRequestAppVersion: String? {
        defaults.string(forKey: Key.lastReviewRequestAppVersion)
    }

    /// Requests made inside the trailing 365 days. Derived from the stored request
    /// timestamps rather than a separate counter, so the window rolls continuously
    /// instead of resetting on a fixed anniversary.
    private var reviewRequestCountThisYear: Int {
        recentReviewRequestDates().count
    }

    private func recentReviewRequestDates(now: Date = Date()) -> [Date] {
        let cutoff = now.addingTimeInterval(-365 * 24 * 60 * 60)
        let stored = defaults.array(forKey: Key.reviewRequestDates) as? [Double] ?? []
        return stored.map(Date.init(timeIntervalSince1970:)).filter { $0 > cutoff }
    }

    // MARK: - Gating

    private func recordSuccessfulRepair() {
        defaults.set(successfulRepairCount + 1, forKey: Key.successfulRepairCount)
    }

    private func shouldRequestReview(now: Date = Date()) -> Bool {
        #if DEBUG
        if Self.forceReviewRequest { return true }
        #endif

        guard successfulRepairCount >= minimumSuccessfulRepairs else { return false }
        guard reviewRequestCountThisYear < maximumRequestsPerYear else { return false }
        guard lastReviewRequestAppVersion != appVersion else { return false }

        if let last = lastReviewRequestDate {
            let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
            guard days >= minimumDaysBetweenRequests else { return false }
        }

        return true
    }

    /// iOS never tells us whether the dialog appeared, so — per Apple's own
    /// guidance — a request counts as spent the moment it is made.
    private func recordReviewRequested(now: Date = Date()) {
        #if DEBUG
        if Self.forceReviewRequest { return }
        #endif

        defaults.set(now, forKey: Key.lastReviewRequestDate)
        defaults.set(appVersion, forKey: Key.lastReviewRequestAppVersion)
        let dates = (recentReviewRequestDates(now: now) + [now]).map(\.timeIntervalSince1970)
        defaults.set(dates, forKey: Key.reviewRequestDates)
    }

    #if DEBUG
    /// Clears all gating state so the flow can be re-tested from scratch.
    func resetForTesting() {
        [Key.successfulRepairCount,
         Key.lastReviewRequestDate,
         Key.reviewRequestDates,
         Key.lastReviewRequestAppVersion].forEach(defaults.removeObject(forKey:))
    }
    #endif
}
