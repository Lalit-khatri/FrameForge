import SwiftUI

struct TimelineView: View {
    @Bindable var viewModel: EditorViewModel
    var onAddMedia: (() -> Void)? = nil
    @State private var trimDragClipID: UUID?
    @State private var trimDragSide: TrimSide = .start
    @State private var trimDragAccumulated: CGFloat = 0
    @State private var dragClipID: UUID?
    @State private var dragSourceTrackID: UUID?
    @State private var dragVerticalOffset: CGFloat = 0
    @State private var isDraggingScrub: Bool = false
    @State private var scrubAccumulated: CGFloat = 0
    @State private var showTransitionPicker: Bool = false
    @State private var transitionClipID: UUID?
    @State private var horizontalDragClipID: UUID?
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var lastDragX: CGFloat = 0
    @State private var transitionTrackID: UUID?

    private let trackHeight: CGFloat = 52
    private let rulerHeight: CGFloat = 24
    private let pixelsPerSecond: CGFloat = 80
    private let labelWidth: CGFloat = 44
    private let handleWidth: CGFloat = 10
    private let playheadLeftPadding: CGFloat = 0

    enum TrimSide { case start, end }

    var body: some View {
        VStack(spacing: 0) {
            zoomBar
            fixedPlayheadTimeline
        }
        .background(Color(white: 0.06))
        .sheet(isPresented: $showTransitionPicker) {
            transitionPickerSheet
        }
    }

    private var scaledPixelsPerSecond: CGFloat {
        pixelsPerSecond * viewModel.zoomScale
    }

    private var contentDuration: Double {
        max(viewModel.totalDuration, 10)
    }

    // MARK: - Zoom Bar

