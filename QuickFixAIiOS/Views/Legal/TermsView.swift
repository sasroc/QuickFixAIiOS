import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.title).fontWeight(.bold)

                    Text("Last updated: January 2025")
                        .font(.caption).foregroundStyle(.secondary)

                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title).font(.headline)
                            Text(section.body).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private let sections: [(title: String, body: String)] = [
        (
            "1. Acceptance of Terms",
            "By accessing and using QuickFix AI, you agree to be bound by these Terms of Service. If you do not agree, please do not use our service."
        ),
        (
            "2. Service Description",
            "QuickFix AI provides AI-powered home repair guidance for informational purposes only. The guidance is not a substitute for professional advice. Always consult a licensed professional for electrical, plumbing, or structural work."
        ),
        (
            "3. User Accounts",
            "You are responsible for maintaining the security of your account. You agree not to share your account credentials with others."
        ),
        (
            "4. Subscription & Billing",
            "Subscriptions are billed monthly or annually. You can cancel anytime. Cancellation takes effect at the end of the current billing period. Refunds are available within 24 hours of first payment if no credits have been used."
        ),
        (
            "5. Limitation of Liability",
            "QuickFix AI is provided 'as is' without warranty of any kind. We are not liable for any damages resulting from the use of our service or following our repair guidance."
        ),
        (
            "6. Changes to Terms",
            "We may update these terms at any time. Continued use of the service constitutes acceptance of the updated terms."
        ),
        (
            "7. Contact",
            "For questions about these terms, contact us at support@quickfixai.com"
        )
    ]
}
