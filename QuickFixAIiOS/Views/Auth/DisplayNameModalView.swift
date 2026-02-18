import SwiftUI

struct DisplayNameModalView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss)         private var dismiss

    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.brand)

                VStack(spacing: 8) {
                    Text("What's your name?")
                        .font(.title2).fontWeight(.bold)
                    Text("This will be shown on community posts and your profile.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Display name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .padding(.horizontal)

                Button {
                    Task {
                        let success = await authVM.updateDisplayName(name)
                        if success { dismiss() }
                    }
                } label: {
                    if authVM.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save Name")
                    }
                }
                .primaryButtonStyle(disabled: name.trimmingCharacters(in: .whitespaces).isEmpty)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal)

                Button("Skip for now") { dismiss() }
                    .font(.footnote).foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Set Display Name")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
