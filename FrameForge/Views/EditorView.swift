import SwiftUI
import AVFoundation

struct EditorView: View {
    let project: Project
    var onDismiss: () -> Void

    @State private var viewModel = EditorViewModel()
    @State private var showMediaPicker = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                editorTopBar
                    .zIndex(10)
                previewSection(geo: geo)
                playbackControls
                TimelineView(viewModel: viewModel, onAddMedia: { showMediaPicker = true })
                    .frame(maxHeight: .infinity)
                toolbarSection
                    .padding(.bottom, geo.safeAreaInsets.bottom)
            }
            .background(Color.black)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showMediaPicker) {
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

                            VideoPlayerView(player: player)
                                .scaleEffect(viewModel.previewScale)
                                .offset(viewModel.previewOffset)

                            videoTrackOverlayLayer

                            textOverlayLayer(containerHeight: geo.size.height * 0.40)

                            stickerOverlayLayer
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
                                    viewModel.previewScale = max(1.0, min(3.0, value.magnification))
                                }
                                .onEnded { value in
                                    if viewModel.previewScale < 1.05 {
                                        withAnimation(.spring(response: 0.3)) {
                                            viewModel.previewScale = 1.0
                                            viewModel.previewOffset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            viewModel.previewScale > 1.0 ?
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
                        Button(action: { showMediaPicker = true }) {
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

            timeIndicatorBar
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

                Text(textData.text)
                    .font(.custom(
                        textData.fontName,
                        size: textData.fontSize * 0.5 * textData.scale
                    ))
                    .foregroundColor(Color(
                        red: textData.textColor.red,
                        green: textData.textColor.green,
                        blue: textData.textColor.blue,
                        opacity: textData.textColor.alpha
                    ))
                    .padding(textData.backgroundColor != nil ? 8 : 0)
                    .background(
                        textData.backgroundColor != nil ?
                        Color(
                            red: textData.backgroundColor!.red,
                            green: textData.backgroundColor!.green,
                            blue: textData.backgroundColor!.blue,
                            opacity: textData.backgroundColor!.alpha
                        ) : Color.clear
                    )
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 1, y: 1)
                    .rotationEffect(.degrees(textData.rotation))
                    .position(x: posX, y: posY)
                    .overlay(
                        clip.id == viewModel.selectedClipID ?
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.42, green: 0.36, blue: 0.91), lineWidth: 2)
                            .padding(-4)
                        : nil
                    )
                    .onTapGesture {
                        viewModel.selectedClipID = clip.id
                    }
                    .gesture(
                        clip.id == viewModel.selectedClipID ?
                        DragGesture()
                            .onChanged { value in
                                let newX = value.location.x / geo.size.width
                                let newY = value.location.y / geo.size.height
                                let clampedX = max(0.05, min(0.95, newX))
                                let clampedY = max(0.05, min(0.95, newY))
                                viewModel.updateTextPosition(
                                    trackIndex: item.trackIndex,
                                    clipIndex: item.clipIndex,
                                    position: CGPoint(x: clampedX, y: clampedY)
                                )
                            }
                        : nil
                    )
                    .gesture(
                        clip.id == viewModel.selectedClipID ?
                        MagnifyGesture()
                            .onChanged { value in
                                viewModel.updateTextScale(
                                    trackIndex: item.trackIndex,
                                    clipIndex: item.clipIndex,
                                    scale: textData.scale * value.magnification
                                )
                            }
                        : nil
                    )
                    .gesture(
                        clip.id == viewModel.selectedClipID ?
                        RotateGesture()
                            .onChanged { value in
                                viewModel.updateTextRotation(
                                    trackIndex: item.trackIndex,
                                    clipIndex: item.clipIndex,
                                    rotation: textData.rotation + value.rotation.degrees
                                )
                            }
                        : nil
                    )
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
        ToolbarView(viewModel: viewModel, onAddMedia: { showMediaPicker = true })
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
            ForEach(viewModel.stickers) { sticker in
                Text(sticker.emoji)
                    .font(.system(size: 48 * sticker.scale))
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                    .position(
                        x: sticker.position.x * geo.size.width,
                        y: sticker.position.y * geo.size.height
                    )
                    .overlay(
                        viewModel.selectedStickerID == sticker.id ?
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(red: 0.42, green: 0.36, blue: 0.91), lineWidth: 2)
                            .padding(-4)
                        : nil
                    )
                    .onTapGesture {
                        viewModel.selectedStickerID = sticker.id
                        viewModel.selectedClipID = nil
                        viewModel.selectedVideoTrackIndex = nil
                    }
                    .gesture(
                        viewModel.selectedStickerID == sticker.id ?
                        DragGesture()
                            .onChanged { value in
                                let newX = value.location.x / geo.size.width
                                let newY = value.location.y / geo.size.height
                                let clampedX = max(0.05, min(0.95, newX))
                                let clampedY = max(0.05, min(0.95, newY))
                                viewModel.updateStickerPosition(
                                    id: sticker.id,
                                    position: CGPoint(x: clampedX, y: clampedY)
                                )
                            }
                            .onEnded { _ in
                                viewModel.saveProject()
                            }
                        : nil
                    )
                    .gesture(
                        viewModel.selectedStickerID == sticker.id ?
                        MagnifyGesture()
                            .onChanged { value in
                                viewModel.updateStickerScale(
                                    id: sticker.id,
                                    scale: sticker.scale * value.magnification
                                )
                            }
                            .onEnded { _ in
                                viewModel.saveProject()
                            }
                        : nil
                    )
                    .onTapGesture(count: 2) {
                        viewModel.removeSticker(id: sticker.id)
                    }
            }
        }
    }

    @ViewBuilder
    private var videoTrackOverlayLayer: some View {
        GeometryReader { geo in
            let overlayTracks = viewModel.videoTracks.filter { $0.index != viewModel.videoTracks.first?.index }
            ForEach(overlayTracks, id: \.track.id) { item in
                VideoLayerOverlayView(
                    item: item,
                    geoSize: geo.size,
                    viewModel: viewModel
                )
            }
        }
    }
}

