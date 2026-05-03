import SwiftUI
import AVFoundation
import ImageIO

struct EditorView: View {
    let project: Project
    var onDismiss: () -> Void

    @State private var viewModel = EditorViewModel()
    @State private var pinchBaseScale: CGFloat?
    @State private var rotateBaseAngle: Double?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                editorTopBar
                    .zIndex(10)
                previewSection(geo: geo)
                playbackControls
                TimelineView(viewModel: viewModel)
                    .frame(maxHeight: .infinity)
                toolbarSection
                AdBannerContainer()
                    .padding(.bottom, geo.safeAreaInsets.bottom)
            }
            .background(Color.black)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $viewModel.showMediaPicker) {
            MediaPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            ExportView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showTextEditor) {
            TextEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showCropTool) {
            CropView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAudioBrowser) {
            AudioBrowserView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.attachProject(project)
        }
        .onDisappear {
            viewModel.saveProject()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.saveProject()
        }
    }

    private var editorTopBar: some View {
        HStack(spacing: 8) {
            Button(action: onDismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Projects")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.8))
            }

            Spacer(minLength: 4)

            Text(project.name)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.subheadline)
                        .foregroundColor(viewModel.canUndo ? .white : .gray.opacity(0.3))
                }
                .disabled(!viewModel.canUndo)

                Button(action: { viewModel.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.subheadline)
                        .foregroundColor(viewModel.canRedo ? .white : .gray.opacity(0.3))
                }
                .disabled(!viewModel.canRedo)
            }

            Spacer(minLength: 4)

            Button(action: { viewModel.showExportSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export")
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                 Color(red: 0.99, green: 0.32, blue: 0.56)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.06))
    }

    private func previewSection(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color(white: 0.12)

                if viewModel.hasMedia {
                    if let player = viewModel.player {
                        ZStack {
                            Color.black
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedVideoTrackIndex = nil
                                    viewModel.selectedClipID = nil
                                    viewModel.selectedStickerID = nil
                                }

                            VideoPlayerView(player: player)
                                .scaleEffect(viewModel.previewScale)
                                .offset(viewModel.previewOffset)
                                .allowsHitTesting(false)

                            videoTrackOverlayLayer

                            textOverlayLayer(containerHeight: geo.size.height * 0.40)

                            stickerOverlayLayer

                            if viewModel.showGrid {
                                gridOverlay
                            }
                        }
                        .aspectRatio(
                            viewModel.videoAspectRatio,
                            contentMode: .fit
                        )
                        .clipped()
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    if let videoIdx = viewModel.selectedVideoTrackIndex {
                                        if pinchBaseScale == nil {
                                            pinchBaseScale = viewModel.videoTracks.first(where: { $0.index == videoIdx })?.track.transform?.scale ?? 1.0
                                        }
                                        viewModel.updateTrackScale(trackIndex: videoIdx, scale: (pinchBaseScale ?? 1.0) * value.magnification)
                                    } else if let clipID = viewModel.selectedClipID {
                                        if let item = viewModel.activeTextOverlays.first(where: { $0.clip.id == clipID }),
                                           let textData = item.clip.textOverlay {
                                            if pinchBaseScale == nil {
                                                pinchBaseScale = textData.scale
                                            }
                                            viewModel.updateTextScale(trackIndex: item.trackIndex, clipIndex: item.clipIndex, scale: (pinchBaseScale ?? 1.0) * value.magnification)
                                        }
                                    } else if let stickerID = viewModel.selectedStickerID {
                                        if let sticker = viewModel.stickers.first(where: { $0.id == stickerID }) {
                                            if pinchBaseScale == nil {
                                                pinchBaseScale = sticker.scale
                                            }
                                            viewModel.updateStickerScale(id: stickerID, scale: (pinchBaseScale ?? 1.0) * value.magnification)
                                        }
                                    } else {
                                        viewModel.previewScale = max(1.0, min(3.0, value.magnification))
                                    }
                                }
                                .onEnded { value in
                                    pinchBaseScale = nil
                                    if viewModel.selectedVideoTrackIndex == nil && viewModel.selectedClipID == nil && viewModel.selectedStickerID == nil {
                                        if viewModel.previewScale < 1.05 {
                                            withAnimation(.spring(response: 0.3)) {
                                                viewModel.previewScale = 1.0
                                                viewModel.previewOffset = .zero
                                            }
                                        }
                                    } else {
                                        viewModel.saveProject()
                                    }
                                }
                        )
                        .simultaneousGesture(
                            viewModel.selectedVideoTrackIndex != nil || viewModel.selectedClipID != nil || viewModel.selectedStickerID != nil ?
                            RotateGesture()
                                .onChanged { value in
                                    if let videoIdx = viewModel.selectedVideoTrackIndex {
                                        if rotateBaseAngle == nil {
                                            rotateBaseAngle = viewModel.videoTracks.first(where: { $0.index == videoIdx })?.track.transform?.rotation ?? 0
                                        }
                                        viewModel.updateTrackRotation(trackIndex: videoIdx, rotation: (rotateBaseAngle ?? 0) + value.rotation.degrees)
                                    } else if let clipID = viewModel.selectedClipID {
                                        if let item = viewModel.activeTextOverlays.first(where: { $0.clip.id == clipID }),
                                           let textData = item.clip.textOverlay {
                                            if rotateBaseAngle == nil {
                                                rotateBaseAngle = textData.rotation
                                            }
                                            viewModel.updateTextRotation(trackIndex: item.trackIndex, clipIndex: item.clipIndex, rotation: (rotateBaseAngle ?? 0) + value.rotation.degrees)
                                        }
                                    } else if let stickerID = viewModel.selectedStickerID {
                                        if let sticker = viewModel.stickers.first(where: { $0.id == stickerID }) {
                                            if rotateBaseAngle == nil {
                                                rotateBaseAngle = sticker.rotation
                                            }
                                            viewModel.updateStickerRotation(id: stickerID, rotation: (rotateBaseAngle ?? 0) + value.rotation.degrees)
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    rotateBaseAngle = nil
                                    viewModel.saveProject()
                                }
                            : nil
                        )
                        .simultaneousGesture(
                            viewModel.selectedVideoTrackIndex == nil && viewModel.selectedClipID == nil && viewModel.selectedStickerID == nil && viewModel.previewScale > 1.0 ?
                            DragGesture()
                                .onChanged { value in
                                    viewModel.previewOffset = value.translation
                                }
                                .onEnded { _ in }
                            : nil
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.previewScale = 1.0
                                viewModel.previewOffset = .zero
                            }
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Import media to start editing")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.5))
                        Button(action: { viewModel.showMediaPicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Media")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.42, green: 0.36, blue: 0.91))
                            .cornerRadius(24)
                        }
                    }
                }
            }
            .frame(height: geo.size.height * 0.40)
            .clipped()
        }
        .contentShape(Rectangle())
        .zIndex(1)
    }

    private var timeIndicatorBar: some View {
        HStack {
            Text(TimeFormatter.formatPrecise(seconds: viewModel.currentTime))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)

            Text("/")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.5))

            Text(TimeFormatter.formatPrecise(seconds: viewModel.totalDuration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)

            Spacer()

            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.canUndo ? .white.opacity(0.8) : .gray.opacity(0.3))
            }
            .disabled(!viewModel.canUndo)

            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.canRedo ? .white.opacity(0.8) : .gray.opacity(0.3))
            }
            .disabled(!viewModel.canRedo)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(white: 0.06))
    }

    @ViewBuilder
    private func textOverlayLayer(containerHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let overlays = viewModel.activeTextOverlays.filter { $0.clip.textOverlay != nil }
            ForEach(overlays, id: \.clip.id) { item in
                let clip = item.clip
                let textData = clip.textOverlay!

                let posX = textData.position.x * geo.size.width
                let posY = textData.position.y * geo.size.height

                let clipProgress = min(1.0, max(0, (viewModel.currentTime - clip.startTime) / max(0.1, clip.effectiveDuration)))
                let animFraction = min(1.0, clipProgress * 4.0)
                let isSelected = clip.id == viewModel.selectedClipID

                TextOverlayWithRotation(
                    textData: textData,
                    animFraction: animFraction,
                    isSelected: isSelected,
                    onTap: {
                        viewModel.selectedClipID = clip.id
                        viewModel.selectedVideoTrackIndex = nil
                        viewModel.selectedStickerID = nil
                    },
                    onDragEnd: isSelected ? { translation in
                        let newX = textData.position.x + translation.width / geo.size.width
                        let newY = textData.position.y + translation.height / geo.size.height
                        let clampedX = max(0.05, min(0.95, newX))
                        let clampedY = max(0.05, min(0.95, newY))
                        viewModel.updateTextPosition(
                            trackIndex: item.trackIndex,
                            clipIndex: item.clipIndex,
                            position: CGPoint(x: clampedX, y: clampedY)
                        )
                    } : nil,
                    onRotationChanged: isSelected ? { rot in
                        viewModel.updateTextRotation(
                            trackIndex: item.trackIndex,
                            clipIndex: item.clipIndex,
                            rotation: rot
                        )
                    } : nil
                )
                .position(x: posX, y: posY)
            }
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 0) {
            Text(TimeFormatter.format(seconds: viewModel.currentTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 60, alignment: .leading)
                .fixedSize()

            Spacer(minLength: 4)

            HStack(spacing: 14) {
                Button(action: { viewModel.seek(to: 0) }) {
                    Image(systemName: "backward.end.fill")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }

                Button(action: { viewModel.stepBackward() }) {
                    Image(systemName: "backward.frame.fill")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }

                Button(action: { viewModel.togglePlayback() }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                             Color(red: 0.6, green: 0.3, blue: 0.9)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.5), radius: 6)

                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .offset(x: viewModel.isPlaying ? 0 : 2)
                    }
                    .scaleEffect(viewModel.isPlaying ? 1.05 : 1.0)
                    .animation(.spring(response: 0.2), value: viewModel.isPlaying)
                }

                Button(action: { viewModel.stepForward() }) {
                    Image(systemName: "forward.frame.fill")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }

                Button(action: { viewModel.seek(to: viewModel.totalDuration) }) {
                    Image(systemName: "forward.end.fill")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }
            }

            Spacer(minLength: 4)

            Text(TimeFormatter.format(seconds: viewModel.totalDuration))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 60, alignment: .trailing)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.04))
    }

    private var toolbarSection: some View {
        ToolbarView(viewModel: viewModel, onAddMedia: { viewModel.showMediaPicker = true })
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerView = uiView as? PlayerUIView {
            playerView.playerLayer.player = player
        }
    }
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

