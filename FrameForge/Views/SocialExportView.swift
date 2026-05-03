import SwiftUI

struct SocialExportView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: SocialPreset?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(SocialPreset.allCases, id: \.self) { preset in
                            presetCard(preset)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Export For")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func presetCard(_ preset: SocialPreset) -> some View {
        let isSelected = selectedPreset == preset
        return Button(action: {
            selectedPreset = preset
            viewModel.exportSettings = preset.exportSettings
            HapticManager.shared.light()
            dismiss()
            viewModel.showExportSheet = true
        }) {
            VStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundColor(isSelected
                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                        : .white.opacity(0.7))

                Text(preset.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Text(preset.specs)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                        ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.2)
                        : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color(red: 0.42, green: 0.36, blue: 0.91) : .clear, lineWidth: 1.5)
                    )
            )
        }
    }
}

enum SocialPreset: String, CaseIterable {
    case tikTok = "TikTok"
    case instagramReels = "IG Reels"
    case instagramPost = "IG Post"
    case youTube = "YouTube"
    case youTubeShorts = "YT Shorts"
    case twitter = "X/Twitter"
    case facebook = "Facebook"
    case linkedin = "LinkedIn"

    var icon: String {
        switch self {
        case .tikTok: return "play.rectangle.fill"
        case .instagramReels: return "camera.filters"
        case .instagramPost: return "photo.fill"
        case .youTube: return "play.tv.fill"
        case .youTubeShorts: return "play.square.stack.fill"
        case .twitter: return "bubble.left.fill"
        case .facebook: return "person.2.fill"
        case .linkedin: return "briefcase.fill"
        }
    }

    var specs: String {
        switch self {
        case .tikTok: return "9:16 • 1080p\n15-60s"
        case .instagramReels: return "9:16 • 1080p\n15-90s"
        case .instagramPost: return "1:1 • 1080p\n3-60s"
        case .youTube: return "16:9 • 4K\nUp to 12hr"
        case .youTubeShorts: return "9:16 • 1080p\nUnder 60s"
        case .twitter: return "16:9 • 1080p\nUp to 2:20"
        case .facebook: return "16:9 • 1080p\nUp to 240min"
        case .linkedin: return "1:1 • 1080p\nUp to 10min"
        }
    }

    var exportSettings: ExportSettings {
        switch self {
        case .tikTok, .instagramReels, .youTubeShorts:
            return ExportSettings(resolution: .fhd1080p, frameRate: 30, codec: .h264, includeAudio: true)
        case .instagramPost:
            return ExportSettings(resolution: .fhd1080p, frameRate: 30, codec: .h264, includeAudio: true)
        case .youTube:
            return ExportSettings(resolution: .uhd4k, frameRate: 30, codec: .h265, includeAudio: true)
        case .twitter:
            return ExportSettings(resolution: .fhd1080p, frameRate: 30, codec: .h264, includeAudio: true)
        case .facebook:
            return ExportSettings(resolution: .fhd1080p, frameRate: 30, codec: .h264, includeAudio: true)
        case .linkedin:
            return ExportSettings(resolution: .fhd1080p, frameRate: 30, codec: .h264, includeAudio: true)
        }
    }
}