    private var zoomBar: some View {
        HStack(spacing: 8) {
            Slider(value: $viewModel.zoomScale, in: 0.1...5.0)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .frame(width: 120)

            Text("\(Int(viewModel.zoomScale * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .fixedSize()

            Spacer()

            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundColor(viewModel.canUndo ? .white.opacity(0.8) : .gray.opacity(0.3))
            }
            .disabled(!viewModel.canUndo)

            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.caption)
                    .foregroundColor(viewModel.canRedo ? .white.opacity(0.8) : .gray.opacity(0.3))
            }
            .disabled(!viewModel.canRedo)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(white: 0.06))
    }

    // MARK: - Fixed Playhead Timeline (Stick at Left)

    private var fixedPlayheadTimeline: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let totalWidth = min(16000, max(contentDuration * Double(scaledPixelsPerSecond), Double(fullWidth)))
            let playheadTimeOffset = CGFloat(viewModel.currentTime) * scaledPixelsPerSecond

            ZStack(alignment: .leading) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        rulerRow(totalWidth: totalWidth)
                            .padding(.leading, labelWidth)
                            .offset(x: -playheadTimeOffset)

                        ForEach(viewModel.tracks) { track in
                            HStack(spacing: 0) {
                                trackLabelCell(track)
                                trackRow(track, totalWidth: totalWidth)
                            }
                            .offset(x: -playheadTimeOffset)
                        }
                    }
                }
                .clipped()
                .contentShape(Rectangle())
                .gesture(scrubGesture)

                Rectangle()
                    .fill(Color(red: 0.99, green: 0.32, blue: 0.56))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .offset(x: labelWidth)
                    .allowsHitTesting(false)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color(red: 0.99, green: 0.32, blue: 0.56))
                    .offset(x: labelWidth - 4, y: -geo.size.height / 2 + 6)
                    .allowsHitTesting(false)
            }
        }
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDraggingScrub {
                    isDraggingScrub = true
                    scrubAccumulated = 0
                    viewModel.pause()
                }
                let delta = value.translation.width - scrubAccumulated
                scrubAccumulated = value.translation.width
                let timeDelta = Double(-delta) / Double(scaledPixelsPerSecond)
                let oldTime = viewModel.currentTime
                let newTime = max(0, min(oldTime + timeDelta, viewModel.totalDuration))
                if Int(newTime * 2) != Int(oldTime * 2) {
                    HapticManager.shared.light()
                }
                viewModel.seek(to: newTime)
            }
            .onEnded { _ in
                isDraggingScrub = false
                scrubAccumulated = 0
            }
    }

    // MARK: - Track Labels (VN Style with + icons)

    private func trackLabelCell(_ track: TimelineTrack) -> some View {
        let config = trackLabelConfig(track.type)

        return ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 2) {
                Image(systemName: config.icon)
                    .font(.system(size: 14))
                    .foregroundColor(config.color)
            }
            .frame(width: labelWidth, height: trackHeight)
            .background(Color.white.opacity(0.03))

            Button {
                handleTrackLabelAction(track)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(config.color.opacity(0.8))
                    .clipShape(Circle())
            }
            .contentShape(Rectangle().size(width: 30, height: 30))
            .offset(x: -2, y: -2)
        }
    }


    private struct TrackLabelConfig {
        let icon: String
        let color: Color
    }

    private func trackLabelConfig(_ type: TrackType) -> TrackLabelConfig {
        switch type {
        case .video:
            return TrackLabelConfig(icon: "film", color: Color(red: 0.42, green: 0.36, blue: 0.91))
        case .audio:
            return TrackLabelConfig(icon: "music.note", color: Color(red: 0.13, green: 0.59, blue: 0.95))
        case .text:
            return TrackLabelConfig(icon: "textformat", color: Color(red: 0.99, green: 0.67, blue: 0.25))
        case .overlay:
            return TrackLabelConfig(icon: "photo.on.rectangle", color: Color(red: 0.3, green: 0.8, blue: 0.5))
        }
    }

    private func handleTrackLabelAction(_ track: TimelineTrack) {
        switch track.type {
        case .video:
            viewModel.showMediaPicker = true
        case .audio:
            viewModel.targetAudioTrackID = track.id
            viewModel.showAudioBrowser = true
        case .text:
            viewModel.showTextEditor = true
        case .overlay:
            viewModel.showStickerPicker = true
        }
    }

    // MARK: - Ruler

    private func rulerRow(totalWidth: Double) -> some View {
        Canvas { context, size in
            let interval = timeInterval(for: viewModel.zoomScale)
            var time: Double = 0
            while time <= contentDuration {
                let x = time * Double(scaledPixelsPerSecond)
                let isMajor = interval > 0 && time.truncatingRemainder(dividingBy: interval * 5) < 0.01
                let tickH: CGFloat = isMajor ? 12 : 6

                var path = Path()
                path.move(to: CGPoint(x: x, y: Double(rulerHeight) - Double(tickH)))
                path.addLine(to: CGPoint(x: x, y: Double(rulerHeight)))
                context.stroke(path, with: .color(.gray.opacity(0.35)), lineWidth: 1)

                if isMajor {
                    context.draw(
                        Text(TimeFormatter.formatSimple(seconds: time))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6)),
                        at: CGPoint(x: x, y: 5)
                    )
                }
                time += interval
            }
        }
        .frame(width: totalWidth, height: rulerHeight)
    }

    // MARK: - Track Row

    private func trackRow(_ track: TimelineTrack, totalWidth: Double) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .frame(height: trackHeight)

            if track.clips.isEmpty {
                Button {
                     handleTrackLabelAction(track)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10))
                        Text(track.type == .audio ? "Tap to add music" :
                             track.type == .text ? "Tap to add subtitle" :
                             "Tap to add media")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.gray.opacity(0.4))
                    .padding(.leading, 10)
                }
            }

            ForEach(Array(track.clips.enumerated()), id: \.element.id) { idx, clip in
                let clipWidth = max(36, clip.effectiveDuration * Double(scaledPixelsPerSecond))
                let xOffset = clip.startTime * Double(scaledPixelsPerSecond)

                clipView(clip, track: track)
                    .offset(x: xOffset)

                if idx < track.clips.count - 1 {
                    let nextClip = track.clips[idx + 1]
                    let gap = abs(nextClip.startTime - clip.endTime)
                    if gap < 0.01 {
                        let junctionX = clip.endTime * Double(scaledPixelsPerSecond)
                        transitionButton(clip: clip, nextClip: nextClip, track: track)
                            .offset(x: junctionX - 10)
                            .zIndex(50)
                    }
                }
            }
        }
        .frame(width: totalWidth, height: trackHeight)
        .clipped()
    }

    // MARK: - Transition Button Between Clips

    private func transitionButton(clip: TimelineClip, nextClip: TimelineClip, track: TimelineTrack) -> some View {
        let hasTransition = clip.transitionID != nil && clip.transitionID != "none"
        let transIcon = TransitionType.allTransitions.first(where: { $0.id == clip.transitionID })?.icon

        return Button {
            transitionClipID = clip.id
            transitionTrackID = track.id
            showTransitionPicker = true
            HapticManager.shared.light()
        } label: {
            ZStack {
                if hasTransition, let icon = transIcon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color(red: 0.99, green: 0.67, blue: 0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }
        }
    }

    // MARK: - Transition Picker Sheet

    private var transitionPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                    ForEach(TransitionType.allTransitions) { transition in
                        Button {
                            applyTransition(transition)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: transition.icon)
                                    .font(.title3)
                                    .foregroundColor(currentTransitionID == transition.id ? .white : .gray)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(currentTransitionID == transition.id
                                                  ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                                  : Color.white.opacity(0.08))
                                    )
                                Text(transition.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Transition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showTransitionPicker = false
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }

    private var currentTransitionID: String? {
        guard let clipID = transitionClipID,
              let trackID = transitionTrackID,
              let track = viewModel.tracks.first(where: { $0.id == trackID }),
              let clip = track.clips.first(where: { $0.id == clipID }) else {
            return nil
        }
        return clip.transitionID
    }

    private func applyTransition(_ transition: TransitionType) {
        guard let clipID = transitionClipID,
              let trackID = transitionTrackID else { return }
        viewModel.setTransition(clipID: clipID, trackID: trackID, transitionID: transition.id)
        showTransitionPicker = false
        HapticManager.shared.success()
    }

    // MARK: - Clip View

    private func clipView(_ clip: TimelineClip, track: TimelineTrack) -> some View {
        let clipWidth = min(16000, max(36, clip.effectiveDuration * Double(scaledPixelsPerSecond)))
        let isSelected = clip.id == viewModel.selectedClipID
        let clipColor = colorForTrackType(track.type)

        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(clipColor.opacity(isSelected ? 0.75 : 0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
                )

            if let thumbData = clip.thumbnailData, let uiImage = UIImage(data: thumbData) {
                HStack(spacing: 0) {
                    ForEach(0..<max(1, Int(clipWidth / 60)), id: \.self) { _ in
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: trackHeight - 10)
                            .clipped()
                            .opacity(0.3)
                    }
                }
                .cornerRadius(4)
                .padding(.horizontal, handleWidth)
                .padding(.vertical, 3)
            }

            if track.type == .audio {
                HStack(spacing: 1) {
                    let barCount = max(4, Int(clipWidth / 3))
                    ForEach(0..<barCount, id: \.self) { i in
                        let seed = abs(sin(Double(i) * 1.618 + Double(clip.id.hashValue))) 
                        let h = CGFloat(6 + seed * Double(trackHeight - 18))
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.5))
                            .frame(width: 2, height: h)
                    }
                }
                .padding(.horizontal, handleWidth + 2)
                .padding(.vertical, 4)
                .frame(height: trackHeight, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 1) {
                if let textOverlay = clip.textOverlay {
                    Text(textOverlay.text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    Text(TimeFormatter.formatSimple(seconds: clip.effectiveDuration))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, handleWidth + 4)
            .frame(maxWidth: .infinity, alignment: .leading)

            if clip.filterID != nil {
                HStack {
                    Spacer()
                    Image(systemName: "camera.filters")
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(4)
                }
            }

            if clip.isMuted {
                HStack {
                    Spacer()
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(4)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }

            if isSelected {
                HStack(spacing: 0) {
                    trimHandle(clip: clip, side: .start, color: clipColor)
                    Spacer()
                    trimHandle(clip: clip, side: .end, color: clipColor)
                }
            }
        }
        .frame(width: clipWidth, height: trackHeight)
        .opacity(dragClipID == clip.id ? 0.6 : 1.0)
        .offset(y: dragClipID == clip.id ? dragVerticalOffset : 0)
        .zIndex(dragClipID == clip.id ? 100 : 0)
        .onTapGesture {
            viewModel.selectClipFromTimeline(clipID: clip.id, trackID: track.id)
            HapticManager.shared.selection()
        }
        .contextMenu {
            Button {
                viewModel.toggleClipMute(clipID: clip.id)
            } label: {
                Label(clip.isMuted ? "Unmute" : "Mute", systemImage: clip.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            Button(role: .destructive) {
                viewModel.deleteSelectedClip()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture())
                .onChanged { value in
                    switch value {
                    case .second(true, let drag):
                        if dragClipID == nil {
                            dragClipID = clip.id
                            dragSourceTrackID = track.id
                            lastDragX = 0
                            HapticManager.shared.medium()
                        }
                        if let drag = drag {
                            dragVerticalOffset = drag.translation.height
                            let currentX = drag.translation.width
                            let deltaX = currentX - lastDragX
                            if abs(deltaX) > 1 {
                                let timeDelta = Double(deltaX) / Double(scaledPixelsPerSecond)
                                viewModel.moveClipInTrack(clipID: clip.id, trackID: track.id, timeDelta: timeDelta, persist: false)
                                lastDragX = currentX
                            }
                        }
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    guard let sourceTrackID = dragSourceTrackID else {
                        resetDragState()
                        return
                    }

                    let trackOffset = Int(round(dragVerticalOffset / (trackHeight + 1)))

                    if trackOffset != 0,
                       let sourceIdx = viewModel.tracks.firstIndex(where: { $0.id == sourceTrackID }) {
                        let targetIdx = sourceIdx + trackOffset
                        if targetIdx >= 0 && targetIdx < viewModel.tracks.count {
                            let targetTrack = viewModel.tracks[targetIdx]
                            viewModel.moveClipToTrack(
                                clipID: clip.id,
                                fromTrackID: sourceTrackID,
                                toTrackID: targetTrack.id
                            )
                        }
                    }

                    viewModel.saveProject()
                    resetDragState()
                    lastDragX = 0
                }
        )
    }

    private func trimHandle(clip: TimelineClip, side: TrimSide, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(0.9))
            .frame(width: handleWidth, height: trackHeight - 4)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 2, height: 16)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = value.translation.width - trimDragAccumulated
                        if side == .start {
                            viewModel.trimClipStart(clipID: clip.id, deltaPx: delta, pixelsPerSecond: scaledPixelsPerSecond)
                        } else {
                            viewModel.trimClipEnd(clipID: clip.id, deltaPx: delta, pixelsPerSecond: scaledPixelsPerSecond)
                        }
                        trimDragAccumulated = value.translation.width
                    }
                    .onEnded { _ in
                        trimDragAccumulated = 0
                        Task { await viewModel.rebuildComposition() }
                    }
            )
    }

    // MARK: - Helpers

    private func colorForTrackType(_ type: TrackType) -> Color {
        switch type {
        case .video: return Color(red: 0.42, green: 0.36, blue: 0.91)
        case .audio: return Color(red: 0.13, green: 0.59, blue: 0.95)
        case .text: return Color(red: 0.99, green: 0.67, blue: 0.25)
        case .overlay: return Color(red: 0.3, green: 0.8, blue: 0.5)
        }
    }

    private func resetDragState() {
        withAnimation(.spring(response: 0.25)) {
            dragClipID = nil
            dragSourceTrackID = nil
            dragVerticalOffset = 0
        }
    }

    private func timeInterval(for zoom: CGFloat) -> Double {
        if zoom > 3 { return 0.5 }
        if zoom > 1.5 { return 1.0 }
        if zoom > 0.5 { return 2.0 }
        return 5.0
    }
}