extension EditorView {
    var gridOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            .allowsHitTesting(false)
        }
    }

    var stickerOverlayLayer: some View {
        GeometryReader { geo in
            let visibleStickers = viewModel.stickers.filter { sticker in
                viewModel.currentTime >= sticker.startTime &&
                viewModel.currentTime < sticker.startTime + sticker.duration
            }
            ForEach(visibleStickers) { sticker in
                let isSelected = viewModel.selectedStickerID == sticker.id
                StickerOverlayWithRotation(
                    sticker: sticker,
                    geoSize: geo.size,
                    isSelected: isSelected,
                    onTap: {
                        viewModel.selectedStickerID = sticker.id
                        viewModel.selectedClipID = sticker.clipID
                        viewModel.selectedVideoTrackIndex = nil
                    },
                    onDragEnd: isSelected ? { translation in
                        let newX = sticker.position.x + translation.width / geo.size.width
                        let newY = sticker.position.y + translation.height / geo.size.height
                        let clampedX = max(0.05, min(0.95, newX))
                        let clampedY = max(0.05, min(0.95, newY))
                        viewModel.updateStickerPosition(
                            id: sticker.id,
                            position: CGPoint(x: clampedX, y: clampedY)
                        )
                        viewModel.saveProject()
                    } : nil,


                    onRotationChanged: isSelected ? { rot in
                        viewModel.updateStickerRotation(
                            id: sticker.id,
                            rotation: rot
                        )
                    } : nil,
                    onRotationEnd: {
                        viewModel.saveProject()
                    },
                    onDoubleTap: {
                        viewModel.removeSticker(id: sticker.id)
                    }
                )
                .transaction { t in t.animation = nil }
            }
        }
    }

    private var gridOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                for i in 1..<3 {
                    let x = w * CGFloat(i) / 3.0
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))

                    let y = h * CGFloat(i) / 3.0
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var videoTrackOverlayLayer: some View {
        GeometryReader { geo in
            ForEach(viewModel.videoTracks, id: \.track.id) { item in
                VideoLayerOverlayView(
                    item: item,
                    geoSize: geo.size,
                    viewModel: viewModel
                )
            }
        }
    }
}

