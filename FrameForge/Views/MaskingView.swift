import SwiftUI

struct MaskingView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var maskShape: MaskShape = .rectangle
    @State private var feather: Double = 10
    @State private var invertMask = false
    @State private var maskEffect: MaskEffect = .blur

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    shapeSelector

                    effectSelector

                    featherControl

                    Toggle(isOn: $invertMask) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.on.rectangle.slash")
                                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                            Text("Invert Mask")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Masking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyMask()
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

    private var shapeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mask Shape")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            HStack(spacing: 8) {
                ForEach(MaskShape.allCases, id: \.self) { shape in
                    Button(action: { maskShape = shape }) {
                        VStack(spacing: 4) {
                            Image(systemName: shape.icon)
                                .font(.title3)
                            Text(shape.label)
                                .font(.caption2.bold())
                        }
                        .foregroundColor(maskShape == shape ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(maskShape == shape ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.white.opacity(0.06))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    private var effectSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mask Effect")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            HStack(spacing: 8) {
                ForEach(MaskEffect.allCases, id: \.self) { effect in
                    Button(action: { maskEffect = effect }) {
                        Text(effect.label)
                            .font(.caption.bold())
                            .foregroundColor(maskEffect == effect ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(maskEffect == effect ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var featherControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Feather")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(feather))px")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: $feather, in: 0...50)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private func applyMask() {
        guard let clipID = viewModel.selectedClipID,
              let (ti, ci) = viewModel.findClipIndices(clipID) else { return }
        viewModel.saveState()
        var effect = ClipEffect(type: .mask, intensity: Float(feather / 50))
        effect.parameters["shape"] = Double(MaskShape.allCases.firstIndex(of: maskShape) ?? 0)
        effect.parameters["effect"] = Double(MaskEffect.allCases.firstIndex(of: maskEffect) ?? 0)
        effect.parameters["inverted"] = invertMask ? 1.0 : 0.0
        viewModel.tracks[ti].clips[ci].effects.append(effect)
        Task { await viewModel.rebuildComposition() }
        HapticManager.shared.success()
    }
}

enum MaskShape: String, CaseIterable {
    case rectangle, circle, freehand, linear
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .freehand: return "scribble"
        case .linear: return "line.diagonal"
        }
    }
}

enum MaskEffect: String, CaseIterable {
    case blur, color, mosaic, none
    var label: String { rawValue.capitalized }
}
