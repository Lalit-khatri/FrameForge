import Foundation
import UIKit

struct TimeFormatter {
    static func format(seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        let frames = Int((seconds - Double(totalSeconds)) * 30)
        return String(format: "%02d:%02d.%02d", minutes, secs, frames)
    }

    static func formatSimple(seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    static func formatPrecise(seconds: Double) -> String {
        let s = max(0, seconds)
        return String(format: "%.2fs", s)
    }

    static func formatDuration(seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else if seconds < 3600 {
            return String(format: "%dm %ds", Int(seconds) / 60, Int(seconds) % 60)
        } else {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            return String(format: "%dh %dm", hours, minutes)
        }
    }
}

final class HapticManager {
    static let shared = HapticManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private var isEnabled: Bool { SettingsManager.shared.hapticFeedbackEnabled }

    private init() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
    }

    func light() { guard isEnabled else { return }; lightGenerator.impactOccurred() }
    func medium() { guard isEnabled else { return }; mediumGenerator.impactOccurred() }
    func heavy() { guard isEnabled else { return }; heavyGenerator.impactOccurred() }
    func selection() { guard isEnabled else { return }; selectionGenerator.selectionChanged() }
    func success() { guard isEnabled else { return }; notificationGenerator.notificationOccurred(.success) }
    func warning() { guard isEnabled else { return }; notificationGenerator.notificationOccurred(.warning) }
    func error() { guard isEnabled else { return }; notificationGenerator.notificationOccurred(.error) }
}