struct AnimatedTextView: View {
    let textData: TextOverlayData
    let animFraction: CGFloat
    let isSelected: Bool

    private let accentColor = Color(red: 0.42, green: 0.36, blue: 0.91)

    var body: some View {
        let textColor = Color(
            red: textData.textColor.red,
            green: textData.textColor.green,
            blue: textData.textColor.blue,
            opacity: textData.textColor.alpha
        )
        let bgColor: Color = {
            if let bg = textData.backgroundColor {
                return Color(red: bg.red, green: bg.green, blue: bg.blue, opacity: bg.alpha)
            }
            return .clear
        }()

        Text(textData.text)
            .font(.custom(textData.fontName, size: textData.fontSize * 0.5 * textData.scale))
            .foregroundColor(textColor)
            .padding(textData.backgroundColor != nil ? 8 : 0)
            .background(bgColor)
            .cornerRadius(6)
            .shadow(
                color: textData.animationStyle == .glow
                    ? textColor.opacity(Double(1.0 - animFraction) * 0.8)
                    : .black.opacity(0.5),
                radius: textData.animationStyle == .glow ? 10 * (1.0 - animFraction) + 3 : 3,
                x: textData.animationStyle == .glow ? 0 : 1,
                y: textData.animationStyle == .glow ? 0 : 1
            )
            .opacity(textData.animationStyle == .fadeIn ? Double(animFraction) : 1.0)
            .offset(y: textData.animationStyle == .slideUp ? 30 * (1.0 - animFraction) : 0)
            .scaleEffect(textData.animationStyle == .bounce ? bounceScale(animFraction) : 1.0)
            .offset(y: textData.animationStyle == .wave ? sin(animFraction * .pi * 2) * 6 : 0)
            .transaction { t in t.animation = nil }
    }

