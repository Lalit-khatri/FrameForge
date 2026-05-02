import AVFoundation
import Photos
import UIKit

final class ExportPipeline {
    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?

    @MainActor
    func export(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?,
        audioMix: AVMutableAudioMix?,
        settings: ExportSettings,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrameForge_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        let presetName: String
        switch settings.codec {
        case .h264:
            presetName = AVAssetExportPresetHighestQuality
        case .h265:
            presetName = AVAssetExportPresetHEVCHighestQuality
        case .proRes:
            presetName = AVAssetExportPresetAppleProRes422LPCM
        }

        guard let session = AVAssetExportSession(asset: composition, presetName: presetName) else {
            throw ExportError.sessionCreationFailed
        }

        if let videoComp = videoComposition {
            let baseSize = videoComp.renderSize
            let scale = settings.resolution.multiplier
            let exportWidth = round(baseSize.width * scale / 2) * 2
            let exportHeight = round(baseSize.height * scale / 2) * 2
            let exportSize = CGSize(width: exportWidth, height: exportHeight)
            videoComp.renderSize = exportSize
            videoComp.frameDuration = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate))

            let updatedInstructions = videoComp.instructions.compactMap { instruction -> AVVideoCompositionInstructionProtocol? in
                guard let multiInstruction = instruction as? MultiLayerCompositionInstruction else {
                    return instruction
                }
                return MultiLayerCompositionInstruction(
                    timeRange: multiInstruction.timeRange,
                    sourceTrackIDs: (multiInstruction.requiredSourceTrackIDs as? [NSNumber])?.map { CMPersistentTrackID($0.int32Value) } ?? [],
                    layerTransforms: multiInstruction.layerTransforms,
                    layerFilters: multiInstruction.layerFilters,
                    layerOpacities: multiInstruction.layerOpacities,
                    layerEffects: multiInstruction.layerEffects,
                    cropRect: multiInstruction.cropRect,
                    renderSize: exportSize,
                    transitions: multiInstruction.transitions,
                    textOverlays: multiInstruction.textOverlays,
                    stickerOverlays: multiInstruction.stickerOverlays
                )
            }
            videoComp.instructions = updatedInstructions
        }

        session.outputURL = outputURL
        session.outputFileType = settings.codec == .proRes ? .mov : .mp4
        session.shouldOptimizeForNetworkUse = true
        session.videoComposition = videoComposition
        if settings.includeAudio {
            session.audioMix = audioMix
        } else {
            session.audioMix = nil
        }

        exportSession = session

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak session] _ in
            guard let s = session else { return }
            let p = s.progress
            DispatchQueue.main.async {
                progressHandler(p)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer

        await session.export()
        timer.invalidate()
        progressTimer = nil

        switch session.status {
        case .completed:
            progressHandler(1.0)
            return outputURL
        case .cancelled:
            throw ExportError.cancelled
        case .failed:
            throw session.error ?? ExportError.unknown
        default:
            throw ExportError.unknown
        }
    }

    func saveToPhotoLibrary(_ url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        }
    }

    func cancel() {
        progressTimer?.invalidate()
        progressTimer = nil
        exportSession?.cancelExport()
    }
}

enum ExportError: LocalizedError {
    case sessionCreationFailed
    case cancelled
    case unknown
    case insufficientDiskSpace

    var errorDescription: String? {
        switch self {
        case .sessionCreationFailed: return "Failed to create export session"
        case .cancelled: return "Export was cancelled"
        case .unknown: return "An unknown error occurred during export"
        case .insufficientDiskSpace: return "Not enough disk space to export"
        }
    }
}
