import SwiftUI
import PhotosUI

struct FeedbackModalView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackType = "general"
    @State private var title        = ""
    @State private var description  = ""
    @State private var email        = ""
    @State private var priority     = "medium"
    @State private var steps        = ""
    @State private var expected     = ""
    @State private var actual       = ""
    @State private var photoItems   : [PhotosPickerItem] = []
    @State private var screenshots  : [UIImage] = []
    @State private var isSubmitting = false
    @State private var submitSuccess = false
    @State private var errorMessage : String? = nil

    private let types      = ["general", "bug", "feature"]
    private let priorities = ["low", "medium", "high", "critical"]

    var body: some View {
        NavigationStack {
            if submitSuccess {
                successView
            } else {
                Form {
                    Section("Feedback Type") {
                        Picker("Type", selection: $feedbackType) {
                            ForEach(types, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Details") {
                        TextField("Title (required)", text: $title)
                        Picker("Priority", selection: $priority) {
                            ForEach(priorities, id: \.self) { Text($0.capitalized).tag($0) }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description (required)").font(.footnote).foregroundStyle(.secondary)
                            TextEditor(text: $description).frame(height: 100)
                        }
                    }

                    if feedbackType == "bug" {
                        Section("Bug Details") {
                            TextField("Steps to reproduce", text: $steps, axis: .vertical)
                            TextField("Expected behavior", text: $expected)
                            TextField("Actual behavior",   text: $actual)
                        }
                    }

                    Section("Contact") {
                        TextField("Email (optional)", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }

                    Section {
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) {
                            Label("Add Screenshots (max 3)", systemImage: "photo.badge.plus")
                                .foregroundStyle(Color.brand)
                        }
                        ForEach(screenshots.indices, id: \.self) { i in
                            Image(uiImage: screenshots[i])
                                .resizable().scaledToFill()
                                .frame(height: 80).clipped().cornerRadius(6)
                        }
                    } header: {
                        Text("Screenshots")
                    }

                    if let error = errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.caption) }
                    }
                }
                .navigationTitle("Send Feedback")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") { Task { await submit() } }
                            .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                            .fontWeight(.semibold)
                    }
                }
                .overlay { if isSubmitting { LoadingOverlayView(message: "Sending…") } }
            }
        }
        .onChange(of: photoItems) { _, items in
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img  = UIImage(data: data) {
                        images.append(img)
                    }
                }
                screenshots = images
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.success)
            Text("Feedback Sent!").font(.title2).fontWeight(.bold)
            Text("Thank you. We'll review your feedback and get back to you if needed.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            Button("Close") { dismiss() }
                .primaryButtonStyle()
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        var fields: [String: String] = [
            "type":      feedbackType,
            "title":     title,
            "description": description,
            "priority":  priority,
            "email":     email,
            "userId":    authVM.currentUID ?? "anonymous",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if feedbackType == "bug" {
            fields["steps"]    = steps
            fields["expected"] = expected
            fields["actual"]   = actual
        }

        let imagePayloads = screenshots.compactMap { img -> (data: Data, fieldName: String, filename: String)? in
            guard let d = img.jpegData(compressionQuality: 0.7) else { return nil }
            return (d, "screenshots", "screenshot-\(UUID().uuidString).jpg")
        }

        do {
            try await APIService.shared.postMultipart(
                "/api/feedback/submit",
                fields: fields,
                images: imagePayloads
            )
            submitSuccess = true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
