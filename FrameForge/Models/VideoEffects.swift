import Foundation

struct VideoFilter: Identifiable {
    let id: String
    var name: String
    var category: FilterCategory
    var icon: String
    var lutFileName: String?

    var brightness: Float
    var contrast: Float
    var saturation: Float
    var temperature: Float
    var tint: Float
    var shadows: Float
    var highlights: Float
    var sharpness: Float
    var vignette: Float
    var grain: Float
    var fade: Float

    init(
        id: String,
        name: String,
        category: FilterCategory = .color,
        icon: String = "circle.fill"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.brightness = 0
        self.contrast = 0
        self.saturation = 0
        self.temperature = 0
        self.tint = 0
        self.shadows = 0
        self.highlights = 0
        self.sharpness = 0
        self.vignette = 0
        self.grain = 0
        self.fade = 0
    }
}

enum FilterCategory: String, CaseIterable {
    case color = "Color"
    case cinematic = "Cinematic"
    case vintage = "Vintage"
    case mood = "Mood"
    case blackAndWhite = "B&W"
    case custom = "Custom"
}

struct TransitionType: Identifiable {
    let id: String
    var name: String
    var icon: String
    var defaultDuration: Double

    static let allTransitions: [TransitionType] = [
        TransitionType(id: "none", name: "None", icon: "xmark.circle", defaultDuration: 0),
        TransitionType(id: "crossfade", name: "Crossfade", icon: "circle.lefthalf.filled", defaultDuration: 0.5),
        TransitionType(id: "dissolve", name: "Dissolve", icon: "sparkles", defaultDuration: 0.5),
        TransitionType(id: "slide-left", name: "Slide Left", icon: "arrow.left.square", defaultDuration: 0.4),
        TransitionType(id: "slide-right", name: "Slide Right", icon: "arrow.right.square", defaultDuration: 0.4),
        TransitionType(id: "slide-up", name: "Slide Up", icon: "arrow.up.square", defaultDuration: 0.4),
        TransitionType(id: "slide-down", name: "Slide Down", icon: "arrow.down.square", defaultDuration: 0.4),
        TransitionType(id: "zoom-in", name: "Zoom In", icon: "plus.magnifyingglass", defaultDuration: 0.5),
        TransitionType(id: "zoom-out", name: "Zoom Out", icon: "minus.magnifyingglass", defaultDuration: 0.5),
        TransitionType(id: "wipe-left", name: "Wipe Left", icon: "rectangle.lefthalf.inset.filled.arrow.left", defaultDuration: 0.5),
        TransitionType(id: "wipe-right", name: "Wipe Right", icon: "rectangle.righthalf.inset.filled.arrow.right", defaultDuration: 0.5),
        TransitionType(id: "blur", name: "Blur", icon: "aqi.medium", defaultDuration: 0.6),
        TransitionType(id: "flash", name: "Flash", icon: "bolt.fill", defaultDuration: 0.3),
        TransitionType(id: "spin", name: "Spin", icon: "arrow.triangle.2.circlepath", defaultDuration: 0.6),
        TransitionType(id: "glitch", name: "Glitch", icon: "waveform.path", defaultDuration: 0.4),
        TransitionType(id: "fade-black", name: "Fade Black", icon: "circle.fill", defaultDuration: 0.5),
        TransitionType(id: "fade-white", name: "Fade White", icon: "circle", defaultDuration: 0.5),
        TransitionType(id: "push-left", name: "Push Left", icon: "arrow.backward.to.line", defaultDuration: 0.4),
        TransitionType(id: "push-right", name: "Push Right", icon: "arrow.forward.to.line", defaultDuration: 0.4),
        TransitionType(id: "iris", name: "Iris", icon: "camera.aperture", defaultDuration: 0.6),
        TransitionType(id: "morph", name: "Morph", icon: "wand.and.rays", defaultDuration: 0.7),
        TransitionType(id: "page-curl", name: "Page Curl", icon: "book.pages", defaultDuration: 0.6),
        TransitionType(id: "ripple", name: "Ripple", icon: "water.waves", defaultDuration: 0.6),
        TransitionType(id: "swirl", name: "Swirl", icon: "tornado", defaultDuration: 0.5),
        TransitionType(id: "pixelate", name: "Pixelate", icon: "square.grid.3x3", defaultDuration: 0.5),
    ]
}

struct SpeedPoint: Identifiable, Codable {
    let id: UUID
    var position: Double
    var speed: Float

