import AVFoundation
import CoreImage

struct TransitionInfo {
    let type: String
    let timeRange: CMTimeRange
    let fromTrackID: CMPersistentTrackID
    let toTrackID: CMPersistentTrackID
}

final class MultiLayerCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let enablePostProcessing: Bool = false
    let containsTweening: Bool = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let layerTransforms: [CMPersistentTrackID: VideoTrackTransform]
    let layerFilters: [CMPersistentTrackID: String?]
    let layerOpacities: [CMPersistentTrackID: Float]
    let layerEffects: [CMPersistentTrackID: [ClipEffect]]
    let cropRect: CGRect
    let renderSize: CGSize
    let transitions: [TransitionInfo]

    init(
        timeRange: CMTimeRange,
        sourceTrackIDs: [CMPersistentTrackID],
        layerTransforms: [CMPersistentTrackID: VideoTrackTransform],
        layerFilters: [CMPersistentTrackID: String?] = [:],
        layerOpacities: [CMPersistentTrackID: Float] = [:],
        layerEffects: [CMPersistentTrackID: [ClipEffect]] = [:],
        cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
        renderSize: CGSize,
        transitions: [TransitionInfo] = []
    ) {
        self.timeRange = timeRange
        self.layerTransforms = layerTransforms
        self.layerFilters = layerFilters
        self.layerOpacities = layerOpacities
        self.layerEffects = layerEffects
        self.cropRect = cropRect
        self.renderSize = renderSize
        self.transitions = transitions
        self.requiredSourceTrackIDs = sourceTrackIDs.map { NSNumber(value: $0) }
    }
}

final class MultiLayerVideoCompositor: NSObject, AVVideoCompositing {

    private let renderContext = CIContext(options: [.useSoftwareRenderer: false])
    private let queue = DispatchQueue(label: "com.frameforge.compositor", qos: .userInitiated)

    var sourcePixelBufferAttributes: [String: Any]? {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async { [weak self] in
            self?.processRequest(request)
        }
    }

    private func processRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? MultiLayerCompositionInstruction else {
            request.finish(with: NSError(domain: "MultiLayerCompositor", code: -1))
            return
        }

        let renderSize = instruction.renderSize
        let extent = CGRect(origin: .zero, size: renderSize)
        var composited = CIImage(color: CIColor.black).cropped(to: extent)
        let currentTime = request.compositionTime

        var transitionTrackIDs = Set<CMPersistentTrackID>()
        var transitionResult: CIImage?

        for transition in instruction.transitions {
            if transition.timeRange.containsTime(currentTime) {
                transitionTrackIDs.insert(transition.fromTrackID)
                transitionTrackIDs.insert(transition.toTrackID)

                let elapsed = CMTimeGetSeconds(CMTimeSubtract(currentTime, transition.timeRange.start))
                let totalDur = CMTimeGetSeconds(transition.timeRange.duration)
                let progress = max(0, min(1, elapsed / totalDur))

                let fromBuffer = request.sourceFrame(byTrackID: transition.fromTrackID)
                let toBuffer = request.sourceFrame(byTrackID: transition.toTrackID)

                let fromImage = fromBuffer.map { fitImageToRenderSize(CIImage(cvPixelBuffer: $0), renderSize: renderSize) }
                    ?? CIImage(color: CIColor.black).cropped(to: extent)
                let toImage = toBuffer.map { fitImageToRenderSize(CIImage(cvPixelBuffer: $0), renderSize: renderSize) }
                    ?? CIImage(color: CIColor.black).cropped(to: extent)

                transitionResult = applyTransition(
                    type: transition.type,
                    from: fromImage,
                    to: toImage,
                    progress: progress,
                    renderSize: renderSize
                )
            }
        }

        if let transResult = transitionResult {
            composited = transResult.cropped(to: extent)
        }

        let sortedTrackIDs = instruction.layerTransforms.sorted { $0.value.zIndex < $1.value.zIndex }

