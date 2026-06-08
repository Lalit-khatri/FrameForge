import SwiftUI
import UniformTypeIdentifiers

struct AudioMixerView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        masterVolumeSection
                        trackVolumes
                        addMusicSection
                        audioEffects
                    }
                    .padding()
                }
            }
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio, .mp3, .wav, .aiff, UTType(filenameExtension: "m4a") ?? .audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                Task {
                    let tempDir = FileManager.default.temporaryDirectory
                    let dest = tempDir.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: url, to: dest)
                    if accessing { url.stopAccessingSecurityScopedResource() }
                    await viewModel.addAudioFromURL(dest)
                }
            case .failure(let error):
                print("Audio import error: \(error)")
            }
        }
    }

    private var masterVolumeSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                Text("Master Volume")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(viewModel.masterVolume * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: Binding(
                get: { viewModel.masterVolume },
                set: { viewModel.setMasterVolume($0) }
            ), in: 0...2.0)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var trackVolumes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Track Volumes")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            ForEach(viewModel.tracks.indices, id: \.self) { i in
                let track = viewModel.tracks[i]
                HStack(spacing: 12) {
                    Image(systemName: trackIcon(for: track.type))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 20)

                    Text(track.type.rawValue.capitalized)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(width: 50, alignment: .leading)

                    Slider(value: Binding(
                        get: { track.volume },
                        set: { viewModel.setTrackVolume($0, trackID: track.id) }
                    ), in: 0...2.0)
                    .tint(track.type == .video
                          ? Color(red: 0.42, green: 0.36, blue: 0.91)
                          : Color(red: 0.13, green: 0.59, blue: 0.95))

                    Button(action: {
                        viewModel.toggleTrackMute(trackID: track.id)
                    }) {
                        Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .foregroundColor(track.isMuted ? .red : .gray)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func trackIcon(for type: TrackType) -> String {
        switch type {
        case .video: return "video"
        case .audio: return "waveform"
        case .text: return "textformat"
        case .overlay: return "square.on.square"
        }
    }

    private var addMusicSection: some View {
        Button(action: { showFilePicker = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                     Color(red: 0.99, green: 0.32, blue: 0.56)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    Image(systemName: "music.note")
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading) {
                    Text("Add Music")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Import audio files (.mp3, .m4a, .wav)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .font(.title3)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }

    // MARK: - Audio Effects

    private var audioEffects: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Effects")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            // --- Fade In / Fade Out (clip-level, real parameter controls) ---
            VStack(spacing: 10) {
                fadeControl(
                    label: "Fade In",
                    icon: "arrow.up.right",
                    duration: Binding(
                        get: { viewModel.globalFadeIn },
                        set: { viewModel.setGlobalFade(fadeIn: $0, fadeOut: viewModel.globalFadeOut) }
                    )
                )
                Divider().background(Color.white.opacity(0.08))
                fadeControl(
                    label: "Fade Out",
                    icon: "arrow.down.right",
                    duration: Binding(
                        get: { viewModel.globalFadeOut },
                        set: { viewModel.setGlobalFade(fadeIn: viewModel.globalFadeIn, fadeOut: $0) }
                    )
                )
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)

            // --- Toggle effects (applied at export) ---
            Text("Export Effects")
                .font(.caption.bold())
                .foregroundColor(.gray)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                audioToggleCard("Noise Reduce", icon: "waveform.badge.minus",
                                description: "Remove background noise",
                                effect: "noiseReduce")
                audioToggleCard("Voice Enhance", icon: "person.wave.2",
                                description: "Boost vocal clarity",
                                effect: "voiceEnhance")
                audioToggleCard("Echo", icon: "repeat",
                                description: "Add echo effect",
                                effect: "echo")
                audioToggleCard("Reverb", icon: "waveform.circle",
                                description: "Add reverb effect",
                                effect: "reverb")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func fadeControl(label: String, icon: String, duration: Binding<Double>) -> some View {
        let isActive = duration.wrappedValue > 0

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isActive
                                     ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                     : .gray)
                    .frame(width: 24)

                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.white)

                Spacer()

                if isActive {
                    Text(String(format: "%.1fs", duration.wrappedValue))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }

                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { on in
                        withAnimation { duration.wrappedValue = on ? 1.0 : 0.0 }
                        HapticManager.shared.selection()
                    }
                ))
                .labelsHidden()
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .scaleEffect(0.85)
            }

            if isActive {
                Slider(value: duration, in: 0.2...5.0, step: 0.1)
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func audioToggleCard(_ name: String, icon: String, description: String, effect: String) -> some View {
        let isActive = viewModel.activeAudioEffects.contains(effect)
        return Button(action: {
            viewModel.toggleAudioEffect(effect)
            HapticManager.shared.selection()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isActive ? Color(red: 0.42, green: 0.36, blue: 0.91) : .gray)
                Text(name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isActive
                ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.2)
                : Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.clear,
                            lineWidth: 1.5)
            )
            .cornerRadius(12)
        }
    }
}