struct VideoLayerOverlayView: View {
    let item: (index: Int, track: TimelineTrack)
    let geoSize: CGSize
    @Bindable var viewModel: EditorViewModel

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchMagnification: CGFloat = 1.0
    @GestureState private var rotationDelta: Angle = .zero

    var body: some View {
        let transform = item.track.transform ?? .fullFrame
        let isSelected = viewModel.selectedVideoTrackIndex == item.index

        let currentScale = transform.scale * pinchMagnification
        let boxW = geoSize.width * currentScale
        let boxH = geoSize.height * currentScale

        let posX = transform.position.x * geoSize.width + dragOffset.width
        let posY = transform.position.y * geoSize.height + dragOffset.height

        let currentRotation = transform.rotation + rotationDelta.degrees

        RoundedRectangle(cornerRadius: 6)
            .fill(Color.clear)
            .frame(width: boxW, height: boxH)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected
                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                        : Color.white.opacity(0.4),
                        lineWidth: isSelected ? 2.5 : 1.5
                    )
            )
            .overlay(alignment: .topLeading) {
                Text("Layer \(item.index)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                        : Color.black.opacity(0.6)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .offset(x: 4, y: 4)
            }
            .overlay {
                if isSelected {
                    ForEach(0..<4, id: \.self) { corner in
                        Circle()
                            .fill(Color(red: 0.42, green: 0.36, blue: 0.91))
                            .frame(width: 10, height: 10)
                            .offset(
                                x: corner % 2 == 0 ? -boxW / 2 + 5 : boxW / 2 - 5,
                                y: corner < 2 ? -boxH / 2 + 5 : boxH / 2 - 5
                            )
                    }
                }
            }
            .rotationEffect(.degrees(currentRotation))
            .position(x: posX, y: posY)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedVideoTrackIndex = item.index
                viewModel.selectedClipID = nil
                viewModel.selectedStickerID = nil
            }
            .gesture(
                isSelected ?
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
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
                : nil
            )
            .gesture(
                isSelected ?
                MagnifyGesture()
                    .updating($pinchMagnification) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        let newScale = max(0.1, min(2.0, transform.scale * value.magnification))
                        viewModel.updateTrackScale(
                            trackIndex: item.index,
                            scale: newScale
                        )
                        viewModel.saveProject()
                    }
                : nil
            )
            .gesture(
                isSelected ?
                RotateGesture()
                    .updating($rotationDelta) { value, state, _ in
                        state = value.rotation
                    }
                    .onEnded { value in
                        let newRotation = transform.rotation + value.rotation.degrees
                        viewModel.updateTrackRotation(
                            trackIndex: item.index,
                            rotation: newRotation
                        )
                        viewModel.saveProject()
                    }
                : nil
            )
    }
}
