import Foundation
import CoreImage

struct FrameForgePlugin: Identifiable, Codable {
    let id: UUID
    var name: String
    var pluginDescription: String
    var version: String
    var author: String
    var isEnabled: Bool
    var type: PluginType
    var filterName: String?

    enum PluginType: String, Codable, CaseIterable {
        case filter = "Filter"
        case transition = "Transition"
        case effect = "Effect"
        case exporter = "Exporter"
        case overlay = "Overlay"

        var icon: String {
            switch self {
            case .filter: return "camera.filters"
            case .transition: return "arrow.left.arrow.right"
            case .effect: return "sparkles"
            case .exporter: return "square.and.arrow.up"
            case .overlay: return "square.on.square"
            }
        }
    }

    init(name: String, description: String, version: String = "1.0", author: String = "FrameForge", type: PluginType, filterName: String? = nil) {
        self.id = UUID()
        self.name = name
        self.pluginDescription = description
        self.version = version
        self.author = author
        self.isEnabled = true
        self.type = type
        self.filterName = filterName
    }
}

@Observable
final class PluginManager {
    var plugins: [FrameForgePlugin] = []

    private enum Keys {
        static let pluginStates = "pluginStates"
    }

    init() { loadBuiltInPlugins() }

    private func loadBuiltInPlugins() {
        plugins = [
            FrameForgePlugin(name: "Vintage Film", description: "Classic film grain and warm tones", type: .filter, filterName: "CIPhotoEffectTransfer"),
            FrameForgePlugin(name: "Noir", description: "High-contrast black and white", type: .filter, filterName: "CIPhotoEffectNoir"),
            FrameForgePlugin(name: "Vignette Pro", description: "Customizable circular vignette", type: .effect, filterName: "CIVignette"),
            FrameForgePlugin(name: "Cross Dissolve+", description: "Enhanced cross dissolve transition", type: .transition),
            FrameForgePlugin(name: "GIF Exporter", description: "Export timeline as animated GIF", type: .exporter),
            FrameForgePlugin(name: "Watermark", description: "Add custom watermark overlays", type: .overlay),
            FrameForgePlugin(name: "Bloom", description: "Soft glow bloom effect", type: .effect, filterName: "CIBloom"),
            FrameForgePlugin(name: "Pixelate", description: "Mosaic pixelation filter", type: .filter, filterName: "CIPixellate"),
        ]
        loadUserPlugins()
    }

    func togglePlugin(_ id: UUID) {
        if let idx = plugins.firstIndex(where: { $0.id == id }) {
            plugins[idx].isEnabled.toggle()
            saveUserPlugins()
        }
    }

    func enabledPlugins(ofType type: FrameForgePlugin.PluginType) -> [FrameForgePlugin] {
        plugins.filter { $0.type == type && $0.isEnabled }
    }

    func createFilter(for plugin: FrameForgePlugin) -> CIFilter? {
        guard let filterName = plugin.filterName else { return nil }
        return CIFilter(name: filterName)
    }

    private func saveUserPlugins() {
        if let data = try? JSONEncoder().encode(plugins.map(\.isEnabled)) {
            UserDefaults.standard.set(data, forKey: Keys.pluginStates)
        }
    }

    private func loadUserPlugins() {
        if let data = UserDefaults.standard.data(forKey: Keys.pluginStates),
           let states = try? JSONDecoder().decode([Bool].self, from: data),
           states.count == plugins.count {
            for i in 0..<plugins.count {
                plugins[i].isEnabled = states[i]
            }
        }
    }
}
