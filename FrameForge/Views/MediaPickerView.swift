import SwiftUI
import PhotosUI
import AVFoundation

struct MediaPickerView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var importedCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 10,
                        matching: .any(of: [.videos, .images]),
                        photoLibrary: .shared()
                    ) {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                                 Color(red: 0.99, green: 0.32, blue: 0.56)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            Text("Select from Library")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Videos & Photos")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }

                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                                .scaleEffect(1.2)
                            Text("Importing \(importedCount) item(s)...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await importItems(items) }
            }
        }
    }

    private func importItems(_ items: [PhotosPickerItem]) async {
        isLoading = true
        importedCount = items.count

        for item in items {
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                await viewModel.addMediaFromURL(movie.url)
            } else if let imageData = try? await item.loadTransferable(type: Data.self) {
                await handleImageImport(imageData)
            }
        }

        selectedItems = []
        isLoading = false
        dismiss()
    }

    private func handleImageImport(_ data: Data) async {
        guard let uiImage = UIImage(data: data) else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "FrameForge_img_\(UUID().uuidString).mp4"
        let outputURL = tempDir.appendingPathComponent(fileName)

        let size = CGSize(
            width: min(uiImage.size.width, 1920),
            height: min(uiImage.size.height, 1080)
        )

        do {
            try await createVideoFromImage(uiImage, size: size, duration: 5.0, outputURL: outputURL)
            await viewModel.addMediaFromURL(outputURL)
        } catch {
            print("Image to video conversion failed: \(error)")
        }
    }

    private func createVideoFromImage(_ image: UIImage, size: CGSize, duration: Double, outputURL: URL) async throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        guard let pixelBuffer = pixelBufferFromImage(image, size: size) else {
            throw NSError(domain: "FrameForge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"])
        }

        let frameDuration = CMTime(value: 1, timescale: 30)
        let totalFrames = Int(duration * 30)

        for frame in 0..<totalFrames {
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frame))
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }

        writerInput.markAsFinished()
        await writer.finishWriting()
    }

    private func pixelBufferFromImage(_ image: UIImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width), Int(size.height),
            kCVPixelFormatType_32ARGB, attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        if let cgImage = image.cgImage {
            context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
}

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "FrameForge_\(UUID().uuidString).\(received.file.pathExtension)"
            let destination = tempDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}