    private func bounceScale(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 0.5 + t * 1.4
        } else if t < 0.75 {
            return 1.2 - (t - 0.5) * 0.8
        } else {
            return 1.0
        }
    }
}

struct TextOverlayWithRotation: View {
    let textData: TextOverlayData
    let animFraction: CGFloat
    let isSelected: Bool
    var onTap: () -> Void
    var onDragEnd: ((CGSize) -> Void)?
    var onRotationChanged: ((Double) -> Void)?

    @State private var rotationHandleDrag: Angle = .zero
    @State private var isDraggingRotation: Bool = false
    @State private var dragOffset: CGSize = .zero

    private let accentColor = Color(red: 0.42, green: 0.36, blue: 0.91)
    private let rotationHandleOffset: CGFloat = 30

    var body: some View {
        let currentRotation = textData.rotation + rotationHandleDrag.degrees

        ZStack {
            AnimatedTextView(
                textData: textData,
                animFraction: animFraction,
                isSelected: isSelected
            )
            .overlay(
                isSelected ?
                RoundedRectangle(cornerRadius: 6)
                    .stroke(accentColor, lineWidth: 2)
                    .padding(-4)
                : nil
            )

            if isSelected {
                VStack(spacing: 0) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingRotation = true
                                    let delta = atan2(value.translation.width, -value.translation.height)
                                    rotationHandleDrag = .radians(Double(delta))
                                }
                                .onEnded { _ in
                                    let newRotation = textData.rotation + rotationHandleDrag.degrees
                                    onRotationChanged?(newRotation)
                                    rotationHandleDrag = .zero
                                    isDraggingRotation = false
                                }
                        )

                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 1.5, height: rotationHandleOffset - 10)
                }
                .offset(y: -rotationHandleOffset - 10)
            }
        }
        .rotationEffect(.degrees(currentRotation))
        .offset(dragOffset)
        .onTapGesture { onTap() }
        .gesture(
            onDragEnd != nil && !isDraggingRotation ?
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    onDragEnd?(value.translation)
                    dragOffset = .zero
                }
            : nil
        )
    }
}