        for (trackID, transform) in sortedTrackIDs {
            if transitionTrackIDs.contains(trackID) { continue }
            guard let sourceBuffer = request.sourceFrame(byTrackID: trackID) else { continue }

            var layerImage = CIImage(cvPixelBuffer: sourceBuffer)
            let sourceExtent = layerImage.extent

            let effects = instruction.layerEffects[trackID] ?? []
            if !effects.isEmpty {
                layerImage = applyEffects(effects, to: layerImage)
            }

            let opacity = instruction.layerOpacities[trackID] ?? 1.0
            if opacity < 1.0 {
                layerImage = layerImage.applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
                ])
            }

            if transform.scale >= 0.99 && transform.position.x == 0.5 && transform.position.y == 0.5 && transform.rotation == 0 {
                let scaleX = renderSize.width / sourceExtent.width
                let scaleY = renderSize.height / sourceExtent.height
                let fitScale = min(scaleX, scaleY)
                let scaledW = sourceExtent.width * fitScale
                let scaledH = sourceExtent.height * fitScale
                let offsetX = (renderSize.width - scaledW) / 2
                let offsetY = (renderSize.height - scaledH) / 2

                layerImage = layerImage
                    .transformed(by: CGAffineTransform(scaleX: fitScale, y: fitScale))
                    .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            } else {
                let targetW = renderSize.width * transform.scale
                let targetH = renderSize.height * transform.scale

                let scaleX = targetW / sourceExtent.width
                let scaleY = targetH / sourceExtent.height
                let fitScale = min(scaleX, scaleY)

                let scaledW = sourceExtent.width * fitScale
                let scaledH = sourceExtent.height * fitScale

                let centerX = transform.position.x * renderSize.width
                let centerY = (1 - transform.position.y) * renderSize.height

                let offsetX = centerX - scaledW / 2
                let offsetY = centerY - scaledH / 2

                var t = CGAffineTransform(scaleX: fitScale, y: fitScale)
                t = t.concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))

                if transform.rotation != 0 {
                    let rotCenter = CGAffineTransform(translationX: centerX, y: centerY)
                    let rotBack = CGAffineTransform(translationX: -centerX, y: -centerY)
                    let rot = CGAffineTransform(rotationAngle: CGFloat(transform.rotation * .pi / 180))
                    t = t.concatenating(rotBack).concatenating(rot).concatenating(rotCenter)
                }

                layerImage = layerImage.transformed(by: t)
            }

            layerImage = layerImage.cropped(to: extent)
            composited = layerImage.composited(over: composited)
        }

        let isCropped = instruction.cropRect != CGRect(x: 0, y: 0, width: 1, height: 1)
        if isCropped {
            let cr = instruction.cropRect
            let cropX = cr.origin.x * renderSize.width
            let cropY = (1 - cr.origin.y - cr.height) * renderSize.height
            let cropW = cr.width * renderSize.width
            let cropH = cr.height * renderSize.height
            let cropRegion = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
            composited = composited.cropped(to: cropRegion)
            let sX = renderSize.width / cropW
            let sY = renderSize.height / cropH
            composited = composited
                .transformed(by: CGAffineTransform(translationX: -cropRegion.origin.x, y: -cropRegion.origin.y))
                .transformed(by: CGAffineTransform(scaleX: sX, y: sY))
        }

        composited = composited.cropped(to: extent)

        guard let outputBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "MultiLayerCompositor", code: -2))
            return
        }

        renderContext.render(composited, to: outputBuffer)
        request.finish(withComposedVideoFrame: outputBuffer)
    }

    private func fitImageToRenderSize(_ image: CIImage, renderSize: CGSize) -> CIImage {
        let sourceExtent = image.extent
        let scaleX = renderSize.width / sourceExtent.width
        let scaleY = renderSize.height / sourceExtent.height
        let fitScale = min(scaleX, scaleY)
        let scaledW = sourceExtent.width * fitScale
        let scaledH = sourceExtent.height * fitScale
        let offsetX = (renderSize.width - scaledW) / 2
        let offsetY = (renderSize.height - scaledH) / 2
        return image
            .transformed(by: CGAffineTransform(scaleX: fitScale, y: fitScale))
            .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            .cropped(to: CGRect(origin: .zero, size: renderSize))
    }

    private func applyTransition(type: String, from fromImage: CIImage, to toImage: CIImage, progress: Double, renderSize: CGSize) -> CIImage {
        let extent = CGRect(origin: .zero, size: renderSize)
        let p = CGFloat(progress)

        switch type {
        case "crossfade", "dissolve":
            let fromFaded = fromImage.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1 - p)
            ])
            let toFaded = toImage.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: p)
            ])
            return toFaded.composited(over: fromFaded).cropped(to: extent)

        case "slide-left":
            let fromSlid = fromImage.transformed(by: CGAffineTransform(translationX: -p * renderSize.width, y: 0))
            let toSlid = toImage.transformed(by: CGAffineTransform(translationX: (1 - p) * renderSize.width, y: 0))
            return toSlid.composited(over: fromSlid).cropped(to: extent)

        case "slide-right":
            let fromSlid = fromImage.transformed(by: CGAffineTransform(translationX: p * renderSize.width, y: 0))
            let toSlid = toImage.transformed(by: CGAffineTransform(translationX: -(1 - p) * renderSize.width, y: 0))
            return toSlid.composited(over: fromSlid).cropped(to: extent)

        case "slide-up":
            let fromSlid = fromImage.transformed(by: CGAffineTransform(translationX: 0, y: p * renderSize.height))
            let toSlid = toImage.transformed(by: CGAffineTransform(translationX: 0, y: -(1 - p) * renderSize.height))
            return toSlid.composited(over: fromSlid).cropped(to: extent)

        case "slide-down":
            let fromSlid = fromImage.transformed(by: CGAffineTransform(translationX: 0, y: -p * renderSize.height))
            let toSlid = toImage.transformed(by: CGAffineTransform(translationX: 0, y: (1 - p) * renderSize.height))
            return toSlid.composited(over: fromSlid).cropped(to: extent)

        case "zoom-in":
            let scale = 1 + p * 0.5
            let cx = renderSize.width / 2
            let cy = renderSize.height / 2
            let fromZoomed = fromImage
                .transformed(by: CGAffineTransform(translationX: -cx, y: -cy))
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: cx, y: cy))
                .cropped(to: extent)
            let fromFaded = fromZoomed.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1 - p)
            ])
            let toFaded = toImage.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: p)
            ])
            return toFaded.composited(over: fromFaded).cropped(to: extent)

        case "zoom-out":
            let scale = 1 - p * 0.3
            let cx = renderSize.width / 2
            let cy = renderSize.height / 2
            let fromZoomed = fromImage
                .transformed(by: CGAffineTransform(translationX: -cx, y: -cy))
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: cx, y: cy))
                .cropped(to: extent)
            let fromFaded = fromZoomed.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1 - p)
            ])
            let toFaded = toImage.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: p)
            ])
            return toFaded.composited(over: fromFaded).cropped(to: extent)

        case "wipe-left":
            let wipeX = (1 - p) * renderSize.width
            let fromCropped = fromImage.cropped(to: CGRect(x: wipeX, y: 0, width: renderSize.width - wipeX, height: renderSize.height))
            return fromCropped.composited(over: toImage).cropped(to: extent)

        case "wipe-right":
            let wipeX = p * renderSize.width
            let fromCropped = fromImage.cropped(to: CGRect(x: 0, y: 0, width: renderSize.width - wipeX, height: renderSize.height))
            return fromCropped.composited(over: toImage).cropped(to: extent)

        case "blur":
            let radius = (1 - abs(p * 2 - 1)) * 30.0
            let blendImage = p < 0.5 ? fromImage : toImage
            return blendImage.applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: radius
            ]).cropped(to: extent)

        case "flash":
            let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: extent)
            let flashIntensity = 1 - abs(p * 2 - 1)
            let blendImage = p < 0.5 ? fromImage : toImage
            let whiteOverlay = white.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: flashIntensity)
            ])
            return whiteOverlay.composited(over: blendImage).cropped(to: extent)

        case "spin":
            let angle = p * .pi * 2
            let cx = renderSize.width / 2
            let cy = renderSize.height / 2
            let fromRotated = fromImage
                .transformed(by: CGAffineTransform(translationX: -cx, y: -cy))
                .transformed(by: CGAffineTransform(rotationAngle: angle))
                .transformed(by: CGAffineTransform(translationX: cx, y: cy))
                .cropped(to: extent)
            let fromFaded = fromRotated.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1 - p)
            ])
            let toFaded = toImage.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: p)
            ])
            return toFaded.composited(over: fromFaded).cropped(to: extent)

        case "glitch":
            let offset = (1 - abs(p * 2 - 1)) * 20.0
            let blendImage = p < 0.5 ? fromImage : toImage
            let r = blendImage.applyingFilter("CIColorMatrix", parameters: [
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ]).transformed(by: CGAffineTransform(translationX: offset, y: 0))
            let gb = blendImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ]).transformed(by: CGAffineTransform(translationX: -offset, y: 0))
            return r.applyingFilter("CIAdditionCompositing", parameters: [
                kCIInputBackgroundImageKey: gb
            ]).cropped(to: extent)

        default:
            let fromFaded = fromImage.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1 - p)
            ])
            let toFaded = toImage.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: p)
            ])
            return toFaded.composited(over: fromFaded).cropped(to: extent)
        }
    }

    private func applyEffects(_ effects: [ClipEffect], to image: CIImage) -> CIImage {
        var result = image
        let extent = image.extent

        for effect in effects {
            let intensity = CGFloat(effect.intensity)

            switch effect.type {
            case .blur:
                let radius = intensity * 20.0
                result = result.applyingFilter("CIGaussianBlur", parameters: [
                    kCIInputRadiusKey: radius
                ]).cropped(to: extent)

            case .vignette:
                result = result.applyingFilter("CIVignette", parameters: [
                    kCIInputIntensityKey: intensity * 2.0,
                    kCIInputRadiusKey: intensity * 3.0
                ])

            case .grain:
                let noiseImage = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
                    .cropped(to: extent)
                let noise = noiseImage.applyingFilter("CIRandomGenerator")
                    .cropped(to: extent)
                    .applyingFilter("CIColorMatrix", parameters: [
                        "inputRVector": CIVector(x: CGFloat(intensity * 0.1), y: 0, z: 0, w: 0),
                        "inputGVector": CIVector(x: 0, y: CGFloat(intensity * 0.1), z: 0, w: 0),
                        "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(intensity * 0.1), w: 0),
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity * 0.15)),
                        "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                    ])
                result = noise.composited(over: result)

            case .glow:
                let bloom = result.applyingFilter("CIBloom", parameters: [
                    kCIInputRadiusKey: intensity * 15.0,
                    kCIInputIntensityKey: intensity
                ])
                result = bloom.cropped(to: extent)

            case .sharpen:
                result = result.applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: intensity * 2.0
                ])

            case .pixelate:
                let scale = max(2.0, intensity * 30.0)
                result = result.applyingFilter("CIPixellate", parameters: [
                    kCIInputScaleKey: scale,
                    "inputCenter": CIVector(x: extent.midX, y: extent.midY)
                ]).cropped(to: extent)

            case .mirror:
                let mirrorTransform = CGAffineTransform(scaleX: -1, y: 1)
                    .concatenating(CGAffineTransform(translationX: extent.width, y: 0))
                result = result.transformed(by: mirrorTransform)

            case .glitch:
                let offset = intensity * 15.0
                let r = result.applyingFilter("CIColorMatrix", parameters: [
                    "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ]).transformed(by: CGAffineTransform(translationX: offset, y: 0))
                let gb = result.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ]).transformed(by: CGAffineTransform(translationX: -offset, y: 0))
                result = r.applyingFilter("CIAdditionCompositing", parameters: [
                    kCIInputBackgroundImageKey: gb
                ]).cropped(to: extent)

            case .reverse:
                break

            case .rotate:
                let angle = intensity * .pi / 2
                let center = CGAffineTransform(translationX: extent.midX, y: extent.midY)
                let back = CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
                let rot = CGAffineTransform(rotationAngle: angle)
                result = result.transformed(by: back.concatenating(rot).concatenating(center))
                    .cropped(to: extent)

            case .flip:
                let flipTransform = CGAffineTransform(scaleX: 1, y: -1)
                    .concatenating(CGAffineTransform(translationX: 0, y: extent.height))
                result = result.transformed(by: flipTransform)

            case .border:
                let borderWidth = intensity * 20.0
                let borderColor = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
                let borderImage = CIImage(color: borderColor).cropped(to: extent)
                let innerRect = extent.insetBy(dx: borderWidth, dy: borderWidth)
                let mask = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: innerRect)
                let fullMask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: extent)
                let invertedMask = mask.composited(over: fullMask)
                let borderFrame = borderImage.applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputBackgroundImageKey: CIImage(color: CIColor.clear).cropped(to: extent),
                    kCIInputMaskImageKey: invertedMask
                ])
                result = borderFrame.composited(over: result)

            case .opacity:
                let alpha = max(0, min(1, intensity))
                result = result.applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(alpha))
                ])

            case .denoise:
                result = result.applyingFilter("CINoiseReduction", parameters: [
                    "inputNoiseLevel": intensity * 0.05,
                    "inputSharpness": 0.4
                ])

            case .mosaic:
                let scale = max(5.0, intensity * 50.0)
                result = result.applyingFilter("CIPixellate", parameters: [
                    kCIInputScaleKey: scale,
                    "inputCenter": CIVector(x: extent.midX, y: extent.midY)
                ]).cropped(to: extent)
            }
        }

        return result
    }

    func cancelAllPendingVideoCompositionRequests() {}
}
