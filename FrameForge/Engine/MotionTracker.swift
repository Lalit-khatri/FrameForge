import Foundation
import AVFoundation
import Vision
import CoreImage
import UIKit

struct TrackingPoint: Identifiable, Codable {
    let id: UUID
    var time: Double
    var normalizedCenter: CGPoint
    var normalizedSize: CGSize

    init(time: Double, center: CGPoint, size: CGSize) {
        self.id = UUID()
        self.time = time
        self.normalizedCenter = center
        self.normalizedSize = size
    }
}

struct MotionTrackData: Codable {
    var points: [TrackingPoint]
    var isActive: Bool

    init() {
        self.points = []
        self.isActive = false
    }

    func interpolatedCenter(at time: Double) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sorted = points.sorted { $0.time < $1.time }
        if time <= sorted.first!.time { return sorted.first!.normalizedCenter }
        if time >= sorted.last!.time { return sorted.last!.normalizedCenter }

        for i in 0..<sorted.count - 1 {
            let a = sorted[i]
            let b = sorted[i + 1]
            if time >= a.time && time <= b.time {
                let t = CGFloat((time - a.time) / max(0.001, b.time - a.time))
                return CGPoint(
                    x: a.normalizedCenter.x + (b.normalizedCenter.x - a.normalizedCenter.x) * t,
                    y: a.normalizedCenter.y + (b.normalizedCenter.y - a.normalizedCenter.y) * t
                )
            }
        }
        return sorted.last!.normalizedCenter
    }
}

@Observable
final class MotionTracker {
    var trackingPoints: [TrackingPoint] = []
    var isTracking = false
    var progress: Float = 0
    var errorMessage: String?

    func trackObject(in asset: AVAsset, region: CGRect) async {
        isTracking = true
        progress = 0
        trackingPoints = []
        errorMessage = nil

        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            errorMessage = "No video track found"
            isTracking = false
            return
        }

        let duration = try? await asset.load(.duration)
        guard let totalDuration = duration else {
            errorMessage = "Could not load duration"
            isTracking = false
            return
        }

        let totalSeconds = CMTimeGetSeconds(totalDuration)
        let fps: Double = 10
        let frameCount = Int(totalSeconds * fps)
        guard frameCount > 0 else {
            errorMessage = "Video too short"
            isTracking = false
            return
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
        generator.maximumSize = CGSize(width: 640, height: 640)

        let observation = VNDetectedObjectObservation(boundingBox: region)
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = VNRequestTrackingLevel.fast

        let sequenceHandler = VNSequenceRequestHandler()

        for i in 0..<frameCount {
            if !isTracking { break }

            let time = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)

            do {
                let (cgImage, _) = try await generator.image(at: time)
                try sequenceHandler.perform([request], on: cgImage, orientation: .up)

                if let result = request.results?.first as? VNDetectedObjectObservation {
                    let box = result.boundingBox
                    let point = TrackingPoint(
                        time: Double(i) / fps,
                        center: CGPoint(x: box.midX, y: 1 - box.midY),
                        size: CGSize(width: box.width, height: box.height)
                    )
                    trackingPoints.append(point)

                    let newObservation = VNDetectedObjectObservation(boundingBox: result.boundingBox)
                    request.inputObservation = newObservation
                }
            } catch {
                continue
            }

            progress = Float(i + 1) / Float(frameCount)
        }

        isTracking = false
        progress = 1.0
    }

    func cancel() {
        isTracking = false
    }

    func toTrackData() -> MotionTrackData {
        var data = MotionTrackData()
        data.points = trackingPoints
        data.isActive = !trackingPoints.isEmpty
        return data
    }
}
