import Foundation
import AVFoundation
import Speech

struct CaptionSegment: Identifiable {
    let id = UUID()
    var text: String
    var startTime: Double
    var endTime: Double
}

@Observable
final class CaptionEngine {
    var progress: Double = 0
    var statusMessage = "Preparing…"
    var isProcessing = false
    var segments: [CaptionSegment] = []
    var error: String?

    private let recognizer: SFSpeechRecognizer?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func generateCaptions(from tracks: [TimelineTrack]) async {
        isProcessing = true
        progress = 0
        error = nil
        segments = []
        statusMessage = "Extracting audio from video…"

        do {
            let audioURL = try await extractVideoAudio(from: tracks)

            statusMessage = "Transcribing speech…"
            progress = 0.3

            let rawSegments = try await transcribe(audioURL: audioURL)

            statusMessage = "Grouping captions…"
            progress = 0.8

            segments = groupIntoSegments(rawSegments, wordsPerGroup: 4)
            progress = 1.0
            statusMessage = "Done!"

            try? FileManager.default.removeItem(at: audioURL)
        } catch {
            self.error = error.localizedDescription
        }

        isProcessing = false
    }

    private func extractVideoAudio(from tracks: [TimelineTrack]) async throws -> URL {
        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw CaptionError.noAudioTrack
        }

        var hasAudio = false

        for track in tracks where track.type == .video {
            for clip in track.clips {
                guard let url = clip.assetURL else { continue }
                let asset = AVURLAsset(url: url)
                guard let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first else { continue }

                let duration = try await asset.load(.duration)
                let trimStart = CMTime(seconds: clip.trimStart, preferredTimescale: 600)
                let trimEnd = CMTime(seconds: clip.trimEnd, preferredTimescale: 600)
                let clipDuration = CMTimeSubtract(CMTimeSubtract(duration, trimStart), trimEnd)
                let insertTime = CMTime(seconds: clip.startTime, preferredTimescale: 600)

                try audioTrack.insertTimeRange(
                    CMTimeRange(start: trimStart, duration: clipDuration),
                    of: sourceAudio,
                    at: insertTime
                )
                hasAudio = true
            }
        }

        guard hasAudio else { throw CaptionError.noAudioTrack }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("caption_audio_\(UUID().uuidString).wav")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw CaptionError.exportFailed
        }

        exportSession.outputFileType = .wav
        exportSession.outputURL = outputURL

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw CaptionError.exportFailed
        }

        return outputURL
    }

    private func transcribe(audioURL: URL) async throws -> [(word: String, start: Double, end: Double)] {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw CaptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result = result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }

        var words: [(word: String, start: Double, end: Double)] = []
        for segment in result.bestTranscription.segments {
            words.append((
                word: segment.substring,
                start: segment.timestamp,
                end: segment.timestamp + segment.duration
            ))
        }

        progress = 0.7
        return words
    }

    private func groupIntoSegments(
        _ words: [(word: String, start: Double, end: Double)],
        wordsPerGroup: Int
    ) -> [CaptionSegment] {
        guard !words.isEmpty else { return [] }

        var segments: [CaptionSegment] = []
        var i = 0

        while i < words.count {
            let end = min(i + wordsPerGroup, words.count)
            let group = words[i..<end]

            let text = group.map(\.word).joined(separator: " ")
            let startTime = group.first!.start
            let endTime = group.last!.end

            let paddedEnd = (end < words.count) ? words[end].start : endTime + 0.3

            segments.append(CaptionSegment(
                text: text,
                startTime: startTime,
                endTime: paddedEnd
            ))

            i = end
        }

        return segments
    }
}

enum CaptionError: LocalizedError {
    case noAudioTrack
    case exportFailed
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "No audio found in video tracks. Add a video with audio to generate captions."
        case .exportFailed: return "Failed to extract audio from video."
        case .recognizerUnavailable: return "Speech recognition is not available on this device."
        }
    }
}
