import SwiftUI
import PhotosUI
import Speech
import AVFoundation

struct InputFormView: View {
    @Environment(RepairViewModel.self) private var repairVM

    @FocusState private var isFocused: Bool
    @State private var description    = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isRecording    = false
    @State private var pulse          = false
    @State private var showCamera     = false
    @State private var isScanMode     = false
    private let recorder              = SpeechRecorder()

    // Scan flow: no description required (image alone is enough)
    private var canSubmit: Bool {
        let hasText = !description.trimmingCharacters(in: .whitespaces).isEmpty
        return (hasText || selectedImage != nil) && !repairVM.isAnalyzing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Scan hero ────────────────────────────────────────────
                VStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandBlue, Color.brand],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.brand.opacity(0.4), radius: 16, y: 6)

                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("Scan Any Repair Issue")
                            .font(.title2).fontWeight(.heavy)
                        Text("Point your camera at the problem and get\na full step-by-step repair guide instantly.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Scan button
                    Button {
                        isScanMode = true
                        showCamera = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Scan Issue")
                                .font(.title3).fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color.brandBlue, Color.brand],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .shadow(color: Color.brand.opacity(0.4), radius: 12, y: 5)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal)
                .padding(.top, 28)

                // ── Divider ───────────────────────────────────────────────
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color(UIColor.separator))
                        .frame(height: 1)
                    Text("or describe manually")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Rectangle()
                        .fill(Color(UIColor.separator))
                        .frame(height: 1)
                }
                .padding(.horizontal)

                // ── Text input card ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {

                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble.fill")
                                .foregroundStyle(Color.brand)
                                .font(.subheadline)
                            Text("Describe the Problem")
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        Spacer()
                        Button { toggleVoice() } label: {
                            HStack(spacing: 5) {
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.caption.weight(.bold))
                                Text(isRecording ? "Stop" : "Voice")
                                    .font(.caption).fontWeight(.semibold)
                            }
                            .foregroundStyle(isRecording ? .red : Color.brand)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(isRecording ? Color.red.opacity(0.1) : Color.brand.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    Divider()

                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("e.g. My kitchen faucet is dripping slowly...")
                                .foregroundStyle(.tertiary)
                                .font(.body)
                                .padding(.horizontal, 14)
                                .padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $description)
                            .scrollContentBackground(.hidden)
                            .font(.body)
                            .frame(minHeight: 110)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .focused($isFocused)
                    }

                    Divider()

                    HStack {
                        if isRecording {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .opacity(pulse ? 0.25 : 1)
                                    .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
                                    .onAppear { pulse = true }
                                    .onDisappear { pulse = false }
                                Text("Listening…")
                                    .font(.caption).foregroundStyle(.red)
                            }
                        } else {
                            Text("More detail = better results")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if !description.isEmpty {
                            Text("\(description.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color.brandBlue, Color.brand],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color(UIColor.quaternaryLabel)),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .shadow(
                    color: isFocused ? Color.brandBlue.opacity(0.12) : Color.black.opacity(0.04),
                    radius: isFocused ? 10 : 3,
                    y: 2
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .padding(.horizontal)

                // ── Gallery photo picker ──────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a Photo (Optional)").font(.headline)

                    if let image = selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipped()
                                .cornerRadius(10)

                            Button {
                                selectedImage = nil
                                selectedPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(8)
                        }
                    } else {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.subheadline.weight(.medium))
                                Text("Choose from Library")
                                    .font(.subheadline).fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.brandBlue.opacity(0.07))
                            .foregroundStyle(Color.brandBlue)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBlue.opacity(0.2), lineWidth: 1.5))
                        }
                    }
                }
                .padding(.horizontal)

                // ── Submit (text/gallery path) ────────────────────────────
                Button {
                    Task { await repairVM.analyze(description: description, image: selectedImage) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                        Text("Get Repair Guide")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        canSubmit
                            ? LinearGradient(colors: [Color.brandBlue, Color.brand], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .shadow(color: canSubmit ? Color.brand.opacity(0.35) : .clear, radius: 8, y: 4)
                }
                .disabled(!canSubmit)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded { isFocused = false })
        .background(Color.appBackground)
        .onChange(of: selectedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .onChange(of: selectedImage) { _, image in
            // Auto-analyze when photo captured via Scan button
            if isScanMode, let image {
                isScanMode = false
                Task { await repairVM.analyze(description: "", image: image) }
            }
        }
        .onChange(of: repairVM.currentGuide) { _, guide in
            if guide != nil {
                description   = ""
                selectedImage = nil
                selectedPhoto = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
    }

    // MARK: - Voice

    private func toggleVoice() {
        if isRecording {
            recorder.stop { text in
                if !text.isEmpty {
                    description += (description.isEmpty ? "" : " ") + text
                }
                isRecording = false
            }
        } else {
            recorder.start(onPartialResult: { partial in
                description = partial
            })
            isRecording = true
        }
    }
}

// MARK: - Camera picker wrapper

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Speech Recorder

final class SpeechRecorder {
    private let recognizer   = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request      : SFSpeechAudioBufferRecognitionRequest?
    private var task         : SFSpeechRecognitionTask?
    private let audioEngine  = AVAudioEngine()
    private var lastResult   = ""

    func start(onPartialResult: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted else { return }
                DispatchQueue.main.async { self.beginRecording(onPartialResult: onPartialResult) }
            }
        }
    }

    private func beginRecording(onPartialResult: @escaping (String) -> Void) {
        lastResult = ""
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request, recognizer?.isAvailable == true else { return }
        request.shouldReportPartialResults = true

        let node   = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
            request.append(buf)
        }

        try? audioEngine.start()

        task = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            if let text = result?.bestTranscription.formattedString {
                self?.lastResult = text
                DispatchQueue.main.async { onPartialResult(text) }
            }
        }
    }

    func stop(completion: @escaping (String) -> Void) {
        let finalText = lastResult
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request    = nil
        task       = nil
        lastResult = ""
        completion(finalText)
    }
}
