import SwiftUI
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers

@Observable
final class EditorViewModel {
    var tracks: [TimelineTrack] = []
    var currentTime: Double = 0
    var totalDuration: Double = 0
    var isPlaying = false
    var selectedClipID: UUID?
    var selectedTrackID: UUID?
    var activeTool: EditorTool = .none
    var showMediaPicker = false
    var showExportSheet = false
    var showFiltersPanel = false
    var showEffectsPanel = false
    var showTextEditor = false
    var showTransitionsPanel = false
    var showSpeedControl = false
    var showAudioMixer = false
    var showCropTool = false
    var showStickerPicker = false
    var showCaptionsView = false
    var showBackgroundRemoval = false
    var showKeyframeEditor = false
    var showMotionTracking = false
    var showLUTImport = false
    var show3DText = false
    var currentLUT: LUTData?
    var showCloudBackup = false
    var showShareView = false
    var showPlugins = false
    var showVoiceover = false
    var showChromaKey = false
    var showCurveSpeed = false
    var showAspectRatio = false
    var showPhotoImport = false
    var showPiP = false
    var showStabilization = false
    var showNoiseReduction = false
    var showBeatSync = false
    var showSplitScreen = false
    var showMasking = false
    var stickers: [StickerData] = []
    var zoomScale: CGFloat = 2.5
    var exportSettings = ExportSettings()
    var exportProgress: Float = 0
    var isExporting = false
    var exportError: String?
    var activeAudioEffects: Set<String> = []
    var previewScale: CGFloat = 1.0
    var previewOffset: CGSize = .zero
    var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    var cropAspectRatio: CropAspectRatio = .free
    var videoAspectRatio: CGFloat = 16.0 / 9.0

    var canvasRenderSize: CGSize {
        guard let project = currentProject else { return CGSize(width: 1920, height: 1080) }
        return CGSize(width: project.aspectRatio.width, height: project.aspectRatio.height)
    }
    var selectedVideoTrackIndex: Int?
    var selectedStickerID: UUID?
    var masterVolume: Float = 1.0
    var globalFadeIn: Double = 0.0   // seconds for project-wide fade-in
    var globalFadeOut: Double = 0.0  // seconds for project-wide fade-out
    var showAudioBrowser = false
    var showFullscreenPreview = false
    var hasUnsavedChanges = false
    var toastMessage: ToastMessage?

    var adjustBrightness: Float = 0
    var adjustContrast: Float = 0
    var adjustSaturation: Float = 0
    var adjustTemperature: Float = 0
    var adjustSharpness: Float = 0
    var adjustVignette: Float = 0

    var player: AVPlayer?
    var playerItem: AVPlayerItem?

    var showGrid: Bool { SettingsManager.shared.showGrid }
    var snapToGrid: Bool { SettingsManager.shared.snapToGrid }

    private let compositionEngine = CompositionEngine()
    private let exportPipeline = ExportPipeline()
    private let thumbnailGen = ThumbnailGenerator()
    private var timeObserver: Any?
    private var autoSaveTimer: Timer?
    private var undoStack: [Data] = []
    private var redoStack: [Data] = []
    private let maxUndoLevels = 30

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    weak var currentProject: Project?

    var selectedClip: TimelineClip? {
        for track in tracks {
            if let clip = track.clips.first(where: { $0.id == selectedClipID }) {
                return clip
            }
        }
        return nil
    }

    func selectClipFromTimeline(clipID: UUID, trackID: UUID) {
        selectedClipID = clipID
        selectedTrackID = trackID
        if let trackIdx = tracks.firstIndex(where: { $0.id == trackID }) {
            if tracks[trackIdx].type == .overlay {
                if let linkedSticker = stickers.first(where: { $0.clipID == clipID }) {
                    selectedStickerID = linkedSticker.id
                } else {
                    selectedStickerID = nil
                }
                selectedVideoTrackIndex = nil
            } else if tracks[trackIdx].type == .video {
                selectedVideoTrackIndex = trackIdx
                selectedStickerID = nil
            } else {
                selectedVideoTrackIndex = nil
                selectedStickerID = nil
            }
        } else {
            selectedVideoTrackIndex = nil
            selectedStickerID = nil
        }
    }

    var hasMedia: Bool {
        tracks.contains { !$0.clips.isEmpty }
    }

    var activeTextOverlays: [(clip: TimelineClip, trackIndex: Int, clipIndex: Int)] {
        var results: [(TimelineClip, Int, Int)] = []
        for (ti, track) in tracks.enumerated() where track.type == .text {
            for (ci, clip) in track.clips.enumerated() {
                if clip.textOverlay != nil && currentTime >= clip.startTime && currentTime < clip.endTime {
                    results.append((clip, ti, ci))
                }
            }
        }
        return results
    }

    init() {
        tracks = [
            TimelineTrack(type: .video, transform: .fullFrame),
            TimelineTrack(type: .audio),
        ]
    }

