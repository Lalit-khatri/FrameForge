import SwiftUI

struct SplitScreenView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLayout: SplitLayout = .halfHorizontal

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    layoutPreview

                    Text("Select Layout")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(SplitLayout.allCases, id: \.self) { layout in
                            Button(action: {
                                selectedLayout = layout
                                HapticManager.shared.light()
                            }) {
                                VStack(spacing: 6) {
                                    layout.preview
                                        .frame(width: 60, height: 40)
                                    Text(layout.label)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(selectedLayout == layout ? .white : .gray)
                                }
                                .padding(8)
                                .background(
                                    selectedLayout == layout
                                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                        : Color.white.opacity(0.06)
                                )
                                .cornerRadius(10)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Split Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applySplitScreen()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var layoutPreview: some View {
        selectedLayout.preview
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func applySplitScreen() {
        viewModel.saveState()

        // Ensure we have at least 2 video tracks (create second if missing)
        let videoIndices = viewModel.tracks.indices.filter { viewModel.tracks[$0].type == .video }
        guard videoIndices.count >= 1 else {
            HapticManager.shared.warning()
            return
        }

        // If only 1 video track, create a second by duplicating its structure
        if videoIndices.count < 2 {
            viewModel.addVideoTrack()
        }

        // Re-query after potential insertion
        let vIndices = viewModel.tracks.indices.filter { viewModel.tracks[$0].type == .video }
        guard vIndices.count >= 2 else { return }

        let i0 = vIndices[0]  // first video track
        let i1 = vIndices[1]  // second video track

        // Assign transform per layout
        switch selectedLayout {
        case .halfHorizontal:
            // Top half / Bottom half
            viewModel.updateTrackPosition(trackIndex: i0, position: CGPoint(x: 0.5, y: 0.25))
            viewModel.updateTrackScale(trackIndex: i0, scale: 1.0)
            viewModel.updateTrackPosition(trackIndex: i1, position: CGPoint(x: 0.5, y: 0.75))
            viewModel.updateTrackScale(trackIndex: i1, scale: 1.0)

        case .halfVertical:
            // Left half / Right half
            viewModel.updateTrackPosition(trackIndex: i0, position: CGPoint(x: 0.25, y: 0.5))
            viewModel.updateTrackScale(trackIndex: i0, scale: 0.5)
            viewModel.updateTrackPosition(trackIndex: i1, position: CGPoint(x: 0.75, y: 0.5))
            viewModel.updateTrackScale(trackIndex: i1, scale: 0.5)

        case .thirds:
            // Add third track if needed
            if vIndices.count < 3 { viewModel.addVideoTrack() }
            let v3 = viewModel.tracks.indices.filter { viewModel.tracks[$0].type == .video }
            if v3.count >= 3 {
                viewModel.updateTrackPosition(trackIndex: v3[0], position: CGPoint(x: 0.17, y: 0.5))
                viewModel.updateTrackScale(trackIndex: v3[0], scale: 0.33)
                viewModel.updateTrackPosition(trackIndex: v3[1], position: CGPoint(x: 0.5, y: 0.5))
                viewModel.updateTrackScale(trackIndex: v3[1], scale: 0.33)
                viewModel.updateTrackPosition(trackIndex: v3[2], position: CGPoint(x: 0.83, y: 0.5))
                viewModel.updateTrackScale(trackIndex: v3[2], scale: 0.33)
            }

        case .quadrant:
            // Add tracks 3 and 4 if needed
            while viewModel.tracks.filter({ $0.type == .video }).count < 4 { viewModel.addVideoTrack() }
            let v4 = viewModel.tracks.indices.filter { viewModel.tracks[$0].type == .video }
            if v4.count >= 4 {
                viewModel.updateTrackPosition(trackIndex: v4[0], position: CGPoint(x: 0.25, y: 0.25)); viewModel.updateTrackScale(trackIndex: v4[0], scale: 0.5)
                viewModel.updateTrackPosition(trackIndex: v4[1], position: CGPoint(x: 0.75, y: 0.25)); viewModel.updateTrackScale(trackIndex: v4[1], scale: 0.5)
                viewModel.updateTrackPosition(trackIndex: v4[2], position: CGPoint(x: 0.25, y: 0.75)); viewModel.updateTrackScale(trackIndex: v4[2], scale: 0.5)
                viewModel.updateTrackPosition(trackIndex: v4[3], position: CGPoint(x: 0.75, y: 0.75)); viewModel.updateTrackScale(trackIndex: v4[3], scale: 0.5)
            }

        case .pipOverlay:
            // Full frame primary, small overlay in bottom-right
            viewModel.updateTrackPosition(trackIndex: i0, position: CGPoint(x: 0.5, y: 0.5))
            viewModel.updateTrackScale(trackIndex: i0, scale: 1.0)
            viewModel.updateTrackPosition(trackIndex: i1, position: CGPoint(x: 0.8, y: 0.78))
            viewModel.updateTrackScale(trackIndex: i1, scale: 0.3)

        case .diagonal:
            // Left-top / right-bottom diagonal split (scale 0.5, diagonal crop)
            viewModel.updateTrackPosition(trackIndex: i0, position: CGPoint(x: 0.25, y: 0.25))
            viewModel.updateTrackScale(trackIndex: i0, scale: 0.5)
            viewModel.updateTrackPosition(trackIndex: i1, position: CGPoint(x: 0.75, y: 0.75))
            viewModel.updateTrackScale(trackIndex: i1, scale: 0.5)
        }

        HapticManager.shared.success()
        viewModel.showToast(icon: "rectangle.split.2x2", text: "\(selectedLayout.label) split applied")
    }
}

enum SplitLayout: String, CaseIterable {
    case halfHorizontal, halfVertical, thirds
    case quadrant, pipOverlay, diagonal

    var label: String {
        switch self {
        case .halfHorizontal: return "50/50 H"
        case .halfVertical: return "50/50 V"
        case .thirds: return "Thirds"
        case .quadrant: return "Quadrant"
        case .pipOverlay: return "PiP"
        case .diagonal: return "Diagonal"
        }
    }

    var preview: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                switch self {
                case .halfHorizontal:
                    VStack(spacing: 2) {
                        Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                        Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                    }
                case .halfVertical:
                    HStack(spacing: 2) {
                        Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                        Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                    }
                case .thirds:
                    HStack(spacing: 2) {
                        Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                        Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                        Color.green.opacity(0.5)
                    }
                case .quadrant:
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                            Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                        }
                        HStack(spacing: 2) {
                            Color.green.opacity(0.5)
                            Color.orange.opacity(0.5)
                        }
                    }
                case .pipOverlay:
                    ZStack(alignment: .bottomTrailing) {
                        Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.5)
                        Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.8)
                            .frame(width: w * 0.35, height: h * 0.35)
                            .cornerRadius(4)
                            .padding(4)
                    }
                case .diagonal:
                    Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                        .overlay(
                            Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                                .clipShape(Triangle())
                        )
                }
            }
            .cornerRadius(4)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
