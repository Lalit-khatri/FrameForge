import SwiftUI

struct SpeedControlView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var speed: Float = 1.0
    @State private var useSpeedCurve = false
    @State private var curvePoints: [CGPoint] = [
        CGPoint(x: 0.0, y: 0.5),
        CGPoint(x: 0.3, y: 0.5),
        CGPoint(x: 0.7, y: 0.5),
        CGPoint(x: 1.0, y: 0.5),
    ]
    @State private var draggingIndex: Int?

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
                            if useSpeedCurve {
                                viewModel.setSpeedCurve(curvePoints: curvePoints, forClip: clipID)
                            } else {
                                viewModel.setSpeed(speed, forClip: clipID)
                            }
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
        .onAppear {
            // Pre-fill current clip speed and curve
            if let clip = viewModel.selectedClip {
                speed = clip.speed
                if let curve = clip.speedCurve {
                    useSpeedCurve = true
                    curvePoints = curve.controlPoints
                }
            }
        }
    }

    // MARK: - Speed display

    private var speedDisplay: some View {
        VStack(spacing: 4) {
            Text(useSpeedCurve ? "Variable" : (String(format: "%.2f", speed) + "x"))
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: speedColor, startPoint: .leading, endPoint: .trailing)
                )
                .animation(.easeInOut(duration: 0.2), value: useSpeedCurve)
            Text(useSpeedCurve ? "Speed curve active" : (speed < 1 ? "Slow Motion" : speed > 1 ? "Fast Forward" : "Normal Speed"))
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private var speedColor: [Color] {
        if useSpeedCurve { return [Color(red: 0.42, green: 0.36, blue: 0.91), Color(red: 0.99, green: 0.32, blue: 0.56)] }
        if speed < 1  { return [.blue, .cyan] }
        if speed > 1  { return [.orange, .red] }
        return [Color(red: 0.42, green: 0.36, blue: 0.91), Color(red: 0.99, green: 0.32, blue: 0.56)]
    }

    // MARK: - Normal Speed Controls

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

    // MARK: - Speed Curve Editor

    private var speedCurveEditor: some View {
        VStack(spacing: 12) {
            // Canvas
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // Background grid
                    speedCurveGrid(in: geo.size)

                    // Speed labels on Y axis
                    speedYLabels(in: geo.size)

                    // Bezier curve path
                    speedCurvePath(size: geo.size)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                         Color(red: 0.99, green: 0.32, blue: 0.56)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    // Control point handles
                    ForEach(1..<curvePoints.count - 1, id: \.self) { i in
                        let pt = canvasPt(curvePoints[i], in: geo.size)
                        Circle()
                            .fill(draggingIndex == i
                                  ? Color(red: 0.99, green: 0.32, blue: 0.56)
                                  : Color(red: 0.42, green: 0.36, blue: 0.91))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 4)
                            .position(pt)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { val in
                                        draggingIndex = i
                                        let newX = min(1.0, max(0.0, val.location.x / w))
                                        // Clamp Y: top = 8x (fast), center = 1x, bottom = 0.1x (slow)
                                        let rawY = min(1.0, max(0.0, val.location.y / h))
                                        var pts = curvePoints
                                        pts[i] = CGPoint(x: newX, y: rawY)
                                        // Keep x monotonically increasing
                                        if i > 1 && pts[i].x < pts[i - 1].x { pts[i].x = pts[i - 1].x }
                                        if i < pts.count - 2 && pts[i].x > pts[i + 1].x { pts[i].x = pts[i + 1].x }
                                        curvePoints = pts
                                        HapticManager.shared.selection()
                                    }
                                    .onEnded { _ in draggingIndex = nil }
                            )
                    }
                }
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .frame(height: 160)
            .padding(.horizontal)

            // Legend
            HStack(spacing: 20) {
                legendItem(color: .cyan, label: "Slow (0.1×)")
                legendItem(color: Color(red: 0.42, green: 0.36, blue: 0.91), label: "Normal (1×)")
                legendItem(color: .orange, label: "Fast (8×)")
            }
            .font(.system(size: 10))
            .foregroundColor(.gray)

            // Preset curve buttons
            HStack(spacing: 8) {
                curvePresetButton("Linear") {
                    curvePoints = [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.33, y: 0.5),
                                   CGPoint(x: 0.66, y: 0.5), CGPoint(x: 1, y: 0.5)]
                }
                curvePresetButton("Ramp Up") {
                    curvePoints = [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.33, y: 0.7),
                                   CGPoint(x: 0.66, y: 0.3), CGPoint(x: 1, y: 0.5)]
                }
                curvePresetButton("Slow-Mo") {
                    curvePoints = [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.33, y: 0.85),
                                   CGPoint(x: 0.66, y: 0.85), CGPoint(x: 1, y: 0.5)]
                }
                curvePresetButton("Hero") {
                    curvePoints = [CGPoint(x: 0, y: 0.3), CGPoint(x: 0.25, y: 0.85),
                                   CGPoint(x: 0.75, y: 0.85), CGPoint(x: 1, y: 0.3)]
                }
            }
            .padding(.horizontal)

            Text("Drag the purple handles to shape speed. Top = slow, bottom = fast.")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Curve Helpers

    /// Convert normalised curve point (0…1, 0…1) to canvas coordinates
    private func canvasPt(_ pt: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: pt.x * size.width, y: pt.y * size.height)
    }

    /// Speed at a given Y normalised (0 = top = fast, 1 = bottom = slow)
    private func speedForY(_ y: CGFloat) -> Double {
        // Map: y=0 → 8x, y=0.5 → 1x, y=1 → 0.1x
        let t = Double(1.0 - y)  // flip: t=1 at top (fast)
        if t >= 0.5 {
            return 1.0 + (t - 0.5) * 14.0   // 1x…8x
        } else {
            return 0.1 + t * 1.8             // 0.1x…1x
        }
    }

    private func speedCurveGrid(in size: CGSize) -> some View {
        Canvas { ctx, sz in
            // Horizontal guides at 0.25, 0.5 (1x), 0.75
            for yFrac in [0.25, 0.5, 0.75] as [CGFloat] {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: yFrac * sz.height))
                path.addLine(to: CGPoint(x: sz.width, y: yFrac * sz.height))
                ctx.stroke(path, with: .color(.white.opacity(yFrac == 0.5 ? 0.2 : 0.08)),
                           style: StrokeStyle(lineWidth: 1, dash: yFrac == 0.5 ? [] : [4, 4]))
            }
        }
    }

    private func speedYLabels(in size: CGSize) -> some View {
        VStack {
            Text("8×")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
            Spacer()
            Text("1×")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
            Spacer()
            Text("0.1×")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.vertical, 6)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speedCurvePath(size: CGSize) -> Path {
        guard curvePoints.count >= 2 else { return Path() }
        let pts = curvePoints.map { canvasPt($0, in: size) }
        var path = Path()
        path.move(to: pts[0])
        // Catmull-Rom spline through all points
        for i in 1..<pts.count {
            let p0 = pts[max(0, i - 2)]
            let p1 = pts[i - 1]
            let p2 = pts[i]
            let p3 = pts[min(pts.count - 1, i + 1)]
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                              y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                              y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return path
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func curvePresetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) { action() }
            HapticManager.shared.light()
        }) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }
}