    func attachProject(_ project: Project) {
        currentProject = project
        videoAspectRatio = project.aspectRatio.width / project.aspectRatio.height
        if let data = project.trackData {
            if let decoded = try? JSONDecoder().decode([TimelineTrack].self, from: data) {
                tracks = decoded
                for i in 0..<tracks.count {
                    if (tracks[i].type == .video || tracks[i].type == .overlay) && tracks[i].transform == nil {
                        tracks[i].transform = .fullFrame
                    }
                    for j in 0..<tracks[i].clips.count {
                        if let url = tracks[i].clips[j].assetURL {
                            tracks[i].clips[j].assetURL = MediaStorageManager.shared.resolveMediaURL(url, projectID: project.id)
                        }
                    }
                }
                recalculateStartTimes()
                Task { await rebuildComposition() }
            }
        }
        if let sData = project.stickerData {
            if let decoded = try? JSONDecoder().decode([StickerData].self, from: sData) {
                stickers = decoded
            }
        }
        startAutoSaveIfNeeded()
    }

    func saveProject() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [self] in saveProject() }
            return
        }
        guard let project = currentProject else { return }
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        project.trackData = data
        project.stickerData = try? JSONEncoder().encode(stickers)
        project.modifiedAt = Date()
        if let firstClip = tracks.first?.clips.first, let thumbData = firstClip.thumbnailData {
            project.thumbnailData = thumbData
        }
        hasUnsavedChanges = false
    }

    func showToast(icon: String, text: String) {
        // Setting a new ToastMessage (with a new UUID) causes ToastOverlay
        // to treat it as a fresh view, reliably firing .onAppear and restarting
        // the dismiss timer — even for rapid back-to-back calls.
        withAnimation(.spring(response: 0.3)) {
            toastMessage = ToastMessage(icon: icon, text: text)
        }
    }

    private func startAutoSaveIfNeeded() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil

        guard SettingsManager.shared.autoSaveEnabled else { return }
        let interval = TimeInterval(SettingsManager.shared.autoSaveInterval)

        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performAutoSave()
        }
    }

    private func performAutoSave() {
        guard let project = currentProject else { return }
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        project.trackData = data
        project.modifiedAt = Date()
    }

    func saveState() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        let maxSteps = SettingsManager.shared.maxUndoSteps
        undoStack.append(data)
        if undoStack.count > maxSteps {
            undoStack.removeFirst(undoStack.count - maxSteps)
        }
        redoStack.removeAll()
        hasUnsavedChanges = true
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        if let currentData = try? JSONEncoder().encode(tracks) {
            redoStack.append(currentData)
        }
        if let restored = try? JSONDecoder().decode([TimelineTrack].self, from: previous) {
            tracks = restored
            recalculateStartTimes()
            Task { await rebuildComposition() }
        }
        HapticManager.shared.light()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        if let currentData = try? JSONEncoder().encode(tracks) {
            undoStack.append(currentData)
        }
        if let restored = try? JSONDecoder().decode([TimelineTrack].self, from: next) {
            tracks = restored
            recalculateStartTimes()
            Task { await rebuildComposition() }
        }
        HapticManager.shared.light()
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    // MARK: - Multi-Track Video

    var videoTracks: [(index: Int, track: TimelineTrack)] {
        tracks.enumerated().compactMap { (i, t) in
            t.type == .video || t.type == .overlay ? (i, t) : nil
        }
    }

    var videoTrackCount: Int { videoTracks.count }

    func addVideoTrack() {
        let layerIndex = videoTrackCount
        let transform = VideoTrackTransform.pipDefault(index: layerIndex)
        let newTrack = TimelineTrack(type: .video, transform: transform)
        saveState()
        tracks.append(newTrack)
        selectedVideoTrackIndex = tracks.count - 1
        saveProject()
        HapticManager.shared.success()
    }

    func addMediaToTrack(_ url: URL, trackIndex: Int) async {
        guard let projectID = currentProject?.id else { return }
        guard trackIndex < tracks.count, tracks[trackIndex].type == .video || tracks[trackIndex].type == .overlay else { return }

        let persistentURL = MediaStorageManager.shared.persistMedia(from: url, projectID: projectID) ?? url

        let asset = AVURLAsset(url: persistentURL)
        guard let duration = try? await asset.load(.duration) else { return }
        let durationSeconds = CMTimeGetSeconds(duration)
        let existingEnd = tracks[trackIndex].clips.last?.endTime ?? 0

        var clip = TimelineClip(
            assetURL: persistentURL,
            startTime: existingEnd,
            duration: durationSeconds,
            originalDuration: durationSeconds
        )

        let thumbSize = CGSize(width: 120, height: 68)
        if let thumb = await thumbnailGen.generateThumbnail(for: persistentURL, at: 0, size: thumbSize) {
            clip.thumbnailData = thumb.jpegData(compressionQuality: 0.5)
        }

        saveState()
        tracks[trackIndex].clips.append(clip)
        await rebuildComposition()
        saveProject()
        HapticManager.shared.success()
    }

    func updateTrackPosition(trackIndex: Int, position: CGPoint) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].transform?.position = position
        Task { await rebuildComposition() }
    }

    func updateTrackScale(trackIndex: Int, scale: CGFloat) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].transform?.scale = max(0.1, min(2.0, scale))
        Task { await rebuildComposition() }
    }

    func updateTrackRotation(trackIndex: Int, rotation: Double) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].transform?.rotation = rotation
        Task { await rebuildComposition() }
    }

    // MARK: - Media Import

    func addMediaFromURL(_ url: URL) async {
        guard let projectID = currentProject?.id else { return }

        let persistentURL = MediaStorageManager.shared.persistMedia(from: url, projectID: projectID) ?? url

        let asset = AVURLAsset(url: persistentURL)
        guard let duration = try? await asset.load(.duration) else { return }
        let durationSeconds = CMTimeGetSeconds(duration)
        let existingEnd = tracks.first?.clips.last?.endTime ?? 0

        if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
            let _ = try? await videoTrack.load(.naturalSize)
        }

        var clip = TimelineClip(
            assetURL: persistentURL,
            startTime: existingEnd,
            duration: durationSeconds,
            originalDuration: durationSeconds
        )

        let thumbSize = CGSize(width: 120, height: 68)
        if let thumb = await thumbnailGen.generateThumbnail(for: persistentURL, at: 0, size: thumbSize) {
            clip.thumbnailData = thumb.jpegData(compressionQuality: 0.5)
        }

        if !tracks.isEmpty {
            saveState()
            tracks[0].clips.append(clip)
        }

        await rebuildComposition()
        saveProject()
        HapticManager.shared.success()
    }

    func addAudioFromURL(_ url: URL) async {
        guard let projectID = currentProject?.id else { return }

        let persistentURL = MediaStorageManager.shared.persistMedia(from: url, projectID: projectID) ?? url

        let asset = AVURLAsset(url: persistentURL)
        guard let duration = try? await asset.load(.duration) else { return }
        let durationSeconds = CMTimeGetSeconds(duration)

        let audioTrackIndices = tracks.enumerated().filter { $0.element.type == .audio }
        let emptyTrackIndex = audioTrackIndices.first(where: { $0.element.clips.isEmpty })?.offset

        let targetIndex: Int
        if let emptyIdx = emptyTrackIndex {
            targetIndex = emptyIdx
        } else {
            let newTrack = TimelineTrack(type: .audio)
            tracks.append(newTrack)
            targetIndex = tracks.count - 1
        }

        let existingEnd = tracks[targetIndex].clips.last?.endTime ?? 0

        let clip = TimelineClip(
            assetURL: persistentURL,
            startTime: existingEnd,
            duration: durationSeconds,
            originalDuration: durationSeconds
        )

        saveState()
        tracks[targetIndex].clips.append(clip)
        await rebuildComposition()
        saveProject()
        HapticManager.shared.success()
    }

    func moveClipToTrack(clipID: UUID, fromTrackID: UUID, toTrackID: UUID) {
        guard fromTrackID != toTrackID else { return }

        guard let fromIndex = tracks.firstIndex(where: { $0.id == fromTrackID }),
              let toIndex = tracks.firstIndex(where: { $0.id == toTrackID }) else { return }

        guard tracks[fromIndex].type == tracks[toIndex].type else { return }

        guard let clipIndex = tracks[fromIndex].clips.firstIndex(where: { $0.id == clipID }) else { return }

        saveState()
        var clip = tracks[fromIndex].clips.remove(at: clipIndex)
        let existingEnd = tracks[toIndex].clips.last?.endTime ?? 0
        clip.startTime = existingEnd
        tracks[toIndex].clips.append(clip)
        recalculateStartTimes()
        Task { await rebuildComposition() }
        saveProject()
        HapticManager.shared.success()
    }

    // MARK: - Clip Editing

    func deleteSelectedClip() {
        guard let clipID = selectedClipID else { return }
        saveState()
        for i in 0..<tracks.count {
            tracks[i].clips.removeAll { $0.id == clipID }
        }
        selectedClipID = nil
        recalculateStartTimes()
        Task { await rebuildComposition() }
        saveProject()
        HapticManager.shared.medium()
        showToast(icon: "trash", text: "Clip deleted")
    }

    func splitClipAtPlayhead() {
        guard let clipID = selectedClipID else { return }
        saveState()
        for trackIndex in 0..<tracks.count {
            guard let clipIndex = tracks[trackIndex].clips.firstIndex(where: { $0.id == clipID }) else { continue }
            let clip = tracks[trackIndex].clips[clipIndex]

            let relativeTime = currentTime - clip.startTime
            guard relativeTime > 0.05 && relativeTime < clip.effectiveDuration - 0.05 else { return }

            let sourceTimeAtSplit = clip.trimStart + (relativeTime * Double(clip.speed))

            var firstHalf = TimelineClip(
                assetURL: clip.assetURL,
                startTime: clip.startTime,
                duration: clip.duration,
                originalDuration: clip.originalDuration
            )
            firstHalf.trimStart = clip.trimStart
            firstHalf.trimEnd = clip.duration - sourceTimeAtSplit
            firstHalf.speed = clip.speed
            firstHalf.volume = clip.volume
            firstHalf.filterID = clip.filterID
            firstHalf.thumbnailData = clip.thumbnailData
            firstHalf.textOverlay = clip.textOverlay

            var secondHalf = TimelineClip(
                assetURL: clip.assetURL,
                startTime: clip.startTime + relativeTime,
                duration: clip.duration,
                originalDuration: clip.originalDuration
            )
            secondHalf.trimStart = sourceTimeAtSplit
            secondHalf.trimEnd = clip.trimEnd
            secondHalf.speed = clip.speed
            secondHalf.volume = clip.volume
            secondHalf.filterID = clip.filterID
            secondHalf.thumbnailData = clip.thumbnailData
            secondHalf.textOverlay = clip.textOverlay

            tracks[trackIndex].clips[clipIndex] = firstHalf
            tracks[trackIndex].clips.insert(secondHalf, at: clipIndex + 1)

            selectedClipID = firstHalf.id

            Task { await rebuildComposition() }
            saveProject()
            HapticManager.shared.medium()
            return
        }
    }

    func duplicateSelectedClip() {
        guard let clipID = selectedClipID else { return }
        saveState()
        for i in 0..<tracks.count {
            guard let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) else { continue }
            let original = tracks[i].clips[j]

            var duplicate = TimelineClip(
                assetURL: original.assetURL,
                startTime: original.endTime,
                duration: original.duration,
                originalDuration: original.originalDuration
            )
            duplicate.trimStart = original.trimStart
            duplicate.trimEnd = original.trimEnd
            duplicate.speed = original.speed
            duplicate.volume = original.volume
            duplicate.filterID = original.filterID
            duplicate.textOverlay = original.textOverlay
            duplicate.thumbnailData = original.thumbnailData

            tracks[i].clips.insert(duplicate, at: j + 1)

            for k in (j + 2)..<tracks[i].clips.count {
                tracks[i].clips[k].startTime += duplicate.effectiveDuration
            }

            selectedClipID = duplicate.id
            Task { await rebuildComposition() }
            saveProject()
            HapticManager.shared.success()
            showToast(icon: "plus.square.on.square", text: "Clip duplicated")
            return
        }
    }

    func trimClipStart(clipID: UUID, deltaPx: CGFloat, pixelsPerSecond: CGFloat) {
        for i in 0..<tracks.count {
            guard let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) else { continue }

            let deltaTime = Double(deltaPx / pixelsPerSecond) * Double(tracks[i].clips[j].speed)
            let newTrimStart = max(0, tracks[i].clips[j].trimStart + deltaTime)
            let maxTrim = tracks[i].clips[j].duration - tracks[i].clips[j].trimEnd - 0.1
            tracks[i].clips[j].trimStart = min(newTrimStart, maxTrim)

            recalculateStartTimes(forTrack: i)
            return
        }
    }

    func trimClipEnd(clipID: UUID, deltaPx: CGFloat, pixelsPerSecond: CGFloat) {
        for i in 0..<tracks.count {
            guard let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) else { continue }

            let deltaTime = Double(deltaPx / pixelsPerSecond) * Double(tracks[i].clips[j].speed)
            let newTrimEnd = max(0, tracks[i].clips[j].trimEnd - deltaTime)
            let maxTrim = tracks[i].clips[j].duration - tracks[i].clips[j].trimStart - 0.1
            tracks[i].clips[j].trimEnd = min(newTrimEnd, maxTrim)

            recalculateStartTimes(forTrack: i)
            return
        }
    }

    func moveClip(clipID: UUID, newStartTime: Double) {
        for i in 0..<tracks.count {
            guard let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) else { continue }
            tracks[i].clips[j].startTime = max(0, newStartTime)
            tracks[i].clips.sort { $0.startTime < $1.startTime }
            Task { await rebuildComposition() }
            return
        }
    }

    func recalculateStartTimes(forTrack trackIndex: Int? = nil) {
        let indices: [Int]
        if let t = trackIndex {
            indices = [t]
        } else {
            indices = Array(0..<tracks.count)
        }

        for i in indices {
            var currentStart: Double = 0
            for j in 0..<tracks[i].clips.count {
                tracks[i].clips[j].startTime = currentStart
                currentStart = tracks[i].clips[j].endTime
            }
        }

        totalDuration = compositionEngine.getTotalDuration(for: tracks)
    }

    // MARK: - Filters & Effects

    func applyFilter(_ filter: VideoFilter, toClip clipID: UUID) {
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].filterID = filter.id
            }
        }
        Task { await rebuildComposition() }
        HapticManager.shared.selection()
        showToast(icon: "camera.filters", text: "Filter applied")
    }

    func applyAdjustments(toClip clipID: UUID) {
        let adj = ColorAdjustments(
            brightness: adjustBrightness,
            contrast: adjustContrast,
            saturation: adjustSaturation,
            temperature: adjustTemperature,
            sharpness: adjustSharpness,
            vignette: adjustVignette
        )
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].colorAdjustments = adj
            }
        }
        Task { await rebuildComposition() }
    }

    func addEffect(_ effect: ClipEffect, toClip clipID: UUID) {
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                if !tracks[i].clips[j].effects.contains(where: { $0.type == effect.type }) {
                    tracks[i].clips[j].effects.append(effect)
                }
            }
        }
        saveProject()
        Task { await rebuildComposition() }
        HapticManager.shared.selection()
    }

    func removeEffect(_ effectType: EffectType, fromClip clipID: UUID) {
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].effects.removeAll { $0.type == effectType }
            }
        }
        saveProject()
        Task { await rebuildComposition() }
    }

    func updateEffectIntensity(_ effectType: EffectType, intensity: Float, forClip clipID: UUID) {
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                if let k = tracks[i].clips[j].effects.firstIndex(where: { $0.type == effectType }) {
                    tracks[i].clips[j].effects[k].intensity = intensity
                }
            }
        }
        saveProject()
        Task { await rebuildComposition() }
    }

    func setTransition(_ transitionID: String, forClip clipID: UUID, duration: Double = 0.3) {
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].transitionID = transitionID
                tracks[i].clips[j].transitionDuration = duration
            }
        }
        Task { await rebuildComposition() }
        HapticManager.shared.selection()
    }

    func setTransition(clipID: UUID, trackID: UUID, transitionID: String) {
        guard let trackIdx = tracks.firstIndex(where: { $0.id == trackID }),
              let clipIdx = tracks[trackIdx].clips.firstIndex(where: { $0.id == clipID }) else { return }
        tracks[trackIdx].clips[clipIdx].transitionID = transitionID == "none" ? nil : transitionID
        Task { await rebuildComposition() }
    }

    func setSpeed(_ speed: Float, forClip clipID: UUID) {
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].speed = speed
                tracks[i].clips[j].speedCurve = nil  // clear any existing curve
            }
        }
        recalculateStartTimes()
        Task { await rebuildComposition() }
    }

    /// Apply a speed curve (Catmull-Rom control points from SpeedControlView) to a clip.
    /// Y=0 = fast (8x), Y=0.5 = normal (1x), Y=1 = slow (0.1x).
    func setSpeedCurve(curvePoints: [CGPoint], forClip clipID: UUID) {
        saveState()
        let curveData = SpeedCurveData(controlPoints: curvePoints)
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].speedCurve = curveData
                tracks[i].clips[j].speed = curveData.averageSpeedMultiplier
            }
        }
        recalculateStartTimes()
        Task { await rebuildComposition() }
        showToast(icon: "waveform.path", text: "Speed curve applied")
    }

    func setVolume(_ volume: Float, forClip clipID: UUID) {
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].volume = volume
            }
        }
        saveProject()
        Task { await rebuildComposition() }
    }

    func toggleTrackMute(trackID: UUID) {
        guard let idx = tracks.firstIndex(where: { $0.id == trackID }) else { return }
        tracks[idx].isMuted.toggle()
        Task { await rebuildComposition() }
        HapticManager.shared.selection()
    }

    func toggleClipMute(clipID: UUID) {
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].isMuted.toggle()
                Task { await rebuildComposition() }
                HapticManager.shared.selection()
                return
            }
        }
    }

    func reverseClip(clipID: UUID) {
        saveState()
        for i in 0..<tracks.count {
            if let j = tracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[i].clips[j].isReversed.toggle()
                Task { await rebuildComposition() }
                HapticManager.shared.medium()
                showToast(icon: "arrow.uturn.left", text: tracks[i].clips[j].isReversed ? "Clip reversed" : "Reverse removed")
                return
            }
        }
    }

    func setTrackVolume(_ volume: Float, trackID: UUID) {
        guard let idx = tracks.firstIndex(where: { $0.id == trackID }) else { return }
        tracks[idx].volume = max(0, min(2.0, volume))
        Task { await rebuildComposition() }
    }

    func setMasterVolume(_ volume: Float) {
        masterVolume = max(0, min(2.0, volume))
        Task { await rebuildComposition() }
    }

    /// Store global fade-in/fade-out durations (seconds).
    /// These are passed to the export pipeline as volume ramps.
    func setGlobalFade(fadeIn: Double, fadeOut: Double) {
        globalFadeIn = max(0, fadeIn)
        globalFadeOut = max(0, fadeOut)
        Task { await rebuildComposition() }
    }

    func toggleAudioEffect(_ effect: String) {
        if activeAudioEffects.contains(effect) {
            activeAudioEffects.remove(effect)
        } else {
            activeAudioEffects.insert(effect)
        }
        HapticManager.shared.selection()
    }

    // MARK: - Text

    func addTextOverlay(_ text: TextOverlayData, duration: Double = 10) {
        if tracks.first(where: { $0.type == .text }) == nil {
            tracks.append(TimelineTrack(type: .text))
        }
        guard let textTrackIndex = tracks.firstIndex(where: { $0.type == .text }) else { return }

        let clampedDuration = max(1, duration)
        var clip = TimelineClip(assetURL: nil, startTime: currentTime, duration: clampedDuration, originalDuration: clampedDuration)
        clip.textOverlay = text
        tracks[textTrackIndex].clips.append(clip)
        totalDuration = compositionEngine.getTotalDuration(for: tracks)
        Task { await rebuildComposition() }
        HapticManager.shared.success()
    }

    func addCaptionSegments(_ segments: [CaptionSegment], style: CaptionStyle) {
        removeCaptions()

        if tracks.first(where: { $0.type == .text }) == nil {
            tracks.append(TimelineTrack(type: .text))
        }
        guard let textTrackIndex = tracks.firstIndex(where: { $0.type == .text }) else { return }

        for segment in segments {
            let overlay = style.toOverlay(text: segment.text)
            let duration = max(0.3, segment.endTime - segment.startTime)
            var clip = TimelineClip(
                assetURL: nil,
                startTime: segment.startTime,
                duration: duration,
                originalDuration: duration
            )
            clip.textOverlay = overlay
            tracks[textTrackIndex].clips.append(clip)
        }

        totalDuration = compositionEngine.getTotalDuration(for: tracks)
        Task { await rebuildComposition() }
        HapticManager.shared.success()
    }

    func removeCaptions() {
        if let idx = tracks.firstIndex(where: { $0.type == .text }) {
            tracks[idx].clips.removeAll()
        }
    }

    func addKeyframe(at time: Double, forClip clipID: UUID) {
        guard let (ti, ci) = findClipIndices(clipID) else { return }
        if tracks[ti].clips[ci].keyframeAnimation == nil {
            tracks[ti].clips[ci].keyframeAnimation = KeyframeAnimation()
        }
        tracks[ti].clips[ci].keyframeAnimation?.addKeyframe(at: time)
    }

    func removeKeyframe(id: UUID, fromClip clipID: UUID) {
        guard let (ti, ci) = findClipIndices(clipID) else { return }
        tracks[ti].clips[ci].keyframeAnimation?.removeKeyframe(id: id)
    }

    func setKeyframeEasing(_ easing: KeyframeEasing, forClip clipID: UUID) {
        guard let (ti, ci) = findClipIndices(clipID) else { return }
        tracks[ti].clips[ci].keyframeAnimation?.easing = easing
    }

    func updateKeyframeAtPlayhead(_ time: Double, forClip clipID: UUID, modify: (inout Keyframe) -> Void) {
        guard let (ti, ci) = findClipIndices(clipID) else { return }
        if tracks[ti].clips[ci].keyframeAnimation == nil {
            tracks[ti].clips[ci].keyframeAnimation = KeyframeAnimation()
        }
        var anim = tracks[ti].clips[ci].keyframeAnimation!
        if let idx = anim.keyframes.firstIndex(where: { abs($0.time - time) < 0.05 }) {
            modify(&anim.keyframes[idx])
        } else {
            var kf = anim.interpolated(at: time) ?? Keyframe(time: time)
            kf = Keyframe(time: time, positionX: kf.positionX, positionY: kf.positionY,
                          scale: kf.scale, rotation: kf.rotation, opacity: kf.opacity)
            modify(&kf)
            anim.keyframes.append(kf)
            anim.keyframes.sort { $0.time < $1.time }
        }
        tracks[ti].clips[ci].keyframeAnimation = anim
    }

    func findClipIndices(_ clipID: UUID) -> (Int, Int)? {
        for (ti, track) in tracks.enumerated() {
            if let ci = track.clips.firstIndex(where: { $0.id == clipID }) {
                return (ti, ci)
            }
        }
        return nil
    }

    func applyMotionTrack(_ data: MotionTrackData, toClip clipID: UUID) {
        guard let (ti, ci) = findClipIndices(clipID) else { return }
        tracks[ti].clips[ci].motionTrack = data
    }

    /// Applies beat sync to the primary video track by splitting/transitioning clips at each beat timestamp.
    func applyBeatSync(beats: [Double], action: SyncAction) {
        guard !beats.isEmpty else { return }
        saveState()

        // Work on the first video track only
        guard let trackIndex = tracks.indices.first(where: { tracks[$0].type == .video }) else { return }

        // Sort beats and remove ones too close together or outside the timeline
        let minGap = 0.15
        let sortedBeats = beats.sorted()
        var filteredBeats: [Double] = []
        var lastBeat = -minGap
        for beat in sortedBeats {
            if beat - lastBeat >= minGap && beat < totalDuration - 0.1 {
                filteredBeats.append(beat)
                lastBeat = beat
            }
        }

        var offset = 0  // track insertions to keep indices valid
        let originalClipCount = tracks[trackIndex].clips.count

        for beat in filteredBeats {
            let adjustedIndex = offset
            // Find which clip in the track contains this beat time
            guard let clipIndex = (0..<tracks[trackIndex].clips.count).first(where: { i in
                let c = tracks[trackIndex].clips[i]
                return c.startTime < beat && c.endTime > beat
            }) else { continue }

            let clip = tracks[trackIndex].clips[clipIndex]
            let relativeTime = beat - clip.startTime
            guard relativeTime > 0.05 && relativeTime < clip.effectiveDuration - 0.05 else { continue }

            let sourceTimeAtSplit = clip.trimStart + (relativeTime * Double(clip.speed))

            var firstHalf = TimelineClip(
                assetURL: clip.assetURL,
                startTime: clip.startTime,
                duration: clip.duration,
                originalDuration: clip.originalDuration
            )
            firstHalf.trimStart = clip.trimStart
            firstHalf.trimEnd  = clip.duration - sourceTimeAtSplit
            firstHalf.speed    = clip.speed
            firstHalf.volume   = clip.volume
            firstHalf.filterID = clip.filterID
            firstHalf.thumbnailData = clip.thumbnailData

            var secondHalf = TimelineClip(
                assetURL: clip.assetURL,
                startTime: clip.startTime + relativeTime,
                duration: clip.duration,
                originalDuration: clip.originalDuration
            )
            secondHalf.trimStart = sourceTimeAtSplit
            secondHalf.trimEnd   = clip.trimEnd
            secondHalf.speed     = clip.speed
            secondHalf.volume    = clip.volume
            secondHalf.filterID  = clip.filterID
            secondHalf.thumbnailData = clip.thumbnailData

            // Apply beat action
            switch action {
            case .cut:
                break  // plain cut — no extra modifications
            case .transition:
                // Set a quick fade transition on the first half
                firstHalf.transitionID = "fade"
                firstHalf.transitionDuration = 0.12
            case .flash:
                // Brief white flash effect on second half
                let flashEffect = ClipEffect(type: .opacity, intensity: 0.0)
                secondHalf.effects.append(flashEffect)
            }

            tracks[trackIndex].clips[clipIndex] = firstHalf
            tracks[trackIndex].clips.insert(secondHalf, at: clipIndex + 1)
            offset += 1
        }

        Task { await rebuildComposition() }
        saveProject()
        let count = filteredBeats.count
        showToast(icon: "metronome", text: "\(count) beat sync cuts applied")
        HapticManager.shared.success()
    }

    func addFreezeFrame() {
        guard let clip = selectedClip else { return }
        saveState()
        var freezeClip = TimelineClip(assetURL: clip.assetURL, startTime: clip.endTime, duration: 2.0, originalDuration: 2.0)
        freezeClip.trimStart = currentTime - clip.startTime
        freezeClip.trimEnd = clip.duration - (currentTime - clip.startTime) - 0.03
        freezeClip.speed = 0.001
        if let trackIdx = tracks.firstIndex(where: { $0.type == .video }) {
            tracks[trackIdx].clips.append(freezeClip)
            recalculateStartTimes()
            Task { await rebuildComposition() }
            showToast(icon: "pause.rectangle", text: "Freeze frame added")
        }
    }

    func addVoiceoverClip(url: URL, duration: Double) {
        saveState()
        let clip = TimelineClip(assetURL: url, startTime: currentTime, duration: duration, originalDuration: duration)
        if let audioTrackIdx = tracks.firstIndex(where: { $0.type == .audio }) {
            tracks[audioTrackIdx].clips.append(clip)
        } else {
            var audioTrack = TimelineTrack(type: .audio)
            audioTrack.clips.append(clip)
            tracks.append(audioTrack)
        }
        recalculateStartTimes()
        Task { await rebuildComposition() }
    }

    func applyChromaKey(color: ChromaKeyColor, threshold: Float, toClip clipID: UUID) {
        saveState()
        guard let (ti, ci) = findClipIndices(clipID) else { return }
        let effect = ClipEffect(type: .backgroundRemoval, intensity: threshold)
        if !tracks[ti].clips[ci].effects.contains(where: { $0.type == .backgroundRemoval }) {
            tracks[ti].clips[ci].effects.append(effect)
        }
    }

    func updateTextPosition(trackIndex: Int, clipIndex: Int, position: CGPoint) {
        guard trackIndex < tracks.count && clipIndex < tracks[trackIndex].clips.count else { return }
        tracks[trackIndex].clips[clipIndex].textOverlay?.position = position
    }

    func updateTextScale(trackIndex: Int, clipIndex: Int, scale: CGFloat) {
        guard trackIndex < tracks.count && clipIndex < tracks[trackIndex].clips.count else { return }
        tracks[trackIndex].clips[clipIndex].textOverlay?.scale = max(0.3, min(4.0, scale))
    }

    func updateTextRotation(trackIndex: Int, clipIndex: Int, rotation: Double) {
        guard trackIndex < tracks.count && clipIndex < tracks[trackIndex].clips.count else { return }
        tracks[trackIndex].clips[clipIndex].textOverlay?.rotation = rotation
    }

    // MARK: - Stickers

    func addSticker(emoji: String, gifURL: String? = nil) {
        saveState()
        let dur = totalDuration > 0 ? totalDuration : 10.0
        let stickerClip = TimelineClip(
            assetURL: nil,
            startTime: 0,
            duration: dur
        )
        var sticker = StickerData(emoji: emoji, gifURL: gifURL, startTime: 0, duration: dur)
        sticker.clipID = stickerClip.id
        stickers.append(sticker)
        selectedStickerID = sticker.id

        var stickerTrack = TimelineTrack(type: .overlay)
        stickerTrack.clips.append(stickerClip)
        tracks.append(stickerTrack)

        saveProject()
    }

    func removeSticker(id: UUID) {
        saveState()
        stickers.removeAll { $0.id == id }
        saveProject()
        HapticManager.shared.medium()
    }

    func updateStickerPosition(id: UUID, position: CGPoint) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[index].position = position
    }

    func updateStickerScale(id: UUID, scale: CGFloat) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[index].scale = max(0.3, min(4.0, scale))
    }

    func updateStickerRotation(id: UUID, rotation: Double) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[index].rotation = rotation
    }

    func moveClipInTrack(clipID: UUID, trackID: UUID, timeDelta: Double, persist: Bool = true) {
        guard let trackIdx = tracks.firstIndex(where: { $0.id == trackID }),
              let clipIdx = tracks[trackIdx].clips.firstIndex(where: { $0.id == clipID }) else { return }

        var newStart = max(0, tracks[trackIdx].clips[clipIdx].startTime + timeDelta)
        let clipDuration = tracks[trackIdx].clips[clipIdx].effectiveDuration

        if clipIdx > 0 {
            let prevEnd = tracks[trackIdx].clips[clipIdx - 1].endTime
            newStart = max(newStart, prevEnd)
        }

        let snapThreshold: Double = 0.1
        var snapTargets: [Double] = [0, currentTime]

        for (ti, track) in tracks.enumerated() {
            for clip in track.clips where clip.id != clipID {
                snapTargets.append(clip.startTime)
                snapTargets.append(clip.endTime)
            }
        }

        for target in snapTargets {
            if abs(newStart - target) < snapThreshold {
                newStart = target
                break
            }
            let newEnd = newStart + clipDuration
            if abs(newEnd - target) < snapThreshold {
                newStart = target - clipDuration
                break
            }
        }

        newStart = max(0, newStart)
        tracks[trackIdx].clips[clipIdx].startTime = newStart

        for i in (clipIdx + 1)..<tracks[trackIdx].clips.count {
            let prevEnd = tracks[trackIdx].clips[i - 1].endTime
            if tracks[trackIdx].clips[i].startTime < prevEnd {
                tracks[trackIdx].clips[i].startTime = prevEnd
            }
        }

        totalDuration = compositionEngine.getTotalDuration(for: tracks)
        if persist {
            saveProject()
        }
    }

    // MARK: - Crop

    func applyCropToSelectedClip() {
        guard let clipID = selectedClipID else { return }
        for trackIdx in tracks.indices {
            if let clipIdx = tracks[trackIdx].clips.firstIndex(where: { $0.id == clipID }) {
                tracks[trackIdx].clips[clipIdx].cropRect = cropRect
                break
            }
        }
        saveProject()
        Task { await rebuildComposition() }
        showCropTool = false
        HapticManager.shared.success()
    }

    // MARK: - Playback

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let player = player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        if currentTime >= totalDuration {
            seek(to: 0)
        }
        player.play()
        isPlaying = true
        startTimeObserver()
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func seek(to time: Double) {
        let clampedTime = max(0, min(time, totalDuration))
        currentTime = clampedTime
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stepForward() {
        seek(to: min(currentTime + (1.0/30.0), totalDuration))
    }

    func stepBackward() {
        seek(to: max(currentTime - (1.0/30.0), 0))
    }

    private func startTimeObserver() {
        guard let player = player else { return }
        if let existing = timeObserver {
            player.removeTimeObserver(existing)
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            let newTime = CMTimeGetSeconds(time)
            if newTime.isFinite && newTime >= 0 {
                self.currentTime = newTime
            }
            if self.currentTime >= self.totalDuration && self.totalDuration > 0 {
                self.pause()
            }
        }
    }

    // MARK: - Composition

    @MainActor
    func rebuildComposition() async {
        do {
            let wasPlaying = isPlaying
            let savedTime = currentTime

            if wasPlaying {
                player?.pause()
                isPlaying = false
            }

            let (comp, videoComp, audioMix) = try await compositionEngine.buildComposition(from: tracks, renderSize: canvasRenderSize, cropRect: cropRect, masterVolume: masterVolume)
            let duration = compositionEngine.getTotalDuration(for: tracks)

            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)

            let item = AVPlayerItem(asset: comp)
            item.videoComposition = videoComp
            if let audioMix = audioMix {
                item.audioMix = audioMix
            }

            self.playerItem = item
            if self.player == nil {
                self.player = AVPlayer(playerItem: item)
            } else {
                self.player?.replaceCurrentItem(with: item)
            }
            self.totalDuration = duration

            let seekTime = min(savedTime, duration)
            if seekTime > 0 {
                seek(to: seekTime)
            }

            if wasPlaying {
                play()
            }
        } catch {
            print("Composition error: \(error)")
        }
    }

    // MARK: - Export

    func startExport() {
        guard !isExporting else { return }
        isExporting = true
        exportProgress = 0
        exportError = nil

        Task { @MainActor in
            do {
                var stickerInfos: [OverlayStickerInfo] = []
                for sticker in stickers {
                    var gifFrames: GifFrameData? = nil
                    if let gifURL = sticker.gifURL, let url = URL(string: gifURL) {
                        if let data = try? await URLSession.shared.data(from: url).0 {
                            gifFrames = GifFrameData.extract(from: data)
                        }
                    }
                    stickerInfos.append(OverlayStickerInfo(
                        emoji: sticker.emoji,
                        position: sticker.position,
                        scale: sticker.scale,
                        rotation: sticker.rotation,
                        startTime: sticker.startTime,
                        duration: sticker.duration,
                        gifFrames: gifFrames
                    ))
                }

                let (comp, videoComp, audioMix) = try await compositionEngine.buildComposition(from: tracks, stickers: stickerInfos, renderSize: canvasRenderSize, cropRect: cropRect, masterVolume: masterVolume)
                let url = try await exportPipeline.export(
                    composition: comp,
                    videoComposition: videoComp,
                    audioMix: audioMix,
                    settings: exportSettings
                ) { [weak self] progress in
                    self?.exportProgress = progress
                }

                try await exportPipeline.saveToPhotoLibrary(url)

                self.isExporting = false
                self.exportProgress = 1.0
                HapticManager.shared.success()
            } catch {
                self.isExporting = false
                self.exportError = error.localizedDescription
                HapticManager.shared.error()
            }
        }
    }

    func cancelExport() {
        exportPipeline.cancel()
        isExporting = false
    }

    func getThumbnails(for url: URL, count: Int) async -> [UIImage] {
        await thumbnailGen.generateThumbnailStrip(for: url, count: count, size: CGSize(width: 80, height: 45))
    }
}

enum EditorTool: String, CaseIterable {
    case none = "None"
    case trim = "Trim"
    case split = "Split"
    case speed = "Speed"
    case filters = "Filters"
    case text = "Text"
    case audio = "Audio"
    case transition = "Transition"
    case effects = "Effects"

    var icon: String {
        switch self {
        case .none: return "hand.point.up"
        case .trim: return "scissors"
        case .split: return "rectangle.split.2x1"
        case .speed: return "gauge.with.dots.needle.33percent"
        case .filters: return "camera.filters"
        case .text: return "textformat"
        case .audio: return "speaker.wave.2"
        case .transition: return "arrow.right.arrow.left"
        case .effects: return "sparkles"
        }
    }
}

enum CropAspectRatio: String, CaseIterable {
    case free = "Free"
    case r16x9 = "16:9"
    case r9x16 = "9:16"
    case r4x3 = "4:3"
    case r1x1 = "1:1"
    case r3x4 = "3:4"

    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .r16x9: return 16.0/9.0
        case .r9x16: return 9.0/16.0
        case .r4x3: return 4.0/3.0
        case .r1x1: return 1.0
        case .r3x4: return 3.0/4.0
        }
    }
}
