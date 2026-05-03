import SwiftUI

struct NoiseReductionView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var reductionAmount: Double = 0.5
    @State private var mode: NoiseMode = .auto
    @State private var preserveVoice = true
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            ForEach(NoiseMode.allCases, id: \.self) { m in
                                Button(action: { mode = m }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: m.icon)
                                            .font(.title3)
                                        Text(m.label)
                                            .font(.caption2.bold())
                                    }
                                    .foregroundColor(mode == m ? .white : .gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        mode == m
                                            ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                            : Color.white.opacity(0.06)
                                    )
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Reduction")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(reductionAmount * 100))%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                        }
                        Slider(value: $reductionAmount, in: 0.1...1.0)
                            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))

                    Toggle(isOn: $preserveVoice) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.wave.2")
                                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                            VStack(alignment: .leading) {
                                Text("Preserve Voice")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text("Protect speech frequencies from reduction")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))

                    if isProcessing {
                        ProgressView("Processing…")
                            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Noise Reduction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyNoiseReduction() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                        .bold()
                        .disabled(isProcessing)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func applyNoiseReduction() {
        guard let clipID = viewModel.selectedClipID,
              let (ti, ci) = viewModel.findClipIndices(clipID) else { return }
        isProcessing = true
        viewModel.saveState()
        viewModel.tracks[ti].clips[ci].effects.append(
            ClipEffect(type: .noiseReduction, intensity: Float(reductionAmount))
        )
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await viewModel.rebuildComposition()
            isProcessing = false
            HapticManager.shared.success()
            dismiss()
        }
    }
}

enum NoiseMode: String, CaseIterable {
    case auto, wind, hum

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .wind: return "Wind"
        case .hum: return "Hum"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .wind: return "wind"
        case .hum: return "bolt.horizontal"
        }
    }
}
