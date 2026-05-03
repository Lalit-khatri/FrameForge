import Foundation
import AVFoundation

struct TimelineTrack: Identifiable, Codable {
    let id: UUID
    var type: TrackType
    var clips: [TimelineClip]
    var isMuted: Bool
    var isLocked: Bool
    var volume: Float
    var opacity: Float
    var transform: VideoTrackTransform?

    init(type: TrackType, clips: [TimelineClip] = [], transform: VideoTrackTransform? = nil) {
        self.id = UUID()
        self.type = type
        self.clips = clips
        self.isMuted = false
        self.isLocked = false
        self.volume = 1.0
        self.opacity = 1.0
        self.transform = transform
    }
}

struct VideoTrackTransform: Codable {
    var position: CGPoint
    var scale: CGFloat
    var rotation: Double
    var zIndex: Int

    static var fullFrame: VideoTrackTransform {
        VideoTrackTransform(position: CGPoint(x: 0.5, y: 0.5), scale: 1.0, rotation: 0, zIndex: 0)
    }

    static func pipDefault(index: Int) -> VideoTrackTransform {
        VideoTrackTransform(position: CGPoint(x: 0.75, y: 0.25), scale: 0.3, rotation: 0, zIndex: index)
    }
}

enum TrackType: String, Codable {
    case video
    case audio
    case text
    case overlay
}

struct TimelineClip: Identifiable, Codable {
    let id: UUID
    var assetURL: URL?
    var startTime: Double
    var duration: Double
    var trimStart: Double
    var trimEnd: Double
    var originalDuration: Double
    var speed: Float
    var volume: Float
    var opacity: Float
    var filterID: String?
    var transitionID: String?
    var transitionDuration: Double
    var textOverlay: TextOverlayData?
    var effects: [ClipEffect]
    var thumbnailData: Data?
    var colorAdjustments: ColorAdjustments?
    var isMuted: Bool
    var keyframeAnimation: KeyframeAnimation?
    var motionTrack: MotionTrackData?
    var pipPosition: String?
    var pipScale: Float?
    var isReversed: Bool = false

    var effectiveDuration: Double {
        (duration - trimStart - trimEnd) / Double(speed)
    }

    var endTime: Double {
        startTime + effectiveDuration
    }

    init(
        assetURL: URL?,
        startTime: Double = 0,
        duration: Double = 0,
        originalDuration: Double = 0
    ) {
        self.id = UUID()
        self.assetURL = assetURL
        self.startTime = startTime
        self.duration = duration
        self.trimStart = 0
        self.trimEnd = 0
        self.originalDuration = originalDuration
        self.speed = 1.0
        self.volume = 1.0
        self.opacity = 1.0
        self.transitionDuration = 0.3
        self.effects = []
        self.isMuted = false
        self.keyframeAnimation = nil
        self.motionTrack = nil
    }
}

struct TextOverlayData: Codable {
    var text: String
    var fontName: String
    var fontSize: CGFloat
    var textColor: CodableColor
    var backgroundColor: CodableColor?
    var position: CGPoint
    var rotation: Double
    var scale: CGFloat
    var animationStyle: TextAnimation

    init(text: String = "Text") {
        self.text = text
        self.fontName = "SF Pro Bold"
        self.fontSize = 48
        self.textColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
        self.position = CGPoint(x: 0.5, y: 0.5)
        self.rotation = 0
        self.scale = 1.0
        self.animationStyle = .none
    }

    init(
        text: String,
        fontName: String,
        fontSize: CGFloat,
        textColor: CodableColor,
        backgroundColor: CodableColor?,
        position: CGPoint,
        rotation: Double,
        scale: CGFloat,
        animationType: String
    ) {
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.animationStyle = TextAnimation(rawValue: animationType.capitalized) ?? .none
    }
}

struct CodableColor: Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
}

enum TextAnimation: String, Codable, CaseIterable {
    case none = "None"
    case fadeIn = "Fade In"
    case slideUp = "Slide Up"
    case typewriter = "Typewriter"
    case bounce = "Bounce"
    case glow = "Glow"
    case wave = "Wave"
}

struct ColorAdjustments: Codable {
    var brightness: Float = 0
    var contrast: Float = 0
    var saturation: Float = 0
    var temperature: Float = 0
    var sharpness: Float = 0
    var vignette: Float = 0
}

struct ClipEffect: Identifiable, Codable {
    let id: UUID
    var type: EffectType
    var intensity: Float
    var parameters: [String: Double]

    init(type: EffectType, intensity: Float = 1.0) {
        self.id = UUID()
        self.type = type
        self.intensity = intensity
        self.parameters = [:]
    }
}

enum EffectType: String, Codable, CaseIterable {
    case blur = "Blur"
    case vignette = "Vignette"
    case grain = "Film Grain"
    case glow = "Glow"
    case sharpen = "Sharpen"
    case pixelate = "Pixelate"
    case mirror = "Mirror"
    case glitch = "Glitch"
    case reverse = "Reverse"
    case rotate = "Rotate"
    case flip = "Flip"
    case border = "Border"
    case opacity = "Opacity"
    case denoise = "Denoise"
    case mosaic = "Mosaic"
    case backgroundRemoval = "BG Remove"
    case stabilize = "Stabilize"
    case noiseReduction = "Noise Reduction"
    case mask = "Mask"

