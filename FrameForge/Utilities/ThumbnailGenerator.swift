import AVFoundation
import UIKit

final class ThumbnailGenerator {
    private var cache: [String: UIImage] = [:]
    private let maxCacheSize = 200

    func generateThumbnail(for url: URL, at time: Double, size: CGSize) async -> UIImage? {
        let cacheKey = "\(url.lastPathComponent)_\(time)_\(Int(size.width))"
        if let cached = cache[cacheKey] { return cached }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)

        do {
            let (cgImage, _) = try await generator.image(at: cmTime)
            let image = UIImage(cgImage: cgImage)
            if cache.count >= maxCacheSize {
                cache.removeAll()
            }
            cache[cacheKey] = image
            return image
        } catch {
            return nil
        }
    }

    func generateThumbnailStrip(for url: URL, count: Int, size: CGSize) async -> [UIImage] {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return [] }

        let totalSeconds = CMTimeGetSeconds(duration)
        guard totalSeconds > 0 else { return [] }

        let interval = totalSeconds / Double(count)
        var images: [UIImage] = []

        for i in 0..<count {
            let time = Double(i) * interval
            if let image = await generateThumbnail(for: url, at: time, size: size) {
                images.append(image)
            }
        }
        return images
    }

    func clearCache() {
        cache.removeAll()
    }
}
