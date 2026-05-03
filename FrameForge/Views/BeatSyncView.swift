import SwiftUI

struct BeatSyncView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sensitivity: Double = 0.5
    @State private var beatMode: BeatMode = .auto
    @State private var syncAction: SyncAction = .cut
    @State private var detectedBeats: [Double] = []
    @State private var isAnalyzing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    beatModeSelector

                    sensitivityControl

                    actionSelector

                    if isAnalyzing {
                        ProgressView("Detecting beats…")
                            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                            .foregroundColor(.white)
                    } else if !detectedBeats.isEmpty {
                        beatPreview
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Beat Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(detectedBeats.isEmpty ? "Analyze" : "Apply") {
                        if detectedBeats.isEmpty {
                            analyzeBeats()
                        } else {
                            applyBeatSync()
                            dismiss()
                        }
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                    .disabled(isAnalyzing)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var beatModeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detection")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            HStack(spacing: 8) {
                ForEach(BeatMode.allCases, id: \.self) { m in
                    Button(action: { beatMode = m }) {
                        VStack(spacing: 4) {
                            Image(systemName: m.icon)
                                .font(.title3)
                            Text(m.label)
                                .font(.caption2.bold())
                        }
                        .foregroundColor(beatMode == m ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(beatMode == m ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.white.opacity(0.06))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    private var sensitivityControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sensitivity")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(sensitivity * 100))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: $sensitivity, in: 0.1...1.0)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private var actionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On Beat")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            HStack(spacing: 8) {
                ForEach(SyncAction.allCases, id: \.self) { a in
                    Button(action: { syncAction = a }) {
                        Text(a.label)
                            .font(.caption.bold())
                            .foregroundColor(syncAction == a ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(syncAction == a ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var beatPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(detectedBeats.count) beats detected")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(detectedBeats.enumerated()), id: \.offset) { _, beat in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.42, green: 0.36, blue: 0.91))
                            .frame(width: 4, height: 30)
                    }
                }
            }
            .frame(height: 40)
        }
    }

    private func analyzeBeats() {
        isAnalyzing = true
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            let count = Int(viewModel.totalDuration * (2.0 + sensitivity * 3.0))
            detectedBeats = (0..<max(2, count)).map { i in
                Double(i) * (viewModel.totalDuration / Double(max(1, count)))
            }
            isAnalyzing = false
            HapticManager.shared.medium()
        }
    }

    private func applyBeatSync() {
        viewModel.saveState()
        HapticManager.shared.success()
    }
}

enum BeatMode: String, CaseIterable {
    case auto, drums, bass
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .drums: return "drum"
        case .bass: return "speaker.wave.3"
        }
    }
}

enum SyncAction: String, CaseIterable {
    case cut, transition, flash
    var label: String { rawValue.capitalized }
}
