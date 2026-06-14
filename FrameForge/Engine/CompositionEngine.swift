import AVFoundation
import UIKit
import CoreImage

final class CompositionEngine: Sendable {

    func buildComposition(from tracks: [TimelineTrack], stickers: [OverlayStickerInfo] = [], renderSize: CGSize = CGSize(width: 1920, height: 1080), cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), masterVolume: Float = 1.0) async throws -> (AVMutableComposition, AVMutableVideoComposition?, AVMutableAudioMix?) {
        let comp = AVMutableComposition()

        var videoTrackIndex = 0
        var audioTrackIndex = 0
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        var videoLayerMappings: [(trackID: CMPersistentTrackID, transform: VideoTrackTransform, opacity: Float, effects: [ClipEffect])] = []
        var transitionInfos: [TransitionInfo] = []

        for track in tracks {
            switch track.type {
            case .video, .overlay:
                let clips = track.clips
                let hasAnyTransition = clips.dropLast().contains { clip in
                    clip.transitionID != nil && clip.transitionID != "none"
                }

                if hasAnyTransition && clips.count > 1 {
                    let trackIDA = CMPersistentTrackID(videoTrackIndex + 1)
                    let trackIDB = CMPersistentTrackID(videoTrackIndex + 2)
                    guard let compTrackA = comp.addMutableTrack(withMediaType: .video, preferredTrackID: trackIDA),
                          let compTrackB = comp.addMutableTrack(withMediaType: .video, preferredTrackID: trackIDB) else { continue }

                    var insertTimeA = CMTime.zero
                    var insertTimeB = CMTime.zero

                    for (idx, clip) in clips.enumerated() {
                        guard let url = clip.assetURL else { continue }
                        let asset = AVURLAsset(url: url)
                        guard let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }

                        let sourceStart = CMTime(seconds: clip.trimStart, preferredTimescale: 600)
                        let sourceDuration = CMTime(seconds: clip.effectiveDuration * Double(clip.speed), preferredTimescale: 600)
                        let timeRange = CMTimeRange(start: sourceStart, duration: sourceDuration)

                        let isTrackA = idx % 2 == 0
                        let targetTrack = isTrackA ? compTrackA : compTrackB
                        let insertTime = isTrackA ? insertTimeA : insertTimeB

                        try targetTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: insertTime)

                        if clip.speed != 1.0 {
                            let scaledDuration = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)
                            let scaleRange = CMTimeRange(start: insertTime, duration: sourceDuration)
                            targetTrack.scaleTimeRange(scaleRange, toDuration: scaledDuration)
                        }

                        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                            if let compositionAudioTrack = comp.addMutableTrack(
                                withMediaType: .audio,
                                preferredTrackID: CMPersistentTrackID(100 + audioTrackIndex)
                            ) {
                                try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: insertTime)
                                if clip.speed != 1.0 {
                                    let scaledDuration = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)
                                    let scaleRange = CMTimeRange(start: insertTime, duration: sourceDuration)
                                    compositionAudioTrack.scaleTimeRange(scaleRange, toDuration: scaledDuration)
                                }
                                let params = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
                                let vol = (track.isMuted || clip.isMuted) ? Float(0) : (clip.volume * track.volume * masterVolume)
                                params.setVolume(vol, at: insertTime)
                                audioMixParams.append(params)
                                audioTrackIndex += 1
                            }
                        }

                        let clipDuration = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)

                        let hasTransitionToNext = idx < clips.count - 1
                            && clip.transitionID != nil
                            && clip.transitionID != "none"

                        let transDur: CMTime
                        if hasTransitionToNext {
                            transDur = CMTime(seconds: clip.transitionDuration, preferredTimescale: 600)
                        } else {
                            transDur = .zero
                        }

                        let nextInsert = CMTimeAdd(insertTime, CMTimeSubtract(clipDuration, transDur))

                        if isTrackA {
                            insertTimeA = CMTimeAdd(insertTime, clipDuration)
                            insertTimeB = nextInsert
                        } else {
                            insertTimeB = CMTimeAdd(insertTime, clipDuration)
                            insertTimeA = nextInsert
                        }

                        if hasTransitionToNext {
                            let transStart = CMTimeSubtract(CMTimeAdd(insertTime, clipDuration), transDur)
                            let transRange = CMTimeRange(start: transStart, duration: transDur)
                            let fromID = isTrackA ? trackIDA : trackIDB
                            let toID = isTrackA ? trackIDB : trackIDA
                            transitionInfos.append(TransitionInfo(
                                type: clip.transitionID!,
                                timeRange: transRange,
                                fromTrackID: fromID,
                                toTrackID: toID
                            ))
                        }
                    }

                    let layerTransform = track.transform ?? .fullFrame
                    let trackEffects = track.clips.flatMap { $0.effects }
                    videoLayerMappings.append((trackID: trackIDA, transform: layerTransform, opacity: track.opacity, effects: trackEffects))
                    videoLayerMappings.append((trackID: trackIDB, transform: layerTransform, opacity: track.opacity, effects: []))
                    videoTrackIndex += 2

                } else {
                    let hasVideoClips = track.clips.contains { $0.assetURL != nil }
                    guard hasVideoClips else { continue }

                    let trackID = CMPersistentTrackID(videoTrackIndex + 1)
                    guard let compositionVideoTrack = comp.addMutableTrack(
                        withMediaType: .video,
                        preferredTrackID: trackID
                    ) else { continue }

                    var insertTime = CMTime.zero

                    for clip in track.clips {
                        guard let url = clip.assetURL else { continue }
                        let asset = AVURLAsset(url: url)

                        guard let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }

                        let sourceStart = CMTime(seconds: clip.trimStart, preferredTimescale: 600)
                        let sourceDuration = CMTime(seconds: clip.effectiveDuration * Double(clip.speed), preferredTimescale: 600)
                        let timeRange = CMTimeRange(start: sourceStart, duration: sourceDuration)

                        try compositionVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: insertTime)

                        if clip.speed != 1.0 {
                            let scaledDuration = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)
                            let scaleRange = CMTimeRange(start: insertTime, duration: sourceDuration)
                            compositionVideoTrack.scaleTimeRange(scaleRange, toDuration: scaledDuration)
                        }

                        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                            if let compositionAudioTrack = comp.addMutableTrack(
                                withMediaType: .audio,
                                preferredTrackID: CMPersistentTrackID(100 + audioTrackIndex)
                            ) {
                                try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: insertTime)
                                if clip.speed != 1.0 {
                                    let scaledDuration = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)
                                    let scaleRange = CMTimeRange(start: insertTime, duration: sourceDuration)
                                    compositionAudioTrack.scaleTimeRange(scaleRange, toDuration: scaledDuration)
                                }

                                let params = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
                                let vol = (track.isMuted || clip.isMuted) ? Float(0) : (clip.volume * track.volume * masterVolume)
                                params.setVolume(vol, at: insertTime)
                                audioMixParams.append(params)
                                audioTrackIndex += 1
                            }
                        }

                        let effectiveInsert = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)
                        insertTime = CMTimeAdd(insertTime, effectiveInsert)
                    }

                    let layerTransform = track.transform ?? .fullFrame
                    let trackEffects = track.clips.flatMap { $0.effects }
                    videoLayerMappings.append((trackID: trackID, transform: layerTransform, opacity: track.opacity, effects: trackEffects))
                    videoTrackIndex += 1
                }

            case .audio:
                for clip in track.clips {
                    guard let url = clip.assetURL else { continue }
                    let asset = AVURLAsset(url: url)

                    var audioSource = try? await asset.loadTracks(withMediaType: .audio).first
                    if audioSource == nil {
                        audioSource = try? await asset.loadTracks(withMediaType: .video).first
                    }
                    guard let assetAudioTrack = audioSource else { continue }

                    if let compositionAudioTrack = comp.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: CMPersistentTrackID(200 + audioTrackIndex)
                    ) {
                        let clipStartCM = CMTime(seconds: clip.trimStart, preferredTimescale: 600)
                        let clipDurationCM = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)
                        let insertTime = CMTime(seconds: clip.startTime, preferredTimescale: 600)

                        try compositionAudioTrack.insertTimeRange(
                            CMTimeRange(start: clipStartCM, duration: clipDurationCM),
                            of: assetAudioTrack,
                            at: insertTime
                        )

                        let params = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
                        let vol = (track.isMuted || clip.isMuted) ? Float(0) : (clip.volume * track.volume * masterVolume)
                        params.setVolume(vol, at: insertTime)
                        audioMixParams.append(params)
                        audioTrackIndex += 1
                    }
                }

            case .text:
                break
            }
        }

        // Build per-clip crop segments from the primary video track.
        var cropSegments: [CropSegment] = []
        for track in tracks where track.type == .video {
            var segmentTime = CMTime.zero
            for clip in track.clips {
                let clipDuration = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)
                let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
                if clip.cropRect != fullFrame {
                    cropSegments.append(CropSegment(
                        timeRange: CMTimeRange(start: segmentTime, duration: clipDuration),
                        cropRect: clip.cropRect
                    ))
                }
                segmentTime = CMTimeAdd(segmentTime, clipDuration)
            }
        }
        // Build per-clip filter segments from the video tracks.
        var filterSegments: [FilterSegment] = []
        for track in tracks where track.type == .video || track.type == .overlay {
            var segmentTime = CMTime.zero
            for clip in track.clips {
                let clipDuration = CMTime(seconds: clip.effectiveDuration, preferredTimescale: 600)

                var brightness: Float = 0, contrast: Float = 0, saturation: Float = 0
                var temperature: Float = 0, sharpness: Float = 0, vignette: Float = 0, fade: Float = 0
                var hasFilter = false

                // Apply filter preset values
                if let filterID = clip.filterID, filterID != "original",
                   let preset = VideoFilter.presets.first(where: { $0.id == filterID }) {
                    brightness = preset.brightness
                    contrast = preset.contrast
                    saturation = preset.saturation
                    temperature = preset.temperature
                    sharpness = preset.sharpness
                    vignette = preset.vignette
                    fade = preset.fade
                    hasFilter = true
                }

                // Override with manual color adjustments if present
                if let adj = clip.colorAdjustments {
                    brightness = adj.brightness
                    contrast = adj.contrast
                    saturation = adj.saturation
                    temperature = adj.temperature
                    sharpness = adj.sharpness
                    vignette = adj.vignette
                    hasFilter = true
                }

                if hasFilter {
                    filterSegments.append(FilterSegment(
                        timeRange: CMTimeRange(start: segmentTime, duration: clipDuration),
                        brightness: brightness, contrast: contrast, saturation: saturation,
                        temperature: temperature, sharpness: sharpness, vignette: vignette, fade: fade
                    ))
                }
                segmentTime = CMTimeAdd(segmentTime, clipDuration)
            }
        }

        let videoComp = buildMultiLayerVideoComposition(
            comp: comp,
            renderSize: renderSize,
            layerMappings: videoLayerMappings,
            cropRect: cropRect,
            cropSegments: cropSegments,
            filterSegments: filterSegments,
            transitions: transitionInfos,
            tracks: tracks,
            stickerOverlays: stickers
        )

        var audioMix: AVMutableAudioMix? = nil
        if !audioMixParams.isEmpty {
            let mix = AVMutableAudioMix()
            mix.inputParameters = audioMixParams
            audioMix = mix
        }

        return (comp, videoComp, audioMix)
    }

    private func buildMultiLayerVideoComposition(
        comp: AVMutableComposition,
        renderSize: CGSize,
        layerMappings: [(trackID: CMPersistentTrackID, transform: VideoTrackTransform, opacity: Float, effects: [ClipEffect])],
        cropRect: CGRect,
        cropSegments: [CropSegment] = [],
        filterSegments: [FilterSegment] = [],
        transitions: [TransitionInfo] = [],
        tracks: [TimelineTrack] = [],
        stickerOverlays: [OverlayStickerInfo] = []
    ) -> AVMutableVideoComposition? {
        guard !layerMappings.isEmpty else { return nil }

        let duration = comp.duration

        var transforms: [CMPersistentTrackID: VideoTrackTransform] = [:]
        var opacities: [CMPersistentTrackID: Float] = [:]
        var effects: [CMPersistentTrackID: [ClipEffect]] = [:]
        var sourceTrackIDs: [CMPersistentTrackID] = []

        for mapping in layerMappings {
            transforms[mapping.trackID] = mapping.transform
            opacities[mapping.trackID] = mapping.opacity
            if !mapping.effects.isEmpty {
                effects[mapping.trackID] = mapping.effects
            }
            sourceTrackIDs.append(mapping.trackID)
        }

        var textOverlays: [(text: TextOverlayData, startTime: Double, endTime: Double)] = []
        for track in tracks where track.type == .text {
            for clip in track.clips {
                if let textData = clip.textOverlay {
                    textOverlays.append((text: textData, startTime: clip.startTime, endTime: clip.endTime))
                }
            }
        }

        let instruction = MultiLayerCompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: duration),
            sourceTrackIDs: sourceTrackIDs,
            layerTransforms: transforms,
            layerOpacities: opacities,
            layerEffects: effects,
            cropRect: cropRect,
            cropSegments: cropSegments,
            filterSegments: filterSegments,
            renderSize: renderSize,
            transitions: transitions,
            textOverlays: textOverlays,
            stickerOverlays: stickerOverlays
        )

        let videoComp = AVMutableVideoComposition()
        videoComp.renderSize = renderSize
        videoComp.frameDuration = CMTime(value: 1, timescale: 30)
        videoComp.instructions = [instruction]
        videoComp.customVideoCompositorClass = MultiLayerVideoCompositor.self

        return videoComp
    }

    private func buildFilterLookup(tracks: [TimelineTrack]) -> (Double) -> VideoFilter? {
        var clipRanges: [(start: Double, end: Double, filter: VideoFilter)] = []
        for track in tracks where track.type == .video || track.type == .overlay {
            for clip in track.clips {
                var filter: VideoFilter?

                if let filterID = clip.filterID, filterID != "original" {
                    filter = VideoFilter.presets.first { $0.id == filterID }
                }

                if let adj = clip.colorAdjustments {
                    if filter == nil {
                        filter = VideoFilter(id: "custom", name: "Custom")
                    }
                    filter?.brightness = adj.brightness
                    filter?.contrast = adj.contrast
                    filter?.saturation = adj.saturation
                    filter?.temperature = adj.temperature
                    filter?.sharpness = adj.sharpness
                    filter?.vignette = adj.vignette
                }

                if let f = filter {
                    clipRanges.append((clip.startTime, clip.endTime, f))
                }
            }
        }

        return { time in
            for range in clipRanges {
                if time >= range.start && time < range.end {
                    return range.filter
                }
            }
            return nil
        }
    }

    private func applyFilter(_ filter: VideoFilter, to image: CIImage, extent: CGRect) -> CIImage {
        var result = image

        if filter.brightness != 0 || filter.contrast != 0 || filter.saturation != 0 {
            let colorControls = CIFilter(name: "CIColorControls")!
            colorControls.setValue(result, forKey: kCIInputImageKey)
            colorControls.setValue(filter.brightness, forKey: kCIInputBrightnessKey)
            colorControls.setValue(1.0 + filter.contrast, forKey: kCIInputContrastKey)
            colorControls.setValue(1.0 + filter.saturation, forKey: kCIInputSaturationKey)
            if let output = colorControls.outputImage {
                result = output
            }
        }

        if filter.temperature != 0 {
            let tempFilter = CIFilter(name: "CITemperatureAndTint")!
            tempFilter.setValue(result, forKey: kCIInputImageKey)
            let neutral = CIVector(x: 6500 + CGFloat(filter.temperature * 3000), y: 0)
            tempFilter.setValue(neutral, forKey: "inputNeutral")
            tempFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
            if let output = tempFilter.outputImage {
                result = output
            }
        }

        if filter.sharpness != 0 {
            let sharp = CIFilter(name: "CISharpenLuminance")!
            sharp.setValue(result, forKey: kCIInputImageKey)
            sharp.setValue(filter.sharpness * 2.0, forKey: kCIInputSharpnessKey)
            if let output = sharp.outputImage {
                result = output
            }
        }

        if filter.vignette != 0 {
            let vig = CIFilter(name: "CIVignette")!
            vig.setValue(result, forKey: kCIInputImageKey)
            vig.setValue(filter.vignette * 3.0, forKey: kCIInputIntensityKey)
            vig.setValue(filter.vignette * 2.0, forKey: kCIInputRadiusKey)
            if let output = vig.outputImage {
                result = output
            }
        }

        if filter.fade > 0 {
            let overlay = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(filter.fade * 0.4)))
                .cropped(to: extent)
            result = overlay.composited(over: result)
        }

        return result
    }

    func buildTextLayers(tracks: [TimelineTrack], renderSize: CGSize, duration: CMTime) -> CALayer? {
        let textClips = tracks.filter { $0.type == .text }.flatMap { $0.clips }.filter { $0.textOverlay != nil }
        guard !textClips.isEmpty else { return nil }

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.isGeometryFlipped = true

        let videoLayer = CALayer()
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        let overlayLayer = CALayer()
        overlayLayer.frame = parentLayer.frame

        for clip in textClips {
            guard let textData = clip.textOverlay else { continue }
            let textLayer = CATextLayer()
            let scaleFactor = renderSize.width / 390.0

            let fontSize = textData.fontSize * scaleFactor
            let font = UIFont(name: textData.fontName, size: fontSize)
                ?? UIFont.boldSystemFont(ofSize: fontSize)

            textLayer.font = font
            textLayer.fontSize = fontSize
            textLayer.string = textData.text
            textLayer.foregroundColor = UIColor(
                red: textData.textColor.red,
                green: textData.textColor.green,
                blue: textData.textColor.blue,
                alpha: textData.textColor.alpha
            ).cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.isWrapped = true

            let textSize = (textData.text as NSString).size(withAttributes: [.font: font])
            let layerWidth = min(textSize.width + 40, renderSize.width - 40)
            let layerHeight = textSize.height + 20

            let posX = textData.position.x * renderSize.width - layerWidth / 2
            let posY = textData.position.y * renderSize.height - layerHeight / 2
            textLayer.frame = CGRect(x: posX, y: posY, width: layerWidth, height: layerHeight)

            if let bgColor = textData.backgroundColor {
                textLayer.backgroundColor = UIColor(
                    red: bgColor.red, green: bgColor.green, blue: bgColor.blue, alpha: bgColor.alpha
                ).cgColor
                textLayer.cornerRadius = 8
            }

            let showTime = clip.startTime
            let hideTime = clip.endTime

            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + showTime
            fadeIn.duration = 0.3
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false
            textLayer.add(fadeIn, forKey: "fadeIn")

            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + hideTime - 0.3
            fadeOut.duration = 0.3
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false
            textLayer.add(fadeOut, forKey: "fadeOut")

            textLayer.opacity = 0

            let initial = CABasicAnimation(keyPath: "opacity")
            initial.fromValue = 0
            initial.toValue = 0
            initial.beginTime = AVCoreAnimationBeginTimeAtZero
            initial.duration = max(0.001, showTime)
            initial.fillMode = .forwards
            initial.isRemovedOnCompletion = false
            textLayer.add(initial, forKey: "initial")

            overlayLayer.addSublayer(textLayer)
        }

        parentLayer.addSublayer(overlayLayer)

        return parentLayer
    }

    func getTotalDuration(for tracks: [TimelineTrack]) -> Double {
        var maxDuration: Double = 0
        for track in tracks {
            var trackEnd: Double = 0
            for clip in track.clips {
                trackEnd = max(trackEnd, clip.endTime)
            }
            maxDuration = max(maxDuration, trackEnd)
        }
        return maxDuration
    }
}
