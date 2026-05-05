import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let pages: [(icon: String, title: String, subtitle: String, gradient: [Color])] = [
        ("film.stack", "Welcome to FrameForge",
         "Professional video editing at your fingertips. Multi-track timeline, 4K export, and AI-powered tools.",
         [Color(red: 0.42, green: 0.36, blue: 0.91), Color(red: 0.99, green: 0.32, blue: 0.56)]),

        ("wand.and.stars", "Powerful Effects",
         "Keyframe animation, motion tracking, 3D text, LUT color grading, chroma key, and 16+ real-time effects.",
         [Color(red: 0.99, green: 0.32, blue: 0.56), .orange]),

        ("sparkles", "AI-Powered Captions",
         "Auto-generate captions with Apple Speech AI. Choose from 6 professional styles — all on-device.",
         [.orange, .yellow]),

        ("icloud.and.arrow.up", "Create & Share",
         "Export in H.264, H.265, or ProRes. Cloud backup, collaboration, and plugin ecosystem built in.",
         [Color(red: 0.42, green: 0.36, blue: 0.91), .cyan])
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if verticalSizeClass == .compact {
                landscapeBody
            } else {
                portraitBody
            }
        }
    }

    private var portraitBody: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        withAnimation { currentPage = pages.count - 1 }
                        HapticManager.shared.light()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.gray)
                }
            }
            .frame(height: 20)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            iconView(size: 56, glowRadius: 50)

            Spacer().frame(height: 40)

            VStack(spacing: 12) {
                Text(pages[currentPage].title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(pages[currentPage].subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 40)

            Spacer()

            pageIndicator
                .padding(.bottom, 28)

            actionButton
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }

    private var landscapeBody: some View {
        HStack(spacing: 0) {
            iconView(size: 44, glowRadius: 40)
                .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation { currentPage = pages.count - 1 }
                            HapticManager.shared.light()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.gray)
                    }
                }
                .padding(.trailing, 24)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 8) {
                    Text(pages[currentPage].title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(pages[currentPage].subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 24)

                Spacer()

                pageIndicator
                    .padding(.bottom, 12)

                actionButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func iconView(size: CGFloat, glowRadius: CGFloat) -> some View {
        let page = pages[currentPage]
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [page.gradient.first?.opacity(0.4) ?? .clear, .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: glowRadius
                    )
                )
                .frame(width: glowRadius * 2, height: glowRadius * 2)

            Image(systemName: page.icon)
                .font(.system(size: size, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: page.gradient,
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: page.gradient.first?.opacity(0.5) ?? .clear, radius: 15)
        }
        .animation(.easeInOut(duration: 0.4), value: currentPage)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage
                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                        : Color.gray.opacity(0.3))
                    .frame(width: i == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }

    private var actionButton: some View {
        Button(action: {
            if currentPage < pages.count - 1 {
                withAnimation(.spring(response: 0.4)) { currentPage += 1 }
            } else {
                hasCompletedOnboarding = true
                isPresented = false
            }
            HapticManager.shared.light()
        }) {
            Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                 Color(red: 0.99, green: 0.32, blue: 0.56)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(16)
        }
    }
}
