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
        .sheet(isPresented: $viewModel.showKeyframeEditor) {
            KeyframeEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showMotionTracking) {
            MotionTrackingView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showLUTImport) {
            LUTImportView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.show3DText) {
            Text3DView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showCloudBackup) {
            CloudBackupView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showShareView) {
            ShareView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPlugins) {
            PluginStoreView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showVoiceover) {
            VoiceoverView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showChromaKey) {
            ChromaKeyView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showCurveSpeed) {
            CurveSpeedView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPhotoImport) {
            PhotoImportView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPiP) {
            PictureInPictureView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showStabilization) {
            VideoStabilizationView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showNoiseReduction) {
            NoiseReductionView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBeatSync) {
            BeatSyncView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSplitScreen) {
            SplitScreenView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showMasking) {
            MaskingView(viewModel: viewModel)
        }
    }

    private var mainToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                toolButton("Import", icon: "plus.circle.fill", color: Color(red: 0.42, green: 0.36, blue: 0.91)) {
                    onAddMedia()
                }
                toolButton("Photos", icon: "photo.badge.plus", color: .white) {
                    viewModel.showPhotoImport = true
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
                toolButton("Beat Sync", icon: "metronome", color: .white) {
                    viewModel.showBeatSync = true
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
                toolButton("Keyframe", icon: "diamond", color: .white) {
                    viewModel.showKeyframeEditor = true
                }
                toolButton("Track", icon: "scope", color: .white) {
                    viewModel.showMotionTracking = true
                }
                toolButton("3D Text", icon: "cube", color: .white) {
                    viewModel.show3DText = true
                }
                toolButton("LUT", icon: "paintpalette", color: .white) {
                    viewModel.showLUTImport = true
                }
                toolButton("Split", icon: "rectangle.split.2x2", color: .white) {
                    viewModel.showSplitScreen = true
                }
                toolButton("Cloud", icon: "icloud", color: .white) {
                    viewModel.showCloudBackup = true
                }
                toolButton("Share", icon: "square.and.arrow.up", color: .white) {
                    viewModel.showShareView = true
                }
                toolButton("Plugins", icon: "puzzlepiece", color: .white) {
                    viewModel.showPlugins = true
                }
                toolButton("Sticker", icon: "face.smiling", color: .white) {
                    viewModel.showStickerPicker = true
                }
                toolButton("Voiceover", icon: "mic.fill", color: .white) {
                    viewModel.showVoiceover = true
                }
                toolButton("Chroma", icon: "person.and.background.dotted", color: .white) {
                    viewModel.showChromaKey = true
                }
                toolButton("Curve", icon: "point.topleft.down.to.point.bottomright.curvepath", color: .white) {
                    viewModel.showCurveSpeed = true
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
                toolButton("Mask", icon: "rectangle.on.rectangle", color: .white) {
                    viewModel.showMasking = true
                }
                toolButton("Transition", icon: "arrow.right.arrow.left", color: .white) {
                    viewModel.showTransitionsPanel = true
                }
                toolButton("PiP", icon: "pip", color: .white) {
                    viewModel.showPiP = true
                }
                toolButton("Reverse", icon: "arrow.uturn.backward", color: .white) {
                    if let id = viewModel.selectedClipID { viewModel.reverseClip(clipID: id) }
                }
                toolButton("Stabilize", icon: "hand.raised", color: .white) {
                    viewModel.showStabilization = true
                }
                toolButton("Denoise", icon: "waveform.badge.minus", color: .white) {
                    viewModel.showNoiseReduction = true
                }
                toolButton("Duplicate", icon: "plus.square.on.square", color: .white) {
                    viewModel.duplicateSelectedClip()
                }
                toolButton("Freeze", icon: "pause.rectangle", color: .white) {
                    viewModel.addFreezeFrame()
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityLabel(title)
        .accessibilityHint("Activate \(title) tool")
    }
}
