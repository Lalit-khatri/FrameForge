import SwiftUI

struct CaptionStyle: Identifiable {
    let id: String
    let name: String
    let icon: String
    let fontName: String
    let fontSize: CGFloat
    let textColor: CodableColor
    let backgroundColor: CodableColor?
    let position: CGPoint
    let animation: TextAnimation

    func toOverlay(text: String) -> TextOverlayData {
        var overlay = TextOverlayData(text: text)
        overlay.fontName = fontName
        overlay.fontSize = fontSize
        overlay.textColor = textColor
        overlay.backgroundColor = backgroundColor
        overlay.position = position
        overlay.animationStyle = animation
        return overlay
    }
}

struct CaptionStylePresets {
    static let all: [CaptionStyle] = [
        CaptionStyle(
            id: "classic",
            name: "Classic",
            icon: "text.bubble",
            fontName: "HelveticaNeue-Bold",
            fontSize: 36,
            textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
            backgroundColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.6),
            position: CGPoint(x: 0.5, y: 0.85),
            animation: .fadeIn
        ),
        CaptionStyle(
            id: "bold",
            name: "Bold",
            icon: "bold",
            fontName: "ArialRoundedMTBold",
            fontSize: 42,
            textColor: CodableColor(red: 1, green: 0.95, blue: 0, alpha: 1),
            backgroundColor: nil,
            position: CGPoint(x: 0.5, y: 0.85),
            animation: .bounce
        ),
        CaptionStyle(
            id: "neon",
            name: "Neon",
            icon: "lightbulb.fill",
            fontName: "Futura-Bold",
            fontSize: 38,
            textColor: CodableColor(red: 0, green: 1, blue: 1, alpha: 1),
            backgroundColor: nil,
            position: CGPoint(x: 0.5, y: 0.85),
            animation: .glow
        ),
        CaptionStyle(
            id: "minimal",
            name: "Minimal",
            icon: "minus",
            fontName: "AvenirNext-Medium",
            fontSize: 28,
            textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 0.8),
            backgroundColor: nil,
            position: CGPoint(x: 0.15, y: 0.85),
            animation: .none
        ),
        CaptionStyle(
            id: "outline",
            name: "Outline",
            icon: "textformat.size",
            fontName: "HelveticaNeue-Bold",
            fontSize: 40,
            textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
            backgroundColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.3),
            position: CGPoint(x: 0.5, y: 0.85),
            animation: .slideUp
        ),
        CaptionStyle(
            id: "karaoke",
            name: "Karaoke",
            icon: "music.mic",
            fontName: "Georgia-Bold",
            fontSize: 40,
            textColor: CodableColor(red: 1, green: 0.84, blue: 0, alpha: 1),
            backgroundColor: nil,
            position: CGPoint(x: 0.5, y: 0.5),
            animation: .bounce
        ),
    ]
}