    var hasIntensitySlider: Bool {
        switch self {
        case .mirror, .flip, .reverse, .backgroundRemoval:
            return false
        default:
            return true
        }
    }

    var defaultIntensity: Float {
        switch self {
        case .blur: return 0.5
        case .opacity: return 0.8
        case .grain: return 0.3
        case .glitch: return 0.4
        case .pixelate: return 0.3
        case .mosaic: return 0.3
        case .denoise: return 0.5
        case .vignette: return 0.6
        case .glow: return 0.5
        case .sharpen: return 0.5
        case .border: return 0.3
        case .rotate: return 0.25
        case .stabilize: return 0.5
        case .noiseReduction: return 0.5
        case .mask: return 0.5
        default: return 1.0
        }
    }
}

struct StickerData: Codable, Identifiable {
    let id: UUID
    var emoji: String
    var gifURL: String?
    var position: CGPoint
    var scale: CGFloat
    var rotation: Double
    var startTime: Double
    var duration: Double
    var clipID: UUID?

    init(emoji: String, gifURL: String? = nil, position: CGPoint = CGPoint(x: 0.5, y: 0.5), startTime: Double = 0, duration: Double = 10) {
        self.id = UUID()
        self.emoji = emoji
        self.gifURL = gifURL
        self.position = position
        self.scale = 1.0
        self.rotation = 0
        self.startTime = startTime
        self.duration = duration
        self.clipID = nil
    }
}

enum StickerCategory: String, CaseIterable {
    case smileys = "Smileys"
    case gestures = "Gestures"
    case animals = "Animals"
    case food = "Food"
    case travel = "Travel"
    case objects = "Objects"
    case symbols = "Symbols"
    case flags = "Flags"

    var icon: String {
        switch self {
        case .smileys: return "face.smiling"
        case .gestures: return "hand.wave"
        case .animals: return "pawprint"
        case .food: return "fork.knife"
        case .travel: return "airplane"
        case .objects: return "lightbulb"
        case .symbols: return "heart"
        case .flags: return "flag"
        }
    }

    var stickers: [String] {
        switch self {
        case .smileys:
            return ["😀", "😂", "🥹", "😍", "🤩", "😎", "🥳", "😈",
                    "🤯", "🥶", "🤮", "👻", "💀", "🤖", "👽", "🎃",
                    "😱", "🫠", "🤗", "🤔", "🫡", "😴", "🤐", "🫣"]
        case .gestures:
            return ["👍", "👎", "✌️", "🤞", "🤟", "🤘", "👌", "🤌",
                    "👏", "🙌", "🫶", "💪", "🖕", "✋", "🤚", "👋",
                    "🫰", "🫳", "🫴", "👆", "👇", "👈", "👉", "☝️"]
        case .animals:
            return ["🐶", "🐱", "🐭", "🦊", "🐻", "🐼", "🐨", "🦁",
                    "🐸", "🐵", "🦄", "🐝", "🦋", "🐙", "🐳", "🦈",
                    "🦅", "🐍", "🦎", "🐢", "🐬", "🐧", "🦜", "🦩"]
        case .food:
            return ["🍕", "🍔", "🌮", "🍣", "🍩", "🧁", "🎂", "🍰",
                    "🍿", "🌶️", "🍟", "🥤", "☕", "🍺", "🧋", "🫧",
                    "🍦", "🍪", "🥑", "🍓", "🍉", "🍇", "🫐", "🥝"]
        case .travel:
            return ["✈️", "🚀", "🛸", "🚗", "🏎️", "🏍️", "🚂", "⛵",
                    "🗼", "🏰", "🎡", "⛱️", "🌋", "🏔️", "🌊", "🌅",
                    "🗺️", "🧭", "⛺", "🏕️", "🎪", "🚁", "🛩️", "🚢"]
        case .objects:
            return ["💎", "🔥", "⚡", "💫", "⭐", "🌟", "✨", "💥",
                    "❤️‍🔥", "🎵", "🎬", "📸", "🎮", "🕹️", "🎯", "🏆",
                    "👑", "💰", "💣", "🔔", "🎁", "🎈", "🎉", "🎊"]
        case .symbols:
            return ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
                    "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘",
                    "💝", "♾️", "☮️", "☯️", "✝️", "🔯", "⚛️", "🕉️"]
        case .flags:
            return ["🏁", "🚩", "🎌", "🏴", "🏳️", "🏳️‍🌈", "🏴‍☠️", "🇺🇸",
                    "🇬🇧", "🇯🇵", "🇰🇷", "🇫🇷", "🇩🇪", "🇮🇹", "🇪🇸", "🇮🇳",
                    "🇧🇷", "🇨🇦", "🇦🇺", "🇲🇽", "🇷🇺", "🇨🇳", "🇹🇷", "🇸🇦"]
        }
    }
}
