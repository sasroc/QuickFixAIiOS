import SwiftUI
import PhotosUI
import Speech
import AVFoundation

struct InputFormView: View {
    @Environment(RepairViewModel.self) private var repairVM

    @FocusState private var isFocused: Bool
    @State private var description   = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isRecording = false
    private let recorder = SpeechRecorder()
    @State private var showCamera    = false

    private var canSubmit: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty && !repairVM.isAnalyzing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("Describe Your Repair")
                        .font(.title2).fontWeight(.bold)
                    Text("Tell us what's broken and we'll create a step-by-step guide.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Text input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description").font(.headline)

                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("e.g. My kitchen faucet is dripping slowly, it's been leaking for 2 days...")
                                .foregroundStyle(.tertiary)
                                .padding(12)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 120)
                            .padding(8)
                            .focused($isFocused)
                    }
                    .background(Color.inputBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(UIColor.quaternaryLabel), lineWidth: 1))

                    // Voice input button
                    Button {
                        toggleVoice()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                                .foregroundStyle(isRecording ? .red : .brand)
                            Text(isRecording ? "Stop Recording" : "Use Voice Input")
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(isRecording ? Color.red.opacity(0.1) : Color.brand.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)

                // Image upload
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a Photo (Optional)").font(.headline)

                    if let image = selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
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
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Choose Photo", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.inputBackground)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(UIColor.quaternaryLabel), lineWidth: 1))
                            }

                            Button {
                                showCamera = true
                            } label: {
                                Label("Camera", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.inputBackground)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(UIColor.quaternaryLabel), lineWidth: 1))
                            }
                        }
                        .foregroundStyle(Color.brand)
                    }
                }
                .padding(.horizontal)

                // Submit
                Button {
                    Task { await repairVM.analyze(description: description, image: selectedImage) }
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Get Repair Guide")
                    }
                    .primaryButtonStyle(disabled: !canSubmit)
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
        .onChange(of: repairVM.currentGuide) { _, guide in
            if guide != nil {
                description  = ""
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
