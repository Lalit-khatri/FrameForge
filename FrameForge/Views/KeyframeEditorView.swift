import SwiftUI

struct KeyframeEditorView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKeyframeID: UUID?
    @State private var selectedProperty: KeyframeProperty = .position

    enum KeyframeProperty: String, CaseIterable {
        case position = "Position"
        case scale = "Scale"
        case rotation = "Rotation"
        case opacity = "Opacity"

        var icon: String {
            switch self {
            case .position: return "arrow.up.and.down.and.arrow.left.and.right"
            case .scale: return "arrow.up.left.and.arrow.down.right"
            case .rotation: return "rotate.right"
            case .opacity: return "circle.lefthalf.filled"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let clip = viewModel.selectedClip {
                    VStack(spacing: 0) {
                        propertyPicker
                        keyframeTimeline(clip: clip)
                        propertyControls(clip: clip)
                        easingPicker
                        actionButtons
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "diamond")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Select a clip to animate")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Keyframes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.visible)
    }

    private var propertyPicker: some View {
        HStack(spacing: 8) {
            ForEach(KeyframeProperty.allCases, id: \.self) { prop in
                Button(action: { selectedProperty = prop }) {
                    VStack(spacing: 4) {
                        Image(systemName: prop.icon)
                            .font(.caption)
                        Text(prop.rawValue)
                            .font(.system(size: 9, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedProperty == prop
                        ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.3)
                        : Color.white.opacity(0.05)
                    )
                    .foregroundColor(selectedProperty == prop ? .white : .gray)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func keyframeTimeline(clip: TimelineClip) -> some View {
        let animation = clip.keyframeAnimation ?? KeyframeAnimation()
        let kfs = animation.keyframes.sorted { $0.time < $1.time }

        return VStack(spacing: 4) {
            Text("TIMELINE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.05))

                    let clipDuration = max(0.1, clip.effectiveDuration)
                    ForEach(kfs) { kf in
                        let x = (kf.time / clipDuration) * geo.size.width
                        Diamond()
                            .fill(selectedKeyframeID == kf.id
                                  ? Color(red: 0.99, green: 0.32, blue: 0.56)
                                  : Color(red: 0.42, green: 0.36, blue: 0.91))
                            .frame(width: 14, height: 14)
                            .position(x: max(7, min(geo.size.width - 7, x)), y: geo.size.height / 2)
                            .onTapGesture { selectedKeyframeID = kf.id }
                    }

                    let playX = (viewModel.currentTime / max(0.1, clip.effectiveDuration)) * geo.size.width
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1.5)
                        .position(x: max(0, min(geo.size.width, playX)), y: geo.size.height / 2)
                }
            }
            .frame(height: 36)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func propertyControls(clip: TimelineClip) -> some View {
        let animation = clip.keyframeAnimation ?? KeyframeAnimation()
        let current = animation.interpolated(at: viewModel.currentTime - clip.startTime)
            ?? Keyframe(time: 0)

        return VStack(spacing: 12) {
            switch selectedProperty {
            case .position:
                sliderRow(title: "X", value: current.positionX, range: 0...1) { val in
                    updateKeyframeProperty { $0.positionX = val }
                }
                sliderRow(title: "Y", value: current.positionY, range: 0...1) { val in
                    updateKeyframeProperty { $0.positionY = val }
                }
            case .scale:
                sliderRow(title: "Scale", value: current.scale, range: 0.1...3.0) { val in
                    updateKeyframeProperty { $0.scale = val }
                }
            case .rotation:
                sliderRow(title: "°", value: CGFloat(current.rotation), range: -360...360) { val in
                    updateKeyframeProperty { $0.rotation = Double(val) }
                }
            case .opacity:
                sliderRow(title: "Opacity", value: CGFloat(current.opacity), range: 0...1) { val in
                    updateKeyframeProperty { $0.opacity = Float(val) }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func sliderRow(title: String, value: CGFloat, range: ClosedRange<CGFloat>, onChange: @escaping (CGFloat) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .leading)
            Slider(value: Binding(
                get: { value },
                set: { onChange($0) }
            ), in: range)
            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))

            Text(String(format: "%.2f", value))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                .frame(width: 44)
        }
    }

    private var easingPicker: some View {
        HStack(spacing: 6) {
            ForEach(KeyframeEasing.allCases, id: \.self) { curve in
                let isSelected = (viewModel.selectedClip?.keyframeAnimation?.easing ?? .easeInOut) == curve
                Button(action: { setEasing(curve) }) {
                    Text(curve.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.white.opacity(0.06))
                        .foregroundColor(isSelected ? .white : .gray)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { addKeyframeAtPlayhead() }) {
                HStack {
                    Image(systemName: "plus.diamond")
                    Text("Add Keyframe")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                 Color(red: 0.99, green: 0.32, blue: 0.56)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            if let selID = selectedKeyframeID {
                Button(action: { deleteKeyframe(selID) }) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .padding(12)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
    }

    private func addKeyframeAtPlayhead() {
        guard let clipID = viewModel.selectedClipID,
              let clip = viewModel.selectedClip else { return }
        let localTime = viewModel.currentTime - clip.startTime
        viewModel.addKeyframe(at: localTime, forClip: clipID)
        HapticManager.shared.light()
    }

    private func deleteKeyframe(_ id: UUID) {
        guard let clipID = viewModel.selectedClipID else { return }
        viewModel.removeKeyframe(id: id, fromClip: clipID)
        selectedKeyframeID = nil
    }

    private func setEasing(_ easing: KeyframeEasing) {
        guard let clipID = viewModel.selectedClipID else { return }
        viewModel.setKeyframeEasing(easing, forClip: clipID)
    }

    private func updateKeyframeProperty(_ modify: (inout Keyframe) -> Void) {
        guard let clipID = viewModel.selectedClipID,
              let clip = viewModel.selectedClip else { return }
        let localTime = viewModel.currentTime - clip.startTime
        viewModel.updateKeyframeAtPlayhead(localTime, forClip: clipID, modify: modify)
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