struct StickerOverlayWithRotation: View {
    let sticker: StickerData
    let geoSize: CGSize
    let isSelected: Bool
    var onTap: () -> Void
    var onDragEnd: ((CGSize) -> Void)?
    var onRotationChanged: ((Double) -> Void)?
    var onRotationEnd: (() -> Void)?
    var onDoubleTap: () -> Void

    @State private var rotationHandleDrag: Angle = .zero
    @State private var isDraggingRotation: Bool = false
    @State private var dragOffset: CGSize = .zero

    private let accentColor = Color(red: 0.42, green: 0.36, blue: 0.91)
    private let rotationHandleOffset: CGFloat = 30

    var body: some View {
        let currentRotation = sticker.rotation + rotationHandleDrag.degrees

        ZStack {
            Group {
                if let gifURL = sticker.gifURL, let url = URL(string: gifURL) {
                    AnimatedGifView(url: url)
                        .frame(width: 80 * sticker.scale, height: 80 * sticker.scale)
                        .cornerRadius(8)
                        .allowsHitTesting(false)
                } else {
                    Text(sticker.emoji)
                        .font(.system(size: 48 * sticker.scale))
                }
            }
            .contentShape(Rectangle())
            .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
            .overlay(
                isSelected ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(accentColor, lineWidth: 2)
                    .padding(-4)
                : nil
            )

            if isSelected {
                VStack(spacing: 0) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingRotation = true
                                    let delta = atan2(value.translation.width, -value.translation.height)
                                    rotationHandleDrag = .radians(Double(delta))
                                }
                                .onEnded { _ in
                                    let newRotation = sticker.rotation + rotationHandleDrag.degrees
                                    onRotationChanged?(newRotation)
                                    rotationHandleDrag = .zero
                                    isDraggingRotation = false
                                    onRotationEnd?()
                                }
                        )

                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 1.5, height: rotationHandleOffset - 10)
                }
                .offset(y: -rotationHandleOffset - 20)
            }
        }
        .rotationEffect(.degrees(currentRotation))
        .position(
            x: sticker.position.x * geoSize.width,
            y: sticker.position.y * geoSize.height
        )
        .offset(dragOffset)
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onTap() }
        .gesture(
            onDragEnd != nil && !isDraggingRotation ?
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    onDragEnd?(value.translation)
                    dragOffset = .zero
                }
            : nil
        )
    }
}

struct VideoLayerOverlayView: View {
    let item: (index: Int, track: TimelineTrack)
    let geoSize: CGSize
    @Bindable var viewModel: EditorViewModel

    @State private var dragOffset: CGSize = .zero
    @State private var rotationHandleDrag: Angle = .zero
    @State private var isDraggingRotation: Bool = false

    private let accentColor = Color(red: 0.42, green: 0.36, blue: 0.91)
    private let handleSize: CGFloat = 12
    private let rotationHandleOffset: CGFloat = 30

