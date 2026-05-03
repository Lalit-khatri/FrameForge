import SwiftUI

@Observable
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    var fps: Double = 0
    var memoryUsageMB: Double = 0
    var renderTimeMs: Double = 0
    var isEnabled = false

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount = 0

    func start() {
        guard !isEnabled else { return }
        isEnabled = true
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        isEnabled = false
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = link.timestamp
            updateMemory()
        }
    }

    private func updateMemory() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            memoryUsageMB = Double(info.resident_size) / (1024 * 1024)
        }
    }
}

struct PerformanceOverlay: View {
    @State private var monitor = PerformanceMonitor.shared

    var body: some View {
        if monitor.isEnabled {
            VStack(alignment: .leading, spacing: 2) {
                statRow("FPS", value: String(format: "%.0f", monitor.fps),
                        color: monitor.fps >= 55 ? .green : monitor.fps >= 30 ? .yellow : .red)
                statRow("MEM", value: String(format: "%.0f MB", monitor.memoryUsageMB),
                        color: monitor.memoryUsageMB < 200 ? .green : monitor.memoryUsageMB < 400 ? .yellow : .red)
            }
            .padding(6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .padding(8)
        }
    }

    private func statRow(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label): \(value)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