    init(position: Double, speed: Float) {
        self.id = UUID()
        self.position = position
        self.speed = speed
    }
}

struct ExportSettings: Codable {
    var resolution: ExportResolution
    var frameRate: Int
    var quality: ExportQuality
    var codec: VideoCodec
    var includeAudio: Bool

    init() {
        let mgr = SettingsManager.shared
        self.resolution = mgr.defaultResolution
        self.frameRate = mgr.defaultFrameRate
        self.quality = .high
        self.codec = mgr.defaultCodec
        self.includeAudio = true
    }

    init(resolution: ExportResolution, frameRate: Int, codec: VideoCodec, includeAudio: Bool) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.quality = .high
        self.codec = codec
        self.includeAudio = includeAudio
    }
}

enum ExportQuality: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"

    var bitrateFactor: Float {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 1.0
        case .ultra: return 1.5
        }
    }
}

enum VideoCodec: String, Codable, CaseIterable {
    case h264 = "H.264"
    case h265 = "H.265 (HEVC)"
    case proRes = "ProRes"

    var displayName: String { rawValue }
}

extension VideoFilter {
    static let presets: [VideoFilter] = [
        makePreset("original", "Original", .color),
        makePreset("vivid", "Vivid", .color, contrast: 0.1, saturation: 0.3),
        makePreset("warm", "Warm", .color, saturation: 0.1, temperature: 0.3),
        makePreset("cool", "Cool", .color, saturation: 0.05, temperature: -0.3),
        makePreset("dramatic", "Dramatic", .cinematic, contrast: 0.4, saturation: -0.1, shadows: -0.2),
        makePreset("noir", "Noir", .blackAndWhite, contrast: 0.3, saturation: -1.0),
        makePreset("chrome", "Chrome", .vintage, contrast: 0.15, saturation: -0.2, fade: 0.15),
        makePreset("fade", "Fade", .vintage, contrast: -0.1, saturation: -0.15, fade: 0.3),
        makePreset("instant", "Instant", .vintage, saturation: -0.1, temperature: 0.2, fade: 0.1),
        makePreset("mono", "Mono", .blackAndWhite, saturation: -1.0),
        makePreset("tonal", "Tonal", .blackAndWhite, contrast: -0.15, saturation: -1.0),
        makePreset("noir-warm", "Warm Noir", .blackAndWhite, contrast: 0.2, saturation: -0.9, temperature: 0.15),
        makePreset("cinematic", "Cinematic", .cinematic, contrast: 0.2, saturation: 0.1, temperature: 0.05, shadows: -0.15, highlights: 0.1),
        makePreset("cyberpunk", "Cyberpunk", .mood, contrast: 0.25, saturation: 0.4, temperature: -0.2, tint: 0.3),
        makePreset("golden", "Golden Hour", .mood, brightness: 0.05, saturation: 0.15, temperature: 0.4, fade: 0.05),
        makePreset("arctic", "Arctic", .mood, brightness: 0.1, saturation: -0.2, temperature: -0.4),
        makePreset("vintage-film", "Vintage Film", .vintage, contrast: 0.1, saturation: -0.2, temperature: 0.15, grain: 0.3, fade: 0.2),
        makePreset("dreamy", "Dreamy", .mood, brightness: 0.1, contrast: -0.1, saturation: 0.15, fade: 0.1),
        makePreset("tokyo-night", "Tokyo Night", .mood, contrast: 0.15, saturation: 0.3, temperature: -0.15, tint: 0.2),
        makePreset("desert", "Desert", .color, contrast: 0.1, saturation: -0.1, temperature: 0.3, highlights: 0.15),
    ]

    private static func makePreset(
        _ id: String, _ name: String, _ category: FilterCategory,
        brightness: Float = 0, contrast: Float = 0, saturation: Float = 0,
        temperature: Float = 0, tint: Float = 0, shadows: Float = 0,
        highlights: Float = 0, sharpness: Float = 0, vignette: Float = 0,
        grain: Float = 0, fade: Float = 0
    ) -> VideoFilter {
        var f = VideoFilter(id: id, name: name, category: category)
        f.brightness = brightness; f.contrast = contrast; f.saturation = saturation
        f.temperature = temperature; f.tint = tint; f.shadows = shadows
        f.highlights = highlights; f.sharpness = sharpness; f.vignette = vignette
        f.grain = grain; f.fade = fade
        return f
    }
}