    var body: some View {
        let transform = item.track.transform ?? .fullFrame
        let isSelected = viewModel.selectedVideoTrackIndex == item.index
        let isFirstTrack = item.index == viewModel.videoTracks.first?.index

        let currentScale = transform.scale
        let boxW = geoSize.width * currentScale
        let boxH = geoSize.height * currentScale

        let posX = transform.position.x * geoSize.width + (isSelected ? dragOffset.width : 0)
        let posY = transform.position.y * geoSize.height + (isSelected ? dragOffset.height : 0)

        let currentRotation = transform.rotation + (isSelected ? rotationHandleDrag.degrees : 0)

        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .frame(width: boxW, height: boxH)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? accentColor : Color.white.opacity(isFirstTrack ? 0 : 0.4),
                            lineWidth: isSelected ? 2.5 : 1.5
                        )
                )
                .overlay {
                    if isSelected {
                        ForEach(0..<4, id: \.self) { corner in
                            Circle()
                                .fill(accentColor)
                                .frame(width: handleSize, height: handleSize)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                                .offset(
                                    x: corner % 2 == 0 ? -boxW / 2 : boxW / 2,
                                    y: corner < 2 ? -boxH / 2 : boxH / 2
                                )
                        }
                    }
                }

            if isSelected {
                VStack(spacing: 0) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingRotation = true
                                    let center = CGPoint(x: posX, y: posY)
                                    let startAngle = atan2(
                                        value.startLocation.y - center.y + posY - rotationHandleOffset - boxH / 2,
                                        value.startLocation.x - center.x + posX
                                    )
                                    let currentAngle = atan2(
                                        value.location.y - center.y + posY - rotationHandleOffset - boxH / 2,
                                        value.location.x - center.x + posX
                                    )
                                    let delta = (currentAngle - startAngle) * 180 / .pi
                                    rotationHandleDrag = .degrees(Double(delta))
                                }
                                .onEnded { _ in
                                    let newRotation = transform.rotation + rotationHandleDrag.degrees
                                    viewModel.updateTrackRotation(
                                        trackIndex: item.index,
                                        rotation: newRotation
                                    )
                                    rotationHandleDrag = .zero
                                    isDraggingRotation = false
                                    viewModel.saveProject()
                                }
                        )

                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 1.5, height: rotationHandleOffset - 10)

                    Spacer()
                }
                .frame(width: 20, height: boxH / 2 + rotationHandleOffset)
                .offset(y: -(boxH / 2 + rotationHandleOffset) / 2)
            }

            if !isSelected && !isFirstTrack {
                Text("Layer \(item.index)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(4)
            }
        }
        .rotationEffect(.degrees(currentRotation))
        .position(x: posX, y: posY)
        .contentShape(Rectangle())
        .allowsHitTesting(!isFirstTrack || isSelected)
        .onTapGesture {
            viewModel.selectedVideoTrackIndex = item.index
            viewModel.selectedClipID = nil
            viewModel.selectedStickerID = nil
        }
        .simultaneousGesture(
            isSelected ?
            DragGesture()
                .onChanged { value in
                    if !isDraggingRotation {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if !isDraggingRotation {
                        let newX = transform.position.x + value.translation.width / geoSize.width
                        let newY = transform.position.y + value.translation.height / geoSize.height
                        let clampedX = max(0.0, min(1.0, newX))
                        let clampedY = max(0.0, min(1.0, newY))
                        viewModel.updateTrackPosition(
                            trackIndex: item.index,
                            position: CGPoint(x: clampedX, y: clampedY)
                        )
                        viewModel.saveProject()
                    }
                    dragOffset = .zero
                }
            : nil
        )
    }
}

struct AnimatedGifView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = false
        loadGif(into: imageView)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}

    private func loadGif(into imageView: UIImageView) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
            let count = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var totalDuration: Double = 0

            for i in 0..<count {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    images.append(UIImage(cgImage: cgImage))
                    if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                            ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double
                            ?? 0.1
                        totalDuration += delay
                    } else {
                        totalDuration += 0.1
                    }
                }
            }

            DispatchQueue.main.async {
                imageView.animationImages = images
                imageView.animationDuration = totalDuration
                imageView.animationRepeatCount = 0
                imageView.startAnimating()
            }
        }.resume()
    }
}
