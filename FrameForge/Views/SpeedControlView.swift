import SwiftUI

struct SpeedControlView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var speed: Float = 1.0
    @State private var useSpeedCurve = false
    @State private var curvePoints: [SpeedPoint] = [
        SpeedPoint(position: 0, speed: 1.0),
        SpeedPoint(position: 0.5, speed: 1.0),
        SpeedPoint(position: 1.0, speed: 1.0),
    ]

    private let presetSpeeds: [(String, Float)] = [
        ("0.25x", 0.25), ("0.5x", 0.5), ("0.75x", 0.75),
        ("1x", 1.0), ("1.5x", 1.5), ("2x", 2.0),
        ("3x", 3.0), ("4x", 4.0), ("8x", 8.0),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    speedDisplay

                    Picker("Mode", selection: $useSpeedCurve) {
                        Text("Normal").tag(false)
                        Text("Speed Curve").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if useSpeedCurve {
                        speedCurveEditor
                    } else {
                        normalSpeedControls
                    }

                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let clipID = viewModel.selectedClipID {
                            viewModel.setSpeed(speed, forClip: clipID)
                        }
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var speedDisplay: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.2f", speed) + "x")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: speedColor,
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            Text(speed < 1 ? "Slow Motion" : speed > 1 ? "Fast Forward" : "Normal Speed")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private var speedColor: [Color] {
        if speed < 1 {
            return [.blue, .cyan]
        } else if speed > 1 {
            return [.orange, .red]
        }
        return [Color(red: 0.42, green: 0.36, blue: 0.91), Color(red: 0.99, green: 0.32, blue: 0.56)]
    }

    private var normalSpeedControls: some View {
        VStack(spacing: 16) {
            Slider(value: $speed, in: 0.1...8.0, step: 0.05)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetSpeeds, id: \.1) { name, value in
                        Button(action: {
                            speed = value
                            HapticManager.shared.selection()
                        }) {
                            Text(name)
                                .font(.caption.bold())
                                .foregroundColor(speed == value ? .white : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    speed == value
                                    ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                    : Color.white.opacity(0.08)
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var speedCurveEditor: some View {
        VStack(spacing: 16) {
            Slider(value: $speed, in: 0.1...8.0, step: 0.05)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetSpeeds, id: \.1) { name, value in
                        Button(action: {
                            speed = value
                            HapticManager.shared.selection()
                        }) {
                            Text(name)
                                .font(.caption.bold())
                                .foregroundColor(speed == value ? .white : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    speed == value
                                    ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                    : Color.white.opacity(0.08)
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
