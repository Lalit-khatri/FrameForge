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

    private var audioEffects: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Audio Effects")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("Coming Soon")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                audioEffectCard("Fade In", icon: "arrow.up.right", description: "Gradually increase volume")
                audioEffectCard("Fade Out", icon: "arrow.down.right", description: "Gradually decrease volume")
                audioEffectCard("Noise Reduce", icon: "waveform.badge.minus", description: "Remove background noise")
                audioEffectCard("Voice Enhance", icon: "person.wave.2", description: "Enhance vocal clarity")
                audioEffectCard("Echo", icon: "repeat", description: "Add echo effect")
                audioEffectCard("Reverb", icon: "waveform.circle", description: "Add reverb effect")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .opacity(0.6)
    }

    private func audioEffectCard(_ name: String, icon: String, description: String) -> some View {
        let isActive = viewModel.activeAudioEffects.contains(name)
        return Button(action: {
            viewModel.toggleAudioEffect(name)
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(isActive ? .white : Color(red: 0.42, green: 0.36, blue: 0.91))

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .offset(x: 14, y: -10)
                    }
                }
                Text(name)
                    .font(.caption.bold())
                    .foregroundColor(isActive ? .white : .white.opacity(0.8))
                Text(description)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive
                ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.25)
                : Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(12)
        }
    }
}
