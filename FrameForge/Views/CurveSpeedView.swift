import SwiftUI

struct CurveSpeedView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var speedPoints: [SpeedPoint] = [
        SpeedPoint(position: 0.0, speed: 1.0),
        SpeedPoint(position: 0.25, speed: 1.0),
        SpeedPoint(position: 0.5, speed: 1.0),
        SpeedPoint(position: 0.75, speed: 1.0),
        SpeedPoint(position: 1.0, speed: 1.0)
    ]
    @State private var selectedPointIndex: Int?
    @State private var selectedPreset: SpeedPreset?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.selectedClipID == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "gauge.with.dots.needle.33percent")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Select a clip for speed ramping")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 20) {
                        curveEditor
                        presetSelector
                        speedInfo
                    }
                    .padding()
                }
            }
            .navigationTitle("Speed Curve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { resetCurve() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applySpeedCurve()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var curveEditor: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))

                gridLines(w: w, h: h)

                curvePath(w: w, h: h)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                     Color(red: 0.99, green: 0.32, blue: 0.56)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )

                curveArea(w: w, h: h)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.3), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                ForEach(0..<speedPoints.count, id: \.self) { i in
                    let pt = pointPosition(speedPoints[i], w: w, h: h)
                    Circle()
                        .fill(selectedPointIndex == i
                            ? Color(red: 0.99, green: 0.32, blue: 0.56)
                            : Color(red: 0.42, green: 0.36, blue: 0.91))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                        .position(pt)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    selectedPointIndex = i
                                    if i > 0 && i < speedPoints.count - 1 {
                                        let newPos = Double(val.location.x / w).clamped(to: 0.05...0.95)
                                        speedPoints[i].position = newPos
                                    }
                                    let newSpeed = Float((1.0 - val.location.y / h) * 4.0).clamped(to: 0.1...4.0)
                                    speedPoints[i].speed = newSpeed
                                }
                        )
                }

                speedLabels(h: h)
            }
        }
        .frame(height: 180)
    }

    private func gridLines(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            ForEach([0.25, 0.5, 0.75], id: \.self) { fraction in
                Path { path in
                    let y = h * (1.0 - fraction / 4.0)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }

            Path { path in
                let y = h * (1.0 - 1.0 / 4.0)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: w, y: y))
            }
            .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
        }
    }

    private func curvePath(w: CGFloat, h: CGFloat) -> Path {
        Path { path in
            guard !speedPoints.isEmpty else { return }
            let sorted = speedPoints.sorted { $0.position < $1.position }
            path.move(to: pointPosition(sorted[0], w: w, h: h))
            for i in 1..<sorted.count {
                let prev = pointPosition(sorted[i-1], w: w, h: h)
                let curr = pointPosition(sorted[i], w: w, h: h)
                let midX = (prev.x + curr.x) / 2
                path.addCurve(
                    to: curr,
                    control1: CGPoint(x: midX, y: prev.y),
                    control2: CGPoint(x: midX, y: curr.y)
                )
            }
        }
    }

    private func curveArea(w: CGFloat, h: CGFloat) -> Path {
        var path = curvePath(w: w, h: h)
        let sorted = speedPoints.sorted { $0.position < $1.position }
        if let last = sorted.last {
            path.addLine(to: CGPoint(x: last.position * w, y: h))
        }
        if let first = sorted.first {
            path.addLine(to: CGPoint(x: first.position * w, y: h))
        }
        path.closeSubpath()
        return path
    }

    private func pointPosition(_ point: SpeedPoint, w: CGFloat, h: CGFloat) -> CGPoint {
        CGPoint(
            x: point.position * w,
            y: h * (1.0 - CGFloat(point.speed) / 4.0)
        )
    }

    private func speedLabels(h: CGFloat) -> some View {
        VStack {
            Text("4x").font(.system(size: 8)).foregroundColor(.gray.opacity(0.5))
            Spacer()
            Text("1x").font(.system(size: 8)).foregroundColor(.gray.opacity(0.5))
            Spacer()
            Text("0x").font(.system(size: 8)).foregroundColor(.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    private var presetSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SpeedPreset.allCases, id: \.self) { preset in
                    Button(action: {
                        selectedPreset = preset
                        speedPoints = preset.points
                        HapticManager.shared.light()
                    }) {
                        Text(preset.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(selectedPreset == preset ? .white : .gray)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedPreset == preset
                                    ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                    : Color.white.opacity(0.08)
                            )
                            .cornerRadius(16)
                    }
                }
            }
        }
    }

    private var speedInfo: some View {
        HStack {
            if let idx = selectedPointIndex, idx < speedPoints.count {
                Label(String(format: "%.1fx", speedPoints[idx].speed),
                      systemImage: "gauge.with.dots.needle.33percent")
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Spacer()
            let avgSpeed = speedPoints.map(\.speed).reduce(0, +) / Float(max(1, speedPoints.count))
            Text(String(format: "Avg: %.1fx", avgSpeed))
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private func resetCurve() {
        speedPoints = [
            SpeedPoint(position: 0.0, speed: 1.0),
            SpeedPoint(position: 0.25, speed: 1.0),
            SpeedPoint(position: 0.5, speed: 1.0),
            SpeedPoint(position: 0.75, speed: 1.0),
            SpeedPoint(position: 1.0, speed: 1.0)
        ]
        selectedPreset = nil
        selectedPointIndex = nil
    }

    private func applySpeedCurve() {
        guard let clipID = viewModel.selectedClipID else { return }
        let avgSpeed = speedPoints.map(\.speed).reduce(0, +) / Float(max(1, speedPoints.count))
        viewModel.setSpeed(avgSpeed, forClip: clipID)
        HapticManager.shared.success()
    }
}

enum SpeedPreset: String, CaseIterable {
    case linear = "Normal"
    case rampUp = "Ramp Up"
    case rampDown = "Ramp Down"
    case pulse = "Pulse"
    case slowMo = "Slow Mo"
    case timelapse = "Timelapse"
    case flash = "Flash"
    case heartbeat = "Heartbeat"

    var points: [SpeedPoint] {
        switch self {
        case .linear:
            return [SpeedPoint(position: 0, speed: 1), SpeedPoint(position: 0.25, speed: 1),
                    SpeedPoint(position: 0.5, speed: 1), SpeedPoint(position: 0.75, speed: 1),
                    SpeedPoint(position: 1, speed: 1)]
        case .rampUp:
            return [SpeedPoint(position: 0, speed: 0.3), SpeedPoint(position: 0.3, speed: 0.5),
                    SpeedPoint(position: 0.6, speed: 1.5), SpeedPoint(position: 0.85, speed: 2.5),
                    SpeedPoint(position: 1, speed: 3.0)]
        case .rampDown:
            return [SpeedPoint(position: 0, speed: 3.0), SpeedPoint(position: 0.3, speed: 2.0),
                    SpeedPoint(position: 0.6, speed: 1.0), SpeedPoint(position: 0.85, speed: 0.5),
                    SpeedPoint(position: 1, speed: 0.3)]
        case .pulse:
            return [SpeedPoint(position: 0, speed: 1.0), SpeedPoint(position: 0.2, speed: 0.3),
                    SpeedPoint(position: 0.5, speed: 2.5), SpeedPoint(position: 0.8, speed: 0.3),
                    SpeedPoint(position: 1, speed: 1.0)]
        case .slowMo:
            return [SpeedPoint(position: 0, speed: 1.0), SpeedPoint(position: 0.2, speed: 0.5),
                    SpeedPoint(position: 0.5, speed: 0.2), SpeedPoint(position: 0.8, speed: 0.5),
                    SpeedPoint(position: 1, speed: 1.0)]
        case .timelapse:
            return [SpeedPoint(position: 0, speed: 3.0), SpeedPoint(position: 0.25, speed: 3.5),
                    SpeedPoint(position: 0.5, speed: 4.0), SpeedPoint(position: 0.75, speed: 3.5),
                    SpeedPoint(position: 1, speed: 3.0)]
        case .flash:
            return [SpeedPoint(position: 0, speed: 0.3), SpeedPoint(position: 0.4, speed: 0.3),
                    SpeedPoint(position: 0.5, speed: 4.0), SpeedPoint(position: 0.6, speed: 0.3),
                    SpeedPoint(position: 1, speed: 0.3)]
        case .heartbeat:
            return [SpeedPoint(position: 0, speed: 1.0), SpeedPoint(position: 0.15, speed: 2.5),
                    SpeedPoint(position: 0.3, speed: 0.5), SpeedPoint(position: 0.5, speed: 2.0),
                    SpeedPoint(position: 0.65, speed: 0.5), SpeedPoint(position: 0.85, speed: 1.5),
                    SpeedPoint(position: 1, speed: 1.0)]
        }
    }
}

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
