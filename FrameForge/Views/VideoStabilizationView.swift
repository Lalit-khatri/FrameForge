import SwiftUI

struct VideoStabilizationView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var stabilizationMode: StabilizationMode = .standard
    @State private var smoothness: Double = 0.5
    @State private var cropCompensation = true
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    modeSelector

                    smoothnessControl

                    Toggle(isOn: $cropCompensation) {
                        HStack(spacing: 8) {
                            Image(systemName: "crop")
                                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                            VStack(alignment: .leading) {
                                Text("Auto Crop")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text("Crop edges to hide stabilization artifacts")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))

                    if isProcessing {
                        ProgressView("Stabilizing…")
                            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Stabilization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyStabilization()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                    .disabled(isProcessing)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stabilization Mode")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            HStack(spacing: 8) {
                ForEach(StabilizationMode.allCases, id: \.self) { mode in
                    Button(action: { stabilizationMode = mode }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.title3)
                            Text(mode.label)
                                .font(.caption2.bold())
                        }
                        .foregroundColor(stabilizationMode == mode ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            stabilizationMode == mode
                                ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                : Color.white.opacity(0.06)
                        )
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    private var smoothnessControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Smoothness")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(smoothness * 100))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: $smoothness, in: 0.1...1.0)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private func applyStabilization() {
        guard let clipID = viewModel.selectedClipID,
              let (ti, ci) = viewModel.findClipIndices(clipID) else { return }
        isProcessing = true
        viewModel.saveState()
        viewModel.tracks[ti].clips[ci].effects.append(
            ClipEffect(type: .stabilize, intensity: Float(smoothness))
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

enum StabilizationMode: String, CaseIterable {
    case standard, cinematic, aggressive

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .cinematic: return "Cinematic"
        case .aggressive: return "Lock"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "hand.raised"
        case .cinematic: return "video"
        case .aggressive: return "lock.shield"
        }
    }
}
