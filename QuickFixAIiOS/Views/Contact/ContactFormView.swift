import SwiftUI

struct ContactFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email      = ""
    @State private var subject    = ""
    @State private var message    = ""
    @State private var isSending  = false
    @State private var sent       = false
    @State private var errorMsg   : String? = nil

    struct MessageResponse: Decodable { let message: String }

    var body: some View {
        NavigationStack {
            if sent {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "envelope.badge.fill").font(.system(size: 64)).foregroundStyle(Color.brand)
                    Text("Message Sent!").font(.title2).fontWeight(.bold)
                    Text("We'll get back to you within 24 hours.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Close") { dismiss() }.primaryButtonStyle().padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            } else {
                Form {
                    Section {
                        TextField("Your Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
                        TextField("Subject", text: $subject)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message").font(.footnote).foregroundStyle(.secondary)
                            TextEditor(text: $message).frame(height: 120)
                        }
                    }
                    if let err = errorMsg {
                        Section { Text(err).foregroundStyle(.red).font(.caption) }
                    }
                }
                .navigationTitle("Contact Support")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") { Task { await send() } }
                            .disabled(email.isEmpty || subject.isEmpty || message.isEmpty || isSending)
                            .fontWeight(.semibold)
                    }
                }
                .overlay { if isSending { LoadingOverlayView(message: "Sending…") } }
            }
        }
    }

    private func send() async {
        isSending = true
        errorMsg  = nil
        defer { isSending = false }
        do {
            try await APIService.shared.post(
                "/api/support/contact",
                body: ["email": email, "subject": subject, "message": message]
            )
            sent = true
        } catch {
            errorMsg = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
