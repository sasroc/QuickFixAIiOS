#if DEBUG
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

/// DEBUG-only tools for walking through paywall flows by hand.
/// Open it by shaking the device (Simulator: Device → Shake, ⌃⌘Z).
struct DebugMenuView: View {
    @Environment(UserViewModel.self)     private var userVM
    @Environment(RepairViewModel.self)   private var repairVM
    @Environment(RevenueCatService.self) private var revenueCatService
    @Environment(\.dismiss)              private var dismiss

    @State private var statusMessage: String? = nil

    private var profile: UserProfile? { userVM.profile }

    var body: some View {
        NavigationStack {
            List {
                timingSection
                accountSection
                actionsSection
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color.appBackground)
        }
    }

    // MARK: - Sections

    private var timingSection: some View {
        Section {
            Picker("Paywall timing", selection: Bindable(revenueCatService).debugPaywallTimingOverride) {
                Text("RevenueCat assignment").tag(PaywallTiming?.none)
                Text("Upfront (control)").tag(PaywallTiming?.some(.upfront))
                Text("After first diagnosis").tag(PaywallTiming?.some(.afterFirstDiagnosis))
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Paywall timing test")
        } footer: {
            Text("RevenueCat assigned: \(label(for: revenueCatService.assignedPaywallTiming)). The override is saved on this device and only exists in Debug builds.")
        }
    }

    private var accountSection: some View {
        Section("Current account") {
            row("Signed in as", profile?.email ?? "—")
            LabeledContent("User ID (RevenueCat)") {
                Text(profile?.uid ?? "—").textSelection(.enabled)
            }
            row("Active access", yesNo(userVM.hasActiveAccess))
            row("Never subscribed", yesNo(!(profile?.hasEverSubscribed ?? true)))
            row("Free diagnosis used", yesNo(profile?.freeDiagnosisUsed ?? false))
            row("Credits", profile.map { "\($0.credits)" } ?? "—")
            row("In free-diagnosis preview", yesNo(userVM.isInDiagnosisPreview(timing: revenueCatService.paywallTiming)))
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Reset free diagnosis") {
                run("Free diagnosis reset") { try await userVM.debugResetFreeDiagnosis() }
                repairVM.reset()
            }
            .disabled(userVM.hasActiveAccess)

            Button("Replay onboarding") {
                run("Onboarding reset") { try await userVM.debugResetOnboarding() }
                dismiss()
            }
        } header: {
            Text("Actions")
        } footer: {
            if userVM.hasActiveAccess {
                Text("This account has an active subscription, so it never sees the paywall. Sign in with an account that has no subscription to test the flow.")
            } else if let statusMessage {
                Text(statusMessage)
            }
        }
    }

    // MARK: - Helpers

    private func run(_ success: String, _ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                statusMessage = success
            } catch {
                statusMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private func yesNo(_ value: Bool) -> String { value ? "Yes" : "No" }

    private func label(for timing: PaywallTiming) -> String {
        switch timing {
        case .upfront:             return "Upfront"
        case .afterFirstDiagnosis: return "After first diagnosis"
        }
    }
}

// MARK: - UserViewModel debug helpers

extension UserViewModel {
    /// Makes the account eligible for the free diagnosis again.
    func debugResetFreeDiagnosis() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await Firestore.db.collection("users").document(uid).updateData([
            "freeDiagnosisUsed": FieldValue.delete(),
            "freeDiagnosisAt":   FieldValue.delete()
        ])
    }

    func debugResetOnboarding() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await Firestore.db.collection("users").document(uid).updateData([
            "hasCompletedOnboarding": false
        ])
    }
}

// MARK: - Shake gesture

extension UIDevice {
    static let deviceDidShake = Notification.Name("debugDeviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShake)) { _ in
            action()
        }
    }
}
#endif
