import SwiftUI

extension Color {
    static let ffAccent = Color(red: 0.42, green: 0.36, blue: 0.91)
    static let ffPink = Color(red: 0.99, green: 0.32, blue: 0.56)
    static let ffBlue = Color(red: 0.13, green: 0.59, blue: 0.95)

    static let ffGradient = LinearGradient(
        colors: [.ffAccent, .ffPink],
        startPoint: .leading, endPoint: .trailing
    )

    static let ffGradientDiagonal = LinearGradient(
        colors: [.ffAccent, .ffPink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
