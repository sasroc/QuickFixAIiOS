import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(CommunityViewModel.self) private var communityVM
    @Environment(AuthViewModel.self)      private var authVM
    @Environment(UserViewModel.self)      private var userVM
    @Environment(\.dismiss)              private var dismiss

    @State private var title       = ""
    @State private var category    = CommunityPost.categories.first ?? "general"
    @State private var description = ""
    @State private var tagsText    = ""

    @State private var beforeItem: PhotosPickerItem? = nil
    @State private var afterItem:  PhotosPickerItem? = nil
    @State private var beforeImage: UIImage? = nil
    @State private var afterImage:  UIImage? = nil

    private var canSubmit: Bool {
        !title.isEmpty && !description.isEmpty && beforeImage != nil && afterImage != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Post Details") {
                    TextField("Title (max 200 chars)", text: $title)
                        .onChange(of: title) { _, v in if v.count > 200 { title = String(v.prefix(200)) } }

                    Picker("Category", selection: $category) {
                        ForEach(CommunityPost.categories, id: \.self) { cat in
                            Text(cat.capitalized).tag(cat)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.footnote).foregroundStyle(.secondary)
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .onChange(of: description) { _, v in
                                if v.count > 2000 { description = String(v.prefix(2000)) }
                            }
                    }

                    TextField("Tags (comma separated)", text: $tagsText)
                }

                Section {
                    photoPicker(item: $beforeItem, image: $beforeImage, label: "Before Photo")
                    photoPicker(item: $afterItem,  image: $afterImage,  label: "After Photo")
                } header: {
                    Text("Before & After Photos")
                } footer: {
                    Text("Both photos are required. Images are compressed for upload.")
                }

                if let error = communityVM.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Share Your Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        guard canSubmit,
                              let before = beforeImage,
                              let after  = afterImage,
                              let uid    = authVM.currentUID
                        else { return }

                        let tags = tagsText.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }

                        Task {
                            let displayName = userVM.profile?.displayName ?? authVM.firebaseUser?.displayName ?? "Anonymous"
                            let success = await communityVM.createPost(
                                title: title,
                                category: category,
                                description: description,
                                tags: tags,
                                beforeImage: before,
                                afterImage: after,
                                authorDisplayName: displayName,
                                authorId: uid
                            )
                            if success { dismiss() }
                        }
                    }
                    .disabled(!canSubmit || communityVM.isSubmitting)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if communityVM.isSubmitting {
                    LoadingOverlayView(message: "Posting…")
                }
            }
        }
        .onChange(of: beforeItem) { _, item in
            Task { beforeImage = await loadImage(from: item) }
        }
        .onChange(of: afterItem) { _, item in
            Task { afterImage = await loadImage(from: item) }
        }
    }

    @ViewBuilder
    private func photoPicker(item: Binding<PhotosPickerItem?>, image: Binding<UIImage?>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let img = image.wrappedValue {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            }
            PhotosPicker(selection: item, matching: .images) {
                Label(image.wrappedValue != nil ? "Change \(label)" : "Choose \(label)",
                      systemImage: "photo.badge.plus")
                    .font(.subheadline)
                    .foregroundStyle(Color.brand)
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let data = try? await item?.loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }
}
