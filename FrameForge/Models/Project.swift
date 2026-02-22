import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var thumbnailData: Data?
    var aspectRatio: AspectRatio
    var frameRate: Int
    var resolution: ExportResolution
    var trackData: Data?
    var stickerData: Data?

    init(
        name: String = "Untitled Project",
        aspectRatio: AspectRatio = .landscape16x9,
        frameRate: Int? = nil,
        resolution: ExportResolution? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.aspectRatio = aspectRatio
        self.frameRate = frameRate ?? SettingsManager.shared.defaultFrameRate
        self.resolution = resolution ?? SettingsManager.shared.defaultResolution
    }
}

enum AspectRatio: String, Codable, CaseIterable {
    case portrait9x16 = "9:16"
    case landscape16x9 = "16:9"
    case square1x1 = "1:1"
    case portrait4x5 = "4:5"
    case landscape21x9 = "21:9"

    var width: CGFloat {
        switch self {
        case .portrait9x16: return 1080
        case .landscape16x9: return 1920
        case .square1x1: return 1080
        case .portrait4x5: return 1080
        case .landscape21x9: return 2560
        }
    }

    var height: CGFloat {
        switch self {
        case .portrait9x16: return 1920
        case .landscape16x9: return 1080
        case .square1x1: return 1080
        case .portrait4x5: return 1350
        case .landscape21x9: return 1080
        }
    }

    var displayName: String {
        switch self {
        case .portrait9x16: return "Portrait 9:16"
        case .landscape16x9: return "Landscape 16:9"
        case .square1x1: return "Square 1:1"
        case .portrait4x5: return "Portrait 4:5"
        case .landscape21x9: return "Ultrawide 21:9"
        }
    }

    var icon: String {
        switch self {
        case .portrait9x16: return "rectangle.portrait"
        case .landscape16x9: return "rectangle"
        case .square1x1: return "square"
        case .portrait4x5: return "rectangle.portrait"
        case .landscape21x9: return "rectangle"
        }
    }
}

enum ExportResolution: String, Codable, CaseIterable {
    case hd720p = "720p"
    case fhd1080p = "1080p"
    case qhd1440p = "1440p"
    case uhd4k = "4K"

    var displayName: String { rawValue }

    var multiplier: CGFloat {
        switch self {
        case .hd720p: return 720.0 / 1080.0
        case .fhd1080p: return 1.0
        case .qhd1440p: return 1440.0 / 1080.0
        case .uhd4k: return 2160.0 / 1080.0
        }
    }
}
