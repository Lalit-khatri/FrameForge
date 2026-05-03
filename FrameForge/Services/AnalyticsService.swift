import Foundation
import OSLog

@Observable
final class AnalyticsService {
    static let shared = AnalyticsService()
    private let logger = Logger(subsystem: "com.frameforge.app", category: "Analytics")
    private var sessionStart = Date()
    private var eventCount = 0

    private init() {
        sessionStart = Date()
        track(.appLaunched)
    }

    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        eventCount += 1
        var params = properties
        params["timestamp"] = ISO8601DateFormatter().string(from: Date())
        params["session_duration"] = String(format: "%.0f", Date().timeIntervalSince(sessionStart))

        logger.info("📊 [\(event.name)] \(params.description)")

        UserDefaults.standard.set(eventCount, forKey: "analytics_total_events")
        incrementCounter(for: event)
    }

    func trackExport(format: String, resolution: String, platform: String? = nil) {
        var props = ["format": format, "resolution": resolution]
        if let platform = platform { props["platform"] = platform }
        track(.export, properties: props)
    }

    func trackFeatureUsed(_ feature: String) {
        track(.featureUsed, properties: ["feature": feature])
    }

    func trackError(_ error: String, context: String) {
        track(.error, properties: ["error": error, "context": context])
    }

    private func incrementCounter(for event: AnalyticsEvent) {
        let key = "analytics_count_\(event.name)"
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }

    func eventCount(for event: AnalyticsEvent) -> Int {
        UserDefaults.standard.integer(forKey: "analytics_count_\(event.name)")
    }

    var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStart)
    }
}

enum AnalyticsEvent: String {
    case appLaunched
    case projectCreated
    case projectOpened
    case clipAdded
    case clipTrimmed
    case clipDeleted
    case filterApplied
    case effectApplied
    case transitionApplied
    case textAdded
    case stickerAdded
    case export
    case featureUsed
    case error
    case proUpgradeShown
    case proUpgradePurchased
    case undoPerformed
    case redoPerformed
    case voiceoverRecorded
    case chromaKeyApplied
    case beatSyncUsed
    case stabilizationApplied
    case noiseReductionApplied

    var name: String { rawValue }
}
