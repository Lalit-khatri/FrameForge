import Foundation
import Combine
import UIKit

/// Manages all persistent app settings backed by UserDefaults.
/// Conforms to ObservableObject so SwiftUI views can react to changes
/// without requiring an app restart (e.g. EditorView grid overlay).
final class SettingsManager: ObservableObject, @unchecked Sendable {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Key: String {
        case defaultResolution
        case defaultFrameRate
        case autoSave
        case autoSaveInterval
        case showGrid
        case snapToGrid
        case hapticFeedback
        case highQualityPreview
        case defaultCodec
        case maxUndoSteps
    }

    // MARK: - Published properties (drive live UI updates)

    @Published var showGrid: Bool {
        didSet { defaults.set(showGrid, forKey: Key.showGrid.rawValue) }
    }

    @Published var snapToGrid: Bool {
        didSet { defaults.set(snapToGrid, forKey: Key.snapToGrid.rawValue) }
    }

    @Published var hapticFeedbackEnabled: Bool {
        didSet { defaults.set(hapticFeedbackEnabled, forKey: Key.hapticFeedback.rawValue) }
    }

    @Published var highQualityPreview: Bool {
        didSet { defaults.set(highQualityPreview, forKey: Key.highQualityPreview.rawValue) }
    }

    @Published var autoSaveEnabled: Bool {
        didSet { defaults.set(autoSaveEnabled, forKey: Key.autoSave.rawValue) }
    }

    // MARK: - Standard properties

    var defaultResolution: ExportResolution {
        let raw = defaults.string(forKey: Key.defaultResolution.rawValue) ?? "1080p"
        switch raw {
        case "720p": return .hd720p
        case "4K": return .uhd4k
        default: return .fhd1080p
        }
    }

    var defaultFrameRate: Int {
        get { defaults.integer(forKey: Key.defaultFrameRate.rawValue) }
        set { defaults.set(newValue, forKey: Key.defaultFrameRate.rawValue) }
    }

    var autoSaveInterval: Int {
        get { defaults.integer(forKey: Key.autoSaveInterval.rawValue) }
        set { defaults.set(newValue, forKey: Key.autoSaveInterval.rawValue) }
    }

    var defaultCodec: VideoCodec {
        let raw = defaults.string(forKey: Key.defaultCodec.rawValue) ?? "H.265"
        switch raw {
        case "H.264": return .h264
        case "ProRes": return .proRes
        default: return .h265
        }
    }

    var maxUndoSteps: Int {
        get { defaults.integer(forKey: Key.maxUndoSteps.rawValue) }
        set { defaults.set(newValue, forKey: Key.maxUndoSteps.rawValue) }
    }

    // MARK: - Init

    private init() {
        defaults.register(defaults: [
            Key.defaultResolution.rawValue: "1080p",
            Key.defaultFrameRate.rawValue: 30,
            Key.autoSave.rawValue: true,
            Key.autoSaveInterval.rawValue: 30,
            Key.showGrid.rawValue: false,
            Key.snapToGrid.rawValue: true,
            Key.hapticFeedback.rawValue: true,
            Key.highQualityPreview.rawValue: false,
            Key.defaultCodec.rawValue: "H.265",
            Key.maxUndoSteps.rawValue: 20,
        ])

        // Initialize @Published vars from UserDefaults
        showGrid = defaults.bool(forKey: Key.showGrid.rawValue)
        snapToGrid = defaults.bool(forKey: Key.snapToGrid.rawValue)
        hapticFeedbackEnabled = defaults.bool(forKey: Key.hapticFeedback.rawValue)
        highQualityPreview = defaults.bool(forKey: Key.highQualityPreview.rawValue)
        autoSaveEnabled = defaults.bool(forKey: Key.autoSave.rawValue)
    }

    // MARK: - Helpers

    func defaultExportSettings() -> ExportSettings {
        var s = ExportSettings()
        s.resolution = defaultResolution
        s.frameRate = defaultFrameRate
        s.codec = defaultCodec
        return s
    }

    func cacheSize() -> Int64 {
        var totalSize: Int64 = 0

        let cacheDirs: [URL] = [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
            FileManager.default.temporaryDirectory
        ].compactMap { $0 }

        for dir in cacheDirs {
            if let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let size = attrs.fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
        }
        return totalSize
    }

    func clearCache() {
        let cacheDirs: [URL] = [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
            FileManager.default.temporaryDirectory
        ].compactMap { $0 }

        for dir in cacheDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            ) else { continue }

            for fileURL in contents {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    func formattedCacheSize() -> String {
        let bytes = cacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func resetAll() {
        let keys: [Key] = [
            .defaultResolution, .defaultFrameRate, .autoSave,
            .autoSaveInterval, .showGrid, .snapToGrid,
            .hapticFeedback, .highQualityPreview, .defaultCodec,
            .maxUndoSteps
        ]
        for key in keys {
            defaults.removeObject(forKey: key.rawValue)
        }
        // Re-sync @Published vars to their reset defaults
        showGrid = false
        snapToGrid = true
        hapticFeedbackEnabled = true
        highQualityPreview = false
        autoSaveEnabled = true
    }
}
