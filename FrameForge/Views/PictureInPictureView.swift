import SwiftUI

struct PictureInPictureView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pipPosition: PiPPosition = .bottomRight
    @State private var pipScale: CGFloat = 0.3
    @State private var pipCornerRadius: CGFloat = 12
    @State private var showBorder = true
    @State private var borderColor: Color = .white

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    pipPreview

                    positionSelector

                    scaleControl

                    cornerRadiusControl

                    borderToggle

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Picture in Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyPiP()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var pipPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .frame(height: 180)
                .overlay(
                    Text("Main Video")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.4))
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 180
                let pipW = w * pipScale
                let pipH = h * pipScale
                let offset = pipOffset(w: w, h: h, pipW: pipW, pipH: pipH)

                RoundedRectangle(cornerRadius: pipCornerRadius)
                    .fill(Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.6))
                    .frame(width: pipW, height: pipH)
                    .overlay(
                        RoundedRectangle(cornerRadius: pipCornerRadius)
                            .stroke(showBorder ? borderColor : .clear, lineWidth: 2)
                    )
                    .overlay(
                        Text("PiP")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    )
                    .offset(x: offset.x, y: offset.y)
            }
            .frame(height: 180)
        }
    }

    private var positionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Position")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(PiPPosition.allCases, id: \.self) { pos in
                    Button(action: {
                        pipPosition = pos
                        HapticManager.shared.light()
                    }) {
                        Text(pos.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(pipPosition == pos ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                pipPosition == pos
                                    ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                    : Color.white.opacity(0.08)
                            )
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var scaleControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Size")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(pipScale * 100))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: $pipScale, in: 0.15...0.5)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
    }

    private var cornerRadiusControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Corner Radius")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(pipCornerRadius))pt")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Slider(value: $pipCornerRadius, in: 0...30)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
    }

    private var borderToggle: some View {
        Toggle(isOn: $showBorder) {
            HStack(spacing: 8) {
                Image(systemName: "square.dashed")
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                Text("Show Border")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
        }
        .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
    }

    private func pipOffset(w: CGFloat, h: CGFloat, pipW: CGFloat, pipH: CGFloat) -> CGPoint {
        let padding: CGFloat = 8
        switch pipPosition {
        case .topLeft: return CGPoint(x: -(w - pipW) / 2 + padding, y: -(h - pipH) / 2 + padding)
        case .topCenter: return CGPoint(x: 0, y: -(h - pipH) / 2 + padding)
        case .topRight: return CGPoint(x: (w - pipW) / 2 - padding, y: -(h - pipH) / 2 + padding)
        case .centerLeft: return CGPoint(x: -(w - pipW) / 2 + padding, y: 0)
        case .center: return .zero
        case .centerRight: return CGPoint(x: (w - pipW) / 2 - padding, y: 0)
        case .bottomLeft: return CGPoint(x: -(w - pipW) / 2 + padding, y: (h - pipH) / 2 - padding)
        case .bottomCenter: return CGPoint(x: 0, y: (h - pipH) / 2 - padding)
        case .bottomRight: return CGPoint(x: (w - pipW) / 2 - padding, y: (h - pipH) / 2 - padding)
        }
    }

    private func applyPiP() {
        guard let clipID = viewModel.selectedClipID else { return }
        guard let (ti, ci) = viewModel.findClipIndices(clipID) else { return }
        viewModel.tracks[ti].clips[ci].pipPosition = pipPosition.rawValue
        viewModel.tracks[ti].clips[ci].pipScale = Float(pipScale)
        HapticManager.shared.success()
    }
}

enum PiPPosition: String, CaseIterable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight

    var label: String {
        switch self {
        case .topLeft: return "↖ TL"
        case .topCenter: return "↑ TC"
        case .topRight: return "↗ TR"
        case .centerLeft: return "← CL"
        case .center: return "● C"
        case .centerRight: return "→ CR"
        case .bottomLeft: return "↙ BL"
        case .bottomCenter: return "↓ BC"
        case .bottomRight: return "↘ BR"
        }
    }
}
