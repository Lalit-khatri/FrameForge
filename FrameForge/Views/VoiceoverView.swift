import SwiftUI
import AVFoundation

struct VoiceoverView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var recordingTime: Double = 0
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var timer: Timer?
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.2, count: 40)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 28) {
                    waveformVisualizer

                    Text(formatTime(recordingTime))
                        .font(.system(size: 48, weight: .thin, design: .monospaced))
                        .foregroundColor(.white)

                    Text(isRecording ? "Recording..." : "Tap to start recording")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    recordButton

                    if !isRecording && recordingURL != nil {
                        Button(action: addToTimeline) {
                            HStack {
                                Image(systemName: "waveform.badge.plus")
                                Text("Add to Timeline")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                             Color(red: 0.99, green: 0.32, blue: 0.56)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.top, 20)
            }
            .navigationTitle("Voiceover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        stopRecording()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onDisappear { stopRecording() }
    }

    private var waveformVisualizer: some View {
        HStack(spacing: 3) {
            ForEach(0..<40, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isRecording
                        ? Color(red: 0.99, green: 0.32, blue: 0.56)
                        : Color.gray.opacity(0.3))
                    .frame(width: 4, height: max(4, audioLevels[i] * 60))
                    .animation(.easeOut(duration: 0.1), value: audioLevels[i])
            }
        }
        .frame(height: 60)
        .padding(.horizontal)
    }

    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(isRecording ? .red : Color(red: 0.99, green: 0.32, blue: 0.56))
                    .frame(width: isRecording ? 32 : 64, height: isRecording ? 32 : 64)
                    .cornerRadius(isRecording ? 6 : 32)
                    .animation(.spring(response: 0.3), value: isRecording)
            }
        }
    }

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .default)
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceover_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        recorder.isMeteringEnabled = true
        recorder.record()
        audioRecorder = recorder
        recordingURL = url
        isRecording = true
        recordingTime = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            recordingTime += 0.05
            recorder.updateMeters()
            let level = CGFloat(max(0, 1 + recorder.averagePower(forChannel: 0) / 50))
            audioLevels.removeFirst()
            audioLevels.append(level)
        }
        HapticManager.shared.medium()
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false
    }

    private func addToTimeline() {
        guard let url = recordingURL else { return }
        viewModel.addVoiceoverClip(url: url, duration: recordingTime)
        HapticManager.shared.success()
        dismiss()
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }
}
