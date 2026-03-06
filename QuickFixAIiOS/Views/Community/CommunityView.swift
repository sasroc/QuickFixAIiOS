import SwiftUI

struct CommunityView: View {
    @Environment(CommunityViewModel.self) private var communityVM
    @Environment(AuthViewModel.self)      private var authVM
    @Environment(UserViewModel.self)      private var userVM

    @State private var selectedCategory  = "all"
    @State private var myPostsOnly       = false
    @State private var sortOption        = CommunitySortOption.recent
    @State private var showCreatePost    = false
    @State private var deleteTarget: CommunityPost? = nil
    @State private var showDeleteAlert   = false
    @State private var reportTarget: CommunityPost? = nil
    @State private var blockTarget: CommunityPost? = nil
    @State private var showBlockAlert    = false

    private let allCategories = ["all"] + CommunityPost.categories

    private var displayedPosts: [CommunityPost] {
        let filtered = communityVM.filtered(
            category: selectedCategory,
            myPostsOnly: myPostsOnly,
            uid: authVM.currentUID,
            blockedUsers: userVM.blockedUsers
        )
        return communityVM.sorted(filtered, by: sortOption)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "My Posts", isSelected: myPostsOnly) {
                            myPostsOnly.toggle()
                        }
                        ForEach(allCategories, id: \.self) { cat in
                            FilterChip(
                                label: cat == "all" ? "All" : cat.capitalized,
                                isSelected: selectedCategory == cat
                            ) {
                                selectedCategory = cat
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }

                // Sort toggle
                HStack {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(CommunitySortOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                // Posts
                if communityVM.isLoading {
                    Spacer()
                    ProgressView("Loading community…")
                    Spacer()
                } else if displayedPosts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(displayedPosts) { post in
                                CommunityPostCard(
                                    post: post,
                                    currentUID: authVM.currentUID,
                                    onLike: {
                                        guard let uid = authVM.currentUID else { return }
                                        Task { await communityVM.toggleLike(postId: post.id, currentUID: uid) }
                                    },
                                    onDelete: {
                                        deleteTarget = post
                                        showDeleteAlert = true
                                    },
                                    onReport: {
                                        reportTarget = post
                                    },
                                    onBlock: {
                                        blockTarget = post
                                        showBlockAlert = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if userVM.hasActiveAccess {
                            showCreatePost = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(userVM.hasActiveAccess ? Color.brand : Color.secondary)
                    }
                    .disabled(!userVM.hasActiveAccess)
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
                    .environment(communityVM)
                    .environment(authVM)
                    .environment(userVM)
            }
            .alert("Delete Post?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let p = deleteTarget {
                        Task { await communityVM.deletePost(postId: p.id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This post will be permanently removed from the community.")
            }
            .alert("Block User?", isPresented: $showBlockAlert, presenting: blockTarget) { post in
                Button("Block \(post.author)", role: .destructive) {
                    Task { await userVM.blockUser(uid: post.authorId, postId: post.id, postTitle: post.title) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { post in
                Text("You won't see posts from \(post.author) anymore. This will also notify our team to review the content.")
            }
            .sheet(item: $reportTarget) { post in
                ReportPostSheet(post: post)
                    .environment(communityVM)
                    .environment(authVM)
            }
        }
        .background(Color.appBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.3")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Posts Yet")
                .font(.title3).fontWeight(.semibold)
            Text("Be the first to share your repair success story!")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            if userVM.hasActiveAccess {
                Button { showCreatePost = true } label: {
                    Label("Share Your Story", systemImage: "plus")
                        .primaryButtonStyle()
                }
                .padding(.horizontal, 40)
            }
            Spacer()
        }
    }
}

// MARK: - Community Post Card

struct CommunityPostCard: View {
    let post: CommunityPost
    let currentUID: String?
    let onLike: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void

    @State private var expanded = false

    private var isLiked: Bool { currentUID.map { post.likedBy.contains($0) } ?? false }
    private var isOwner: Bool { currentUID == post.authorId }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.title).font(.subheadline).fontWeight(.bold).lineLimit(2)
                    Text("\(post.author) · \(post.categoryDisplayName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let ts = post.timestamp {
                    Text(ts.relativeString)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            // Before / After images
            HStack(spacing: 8) {
                beforeAfterImage(base64: post.beforeImage, label: "Before", tint: .red)
                beforeAfterImage(base64: post.afterImage,  label: "After",  tint: .green)
            }

            // Description
            Text(post.description)
                .font(.caption)
                .lineLimit(expanded ? nil : 3)
                .foregroundStyle(.secondary)

            if post.description.count > 120 {
                Button { expanded.toggle() } label: {
                    Text(expanded ? "Show less" : "Read more")
                        .font(.caption).foregroundStyle(Color.brand)
                }
            }

            // Tags
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.brand.opacity(0.1))
                                .foregroundStyle(Color.brand)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            // Footer
            HStack {
                Button(action: onLike) {
                    Label("\(post.likes)", systemImage: isLiked ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundStyle(isLiked ? .red : .secondary)
                }

                Spacer()

                if isOwner {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                } else {
                    Menu {
                        Button(role: .destructive, action: onReport) {
                            Label("Report Post", systemImage: "flag")
                        }
                        Button(role: .destructive, action: onBlock) {
                            Label("Block \(post.author)", systemImage: "nosign")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    @ViewBuilder
    private func beforeAfterImage(base64: String, label: String, tint: Color) -> some View {
        let prefix = "data:image/jpeg;base64,"
        let b64 = base64.hasPrefix(prefix) ? String(base64.dropFirst(prefix.count)) : base64

        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: label == "Before" ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption2).foregroundStyle(tint)

            if let data = Data(base64Encoded: b64), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.inputBackground)
                    .frame(height: 100)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.footnote).fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color.brand : Color.inputBackground)
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
