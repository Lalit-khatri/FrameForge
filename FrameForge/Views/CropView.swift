import SwiftUI

struct CropView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cropFrame: CGRect = .zero
    @State private var dragCorner: CropCorner?
    @State private var dragStart: CGPoint = .zero
    @State private var initialFrame: CGRect = .zero

    enum CropCorner { case topLeft, topRight, bottomLeft, bottomRight, center }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    cropPreview
                    aspectRatioSelector
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.applyCropToSelectedClip()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                }
            }
        }
        .presentationDetents([.large])
    }

    private var cropPreview: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let videoAspect: CGFloat = viewModel.videoAspectRatio
            let videoWidth = min(containerSize.width, containerSize.height * videoAspect)
            let videoHeight = videoWidth / videoAspect
            let videoRect = CGRect(
                x: (containerSize.width - videoWidth) / 2,
                y: (containerSize.height - videoHeight) / 2,
                width: videoWidth,
                height: videoHeight
            )

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: videoWidth, height: videoHeight)
                    .position(x: containerSize.width / 2, y: containerSize.height / 2)

                if let player = viewModel.player {
                    VideoPlayerView(player: player)
                        .frame(width: videoWidth, height: videoHeight)
                        .position(x: containerSize.width / 2, y: containerSize.height / 2)
                        .opacity(0.5)
                }

                let cf = cropFrameInPoints(videoRect: videoRect)

                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(width: cf.width, height: cf.height)
                                    .position(x: cf.midX, y: cf.midY)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .frame(width: videoWidth, height: videoHeight)
                    .position(x: containerSize.width / 2, y: containerSize.height / 2)
                    .allowsHitTesting(false)

                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cf.width, height: cf.height)
                    .position(x: cf.midX, y: cf.midY)

                gridLines(in: cf)

                ForEach(corners(of: cf), id: \.0) { (corner, point) in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .shadow(radius: 3)
                        .position(point)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    handleCornerDrag(corner: corner, location: value.location, videoRect: videoRect)
                                }
                        )
                }

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: cf.width - 36, height: cf.height - 36)
                    .position(x: cf.midX, y: cf.midY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragCorner == nil {
                                    dragCorner = .center
                                    initialFrame = viewModel.cropRect
                                }
                                let dx = value.translation.width / videoRect.width
                                let dy = value.translation.height / videoRect.height
                                var newRect = initialFrame
                                newRect.origin.x = max(0, min(1 - newRect.width, initialFrame.origin.x + dx))
                                newRect.origin.y = max(0, min(1 - newRect.height, initialFrame.origin.y + dy))
                                viewModel.cropRect = newRect
                            }
                            .onEnded { _ in
                                dragCorner = nil
                            }
                    )
            }
            .onAppear {
                if let clip = viewModel.selectedClip {
                    viewModel.cropRect = clip.cropRect
                }
                if viewModel.cropRect == CGRect(x: 0, y: 0, width: 1, height: 1) {
                    cropFrame = videoRect
                }
            }
        }
        .aspectRatio(viewModel.videoAspectRatio, contentMode: .fit)
    }

    private func cropFrameInPoints(videoRect: CGRect) -> CGRect {
        let cr = viewModel.cropRect
        return CGRect(
            x: videoRect.origin.x + cr.origin.x * videoRect.width,
            y: videoRect.origin.y + cr.origin.y * videoRect.height,
            width: cr.width * videoRect.width,
            height: cr.height * videoRect.height
        )
    }

    private func gridLines(in frame: CGRect) -> some View {
        let thirdW = frame.width / 3
        let thirdH = frame.height / 3
        return ZStack {
            ForEach(1..<3, id: \.self) { i in
                Path { p in
                    p.move(to: CGPoint(x: frame.minX + thirdW * CGFloat(i), y: frame.minY))
                    p.addLine(to: CGPoint(x: frame.minX + thirdW * CGFloat(i), y: frame.maxY))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)

                Path { p in
                    p.move(to: CGPoint(x: frame.minX, y: frame.minY + thirdH * CGFloat(i)))
                    p.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + thirdH * CGFloat(i)))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            }
        }
    }

    private func corners(of frame: CGRect) -> [(CropCorner, CGPoint)] {
        [
            (.topLeft, CGPoint(x: frame.minX, y: frame.minY)),
            (.topRight, CGPoint(x: frame.maxX, y: frame.minY)),
            (.bottomLeft, CGPoint(x: frame.minX, y: frame.maxY)),
            (.bottomRight, CGPoint(x: frame.maxX, y: frame.maxY)),
        ]
    }

    private func handleCornerDrag(corner: CropCorner, location: CGPoint, videoRect: CGRect) {
        let nx = (location.x - videoRect.origin.x) / videoRect.width
        let ny = (location.y - videoRect.origin.y) / videoRect.height
        let clampedX = max(0, min(1, nx))
        let clampedY = max(0, min(1, ny))
        var rect = viewModel.cropRect

        let minSize: CGFloat = 0.1

        switch corner {
        case .topLeft:
            let newW = rect.maxX - clampedX
            let newH = rect.maxY - clampedY
            if newW > minSize && newH > minSize {
                rect.origin.x = clampedX
                rect.origin.y = clampedY
                rect.size.width = newW
                rect.size.height = newH
            }
        case .topRight:
            let newW = clampedX - rect.minX
            let newH = rect.maxY - clampedY
            if newW > minSize && newH > minSize {
                rect.origin.y = clampedY
                rect.size.width = newW
                rect.size.height = newH
            }
        case .bottomLeft:
            let newW = rect.maxX - clampedX
            let newH = clampedY - rect.minY
            if newW > minSize && newH > minSize {
                rect.origin.x = clampedX
                rect.size.width = newW
                rect.size.height = newH
            }
        case .bottomRight:
            let newW = clampedX - rect.minX
            let newH = clampedY - rect.minY
            if newW > minSize && newH > minSize {
                rect.size.width = newW
                rect.size.height = newH
            }
        case .center:
            break
        }

        if let ratio = viewModel.cropAspectRatio.ratio {
            let currentRatio = rect.width / rect.height
            if currentRatio > ratio {
                rect.size.width = rect.height * ratio
            } else {
                rect.size.height = rect.width / ratio
            }
        }

        viewModel.cropRect = rect
    }

    private var aspectRatioSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CropAspectRatio.allCases, id: \.self) { ratio in
                    Button(action: {
                        viewModel.cropAspectRatio = ratio
                        if let r = ratio.ratio {
                            var rect = viewModel.cropRect
                            let currentRatio = rect.width / rect.height
                            if currentRatio > r {
                                let newW = rect.height * r
                                rect.origin.x += (rect.width - newW) / 2
                                rect.size.width = newW
                            } else {
                                let newH = rect.width / r
                                rect.origin.y += (rect.height - newH) / 2
                                rect.size.height = newH
                            }
                            viewModel.cropRect = rect
                        } else {
                            viewModel.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                        }
                        HapticManager.shared.selection()
                    }) {
                        Text(ratio.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(viewModel.cropAspectRatio == ratio ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.cropAspectRatio == ratio
                                ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                : Color.white.opacity(0.08)
                            )
                            .cornerRadius(20)
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button(action: {
                viewModel.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                viewModel.cropAspectRatio = .free
                HapticManager.shared.light()
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(24)
            }
        }
    }
}
