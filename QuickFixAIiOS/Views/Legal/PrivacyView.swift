import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
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
            .navigationTitle("Privacy Policy")
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
            "1. Information We Collect",
            "We collect your email address, display name, and repair descriptions when you use our service. If you upload photos, they are processed by our AI and stored securely in your account."
        ),
        (
            "2. How We Use Your Information",
            "Your information is used to provide repair guidance, manage your subscription, and improve our service. We do not sell your personal data to third parties."
        ),
        (
            "3. Data Storage",
            "Your data is stored securely using Firebase (Google Cloud) with encryption at rest and in transit. Repair guides are stored in your private account."
        ),
        (
            "4. Third-Party Services",
            "We use Firebase (authentication & database), Stripe (payments), SendGrid (email), and OpenAI (AI analysis). Each has their own privacy policy."
        ),
        (
            "5. Data Retention",
            "Your data is retained as long as your account is active. You can delete your account at any time from Account Settings, which removes all your data."
        ),
        (
            "6. Cookies",
            "Our iOS app does not use browser cookies. Analytics data is collected via Firebase Analytics to improve our service."
        ),
        (
            "7. Your Rights",
            "You have the right to access, correct, or delete your personal data. Contact us at privacy@quickfixai.com for any privacy-related requests."
        ),
        (
            "8. Contact",
            "For privacy questions, contact us at privacy@quickfixai.com"
        )
    ]
}
