import SwiftUI

struct ReportPostSheet: View {
    @Environment(CommunityViewModel.self) private var communityVM
    @Environment(AuthViewModel.self)      private var authVM
    @Environment(\.dismiss)              private var dismiss

    let post: CommunityPost

    private let reasons = [
        "Spam or advertising",
        "Inappropriate or offensive content",
        "Misinformation",
        "Harassment or bullying",
        "Unrelated to home repair",
        "Other"
    ]

    @State private var selectedReason: String? = nil
    @State private var submitted = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    successView
                } else {
                    reasonList
                }
            }
            .navigationTitle("Report Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if !submitted {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            submitReport()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedReason == nil || isSubmitting)
                    }
                }
            }
        }
    }

    private var reasonList: some View {
        List(reasons, id: \.self) { reason in
            Button {
                selectedReason = reason
            } label: {
                HStack {
                    Text(reason)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedReason == reason {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.brand)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if isSubmitting {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView()
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandGreen)
            Text("Report Submitted")
                .font(.title2).fontWeight(.bold)
            Text("Thank you for keeping our community safe. We review all reports within 24 hours and will take appropriate action.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button("Done") { dismiss() }
                .primaryButtonStyle()
                .padding(.horizontal, 40)
                .padding(.top, 8)
            Spacer()
        }
    }

    private func submitReport() {
        guard let reason = selectedReason, let uid = authVM.currentUID else { return }
        isSubmitting = true
        Task {
            await communityVM.reportPost(
                postId: post.id,
                postTitle: post.title,
                reportedUserId: post.authorId,
                currentUID: uid,
                reason: reason
            )
            isSubmitting = false
            submitted = true
        }
    }
}
