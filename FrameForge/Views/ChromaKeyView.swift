import SwiftUI

enum ChromaKeyColor: String, CaseIterable {
    case green = "Green"
    case blue = "Blue"
    case red = "Red"
    case custom = "Custom"

    var targetColor: (r: Float, g: Float, b: Float) {
        switch self {
        case .green: return (0.0, 1.0, 0.0)
        case .blue: return (0.0, 0.0, 1.0)
        case .red: return (1.0, 0.0, 0.0)
        case .custom: return (0.0, 1.0, 0.0)
        }
    }

    var displayColor: Color {
        switch self {
        case .green: return .green
        case .blue: return .blue
        case .red: return .red
        case .custom: return .gray
        }
    }
}

struct ChromaKeyView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColor: ChromaKeyColor = .green
    @State private var threshold: Float = 0.4
    @State private var smoothing: Float = 0.1
    @State private var spillSuppression: Float = 0.5

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.selectedClipID == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Select a clip to apply chroma key")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            colorSelector

                            controlSlider("Threshold", value: $threshold, range: 0.1...0.8,
                                        icon: "slider.horizontal.below.rectangle")
                            controlSlider("Smoothing", value: $smoothing, range: 0...0.5,
                                        icon: "wand.and.stars")
                            controlSlider("Spill Suppression", value: $spillSuppression, range: 0...1.0,
                                        icon: "eyedropper")

                            applyButton
                        }
                        .padding()
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Chroma Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var colorSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY COLOR")
                .font(.caption.bold())
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                ForEach(ChromaKeyColor.allCases, id: \.self) { color in
                    Button(action: { selectedColor = color }) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(color.displayColor)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color
                                            ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                            : .clear, lineWidth: 3)
                                )
                            Text(color.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selectedColor == color ? .white : .gray)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    private func controlSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>, icon: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: value, in: range)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    private var applyButton: some View {
        Button(action: {
            guard let clipID = viewModel.selectedClipID else { return }
            viewModel.applyChromaKey(color: selectedColor, threshold: threshold, toClip: clipID)
            HapticManager.shared.success()
            dismiss()
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Apply Chroma Key")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                             Color(red: 0.99, green: 0.32, blue: 0.56)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
    }
}
