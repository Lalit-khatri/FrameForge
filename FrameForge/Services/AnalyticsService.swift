import Foundation
import OSLog

@Observable
final class AnalyticsService {
    static let shared = AnalyticsService()

    private static let subsystemID = "com.frameforge.app"
    private static let logCategory = "Analytics"

    private let logger = Logger(subsystem: subsystemID, category: logCategory)
    private var sessionStart = Date()
    private var eventCount = 0

    // DEBUG-only: UserDefaults keys for persisting analytics counters locally.
    // Not used in production — analytics data is only logged via OSLog in release builds.
    private enum Keys {
        static let totalEvents = "analytics_total_events"
        static let countPrefix = "analytics_count_"
        static func eventCount(_ event: AnalyticsEvent) -> String {
            "\(countPrefix)\(event.name)"
        }
    }

    private enum Params {
        static let timestamp = "timestamp"
        static let sessionDurationKey = "session_duration"
        static let format = "format"
        static let resolution = "resolution"
        static let platform = "platform"
        static let feature = "feature"
        static let error = "error"
        static let context = "context"
    }

    private init() {
        sessionStart = Date()
        track(.appLaunched)
    }

    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        eventCount += 1
        var params = properties
        params[Params.timestamp] = ISO8601DateFormatter().string(from: Date())
        params[Params.sessionDurationKey] = String(format: "%.0f", Date().timeIntervalSince(sessionStart))

        logger.info("📊 [\(event.name)] \(params.description)")

        // DEBUG-only: persist event counters to UserDefaults for development diagnostics.
        // This is not intended for production users.
        #if DEBUG
        UserDefaults.standard.set(eventCount, forKey: Keys.totalEvents)
        incrementCounter(for: event)
        #endif
    }

    func trackExport(format: String, resolution: String, platform: String? = nil) {
        var props = [Params.format: format, Params.resolution: resolution]
        if let platform = platform { props[Params.platform] = platform }
        track(.export, properties: props)
    }

    func trackFeatureUsed(_ feature: String) {
        track(.featureUsed, properties: [Params.feature: feature])
    }

    func trackError(_ error: String, context: String) {
        track(.error, properties: [Params.error: error, Params.context: context])
    }

    // DEBUG-only: increments per-event counters in UserDefaults for local diagnostics.
    private func incrementCounter(for event: AnalyticsEvent) {
        let key = Keys.eventCount(event)
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }

    // DEBUG-only: reads persisted event count from UserDefaults.
    func eventCount(for event: AnalyticsEvent) -> Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: Keys.eventCount(event))
        #else
        return 0
        #endif
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
