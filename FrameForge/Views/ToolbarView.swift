import SwiftUI

struct ToolbarView: View {
    @Bindable var viewModel: EditorViewModel
    var onAddMedia: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.1))

            if viewModel.selectedClipID != nil {
                clipToolbar
            } else {
                mainToolbar
            }
        }
        .background(Color(white: 0.06))
        .sheet(isPresented: $viewModel.showFiltersPanel) {
            FiltersView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEffectsPanel) {
            EffectsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showTransitionsPanel) {
            TransitionsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSpeedControl) {
            SpeedControlView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAudioMixer) {
            AudioMixerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showStickerPicker) {
            StickersView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showCaptionsView) {
            CaptionsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBackgroundRemoval) {
            BackgroundRemovalView(viewModel: viewModel)
        }
    }

    private var mainToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                toolButton("Import", icon: "plus.circle.fill", color: Color(red: 0.42, green: 0.36, blue: 0.91)) {
                    onAddMedia()
                }
                toolButton("Text", icon: "textformat", color: .white) {
                    viewModel.showTextEditor = true
                }
                toolButton("Captions", icon: "captions.bubble", color: .white) {
                    viewModel.showCaptionsView = true
                }
                toolButton("Music", icon: "music.note", color: .white) {
                    viewModel.showAudioBrowser = true
                }
                toolButton("Filters", icon: "camera.filters", color: .white) {
                    viewModel.showFiltersPanel = true
                }
                toolButton("Effects", icon: "sparkles", color: .white) {
                    viewModel.showEffectsPanel = true
                }
                toolButton("BG Remove", icon: "person.crop.rectangle", color: .white) {
                    viewModel.showBackgroundRemoval = true
                }
                toolButton("Sticker", icon: "face.smiling", color: .white) {
                    viewModel.showStickerPicker = true
                }
                toolButton("Layer", icon: "square.3.layers.3d", color: .white) {
                    viewModel.addVideoTrack()
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 62)
        .padding(.bottom, 2)
    }

    private var clipToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                toolButton("Split", icon: "scissors", color: .white) {
                    viewModel.splitClipAtPlayhead()
                }
                toolButton("Crop", icon: "crop", color: .white) {
                    viewModel.showCropTool = true
                }
                toolButton("Speed", icon: "gauge.with.dots.needle.33percent", color: .white) {
                    viewModel.showSpeedControl = true
                }
                toolButton("Volume", icon: "speaker.wave.2", color: .white) {
                    viewModel.showAudioMixer = true
                }
                toolButton("Filters", icon: "camera.filters", color: .white) {
                    viewModel.showFiltersPanel = true
                }
                toolButton("Effects", icon: "sparkles", color: .white) {
                    viewModel.showEffectsPanel = true
                }
                toolButton("Transition", icon: "arrow.right.arrow.left", color: .white) {
                    viewModel.showTransitionsPanel = true
                }
                toolButton("Duplicate", icon: "plus.square.on.square", color: .white) {
                    viewModel.duplicateSelectedClip()
                }
                toolButton("Delete", icon: "trash", color: .red) {
                    viewModel.deleteSelectedClip()
                }
                toolButton("Deselect", icon: "xmark.circle", color: .gray) {
                    viewModel.selectedClipID = nil
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 70)
    }

    private func toolButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
}
