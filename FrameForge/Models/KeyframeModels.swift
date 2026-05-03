import Foundation

struct Keyframe: Identifiable, Codable {
    let id: UUID
    var time: Double
    var positionX: CGFloat
    var positionY: CGFloat
    var scale: CGFloat
    var rotation: Double
    var opacity: Float

    init(
        time: Double,
        positionX: CGFloat = 0.5,
        positionY: CGFloat = 0.5,
        scale: CGFloat = 1.0,
        rotation: Double = 0,
        opacity: Float = 1.0
    ) {
        self.id = UUID()
        self.time = time
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
    }
}

enum KeyframeEasing: String, Codable, CaseIterable {
    case linear = "Linear"
    case easeIn = "Ease In"
    case easeOut = "Ease Out"
    case easeInOut = "Ease In-Out"
    case spring = "Spring"

    func apply(_ t: Double) -> Double {
        switch self {
        case .linear: return t
        case .easeIn: return t * t
        case .easeOut: return t * (2 - t)
        case .easeInOut:
            return t < 0.5
                ? 2 * t * t
                : -1 + (4 - 2 * t) * t
        case .spring:
            let decay = exp(-4 * t) * cos(8 * .pi * t)
            return 1 - decay
        }
    }
}

struct KeyframeAnimation: Codable {
    var keyframes: [Keyframe]
    var easing: KeyframeEasing

    init(keyframes: [Keyframe] = [], easing: KeyframeEasing = .easeInOut) {
        self.keyframes = keyframes
        self.easing = easing
    }

    func interpolated(at time: Double) -> Keyframe? {
        guard !keyframes.isEmpty else { return nil }
        let sorted = keyframes.sorted { $0.time < $1.time }

        if time <= sorted.first!.time { return sorted.first }
        if time >= sorted.last!.time { return sorted.last }

        for i in 0..<sorted.count - 1 {
            let a = sorted[i]
            let b = sorted[i + 1]
            if time >= a.time && time <= b.time {
                let rawT = (time - a.time) / max(0.001, b.time - a.time)
                let t = easing.apply(rawT)
                let cg = CGFloat(t)

                return Keyframe(
                    time: time,
                    positionX: a.positionX + (b.positionX - a.positionX) * cg,
                    positionY: a.positionY + (b.positionY - a.positionY) * cg,
                    scale: a.scale + (b.scale - a.scale) * cg,
                    rotation: a.rotation + (b.rotation - a.rotation) * t,
                    opacity: a.opacity + Float(t) * (b.opacity - a.opacity)
                )
            }
        }
        return sorted.last
    }

    mutating func addKeyframe(at time: Double, from current: Keyframe? = nil) {
        let base = current ?? interpolated(at: time) ?? Keyframe(time: time)
        var newKF = base
        newKF = Keyframe(
            time: time,
            positionX: base.positionX,
            positionY: base.positionY,
            scale: base.scale,
            rotation: base.rotation,
            opacity: base.opacity
        )
        keyframes.removeAll { abs($0.time - time) < 0.05 }
        keyframes.append(newKF)
        keyframes.sort { $0.time < $1.time }
    }

    mutating func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }
}
