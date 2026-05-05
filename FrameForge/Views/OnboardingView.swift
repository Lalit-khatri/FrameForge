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
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                animatedBackground

                if verticalSizeClass == .compact {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func portraitLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            skipButton
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, geo.safeAreaInsets.top + 12)
                .padding(.trailing, 24)

            Spacer(minLength: 20)

            iconSection(page: pages[currentPage], iconSize: 70, glowSize: 160)
                .frame(height: geo.size.height * 0.3)

            textSection(page: pages[currentPage])
                .padding(.horizontal, 32)

            Spacer(minLength: 20)

            pageIndicator
                .padding(.bottom, 24)

            actionButton
                .padding(.horizontal, 40)
                .padding(.bottom, geo.safeAreaInsets.bottom + 20)
        }
    }

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            skipButton
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, geo.safeAreaInsets.top + 8)
                .padding(.trailing, 24)

            HStack(spacing: 32) {
                iconSection(page: pages[currentPage], iconSize: 50, glowSize: 110)
                    .frame(width: geo.size.width * 0.3)

                VStack(spacing: 16) {
                    textSection(page: pages[currentPage], compact: true)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 8)

            HStack(spacing: 24) {
                pageIndicator

                actionButton
                    .frame(maxWidth: 260)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, geo.safeAreaInsets.bottom + 12)
        }
    }

    private func iconSection(page: (icon: String, title: String, subtitle: String, gradient: [Color]), iconSize: CGFloat, glowSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: page.gradient + [.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowSize * 0.7
                    )
                )
                .frame(width: glowSize, height: glowSize)
                .opacity(0.6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: page.gradient.map { $0.opacity(0.3) } + [.clear],
                        center: .center,
                        startRadius: glowSize * 0.3,
                        endRadius: glowSize
                    )
                )
                .frame(width: glowSize * 1.6, height: glowSize * 1.6)

            Image(systemName: page.icon)
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: page.gradient,
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: page.gradient.first?.opacity(0.5) ?? .clear, radius: 20)
        }
        .animation(.easeInOut(duration: 0.5), value: currentPage)
    }

    private func textSection(page: (icon: String, title: String, subtitle: String, gradient: [Color]), compact: Bool = false) -> some View {
        VStack(spacing: compact ? 8 : 14) {
            Text(page.title)
                .font(compact ? .title2.bold() : .title.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(compact ? .subheadline : .body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(compact ? 2 : 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private var animatedBackground: some View {
        ZStack {
            let page = pages[currentPage]
            Circle()
                .fill(
                    RadialGradient(
                        colors: [page.gradient.first?.opacity(0.15) ?? .clear, .clear],
                        center: .topLeading,
                        startRadius: 50,
                        endRadius: 400
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: -150, y: -200)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [page.gradient.last?.opacity(0.1) ?? .clear, .clear],
                        center: .bottomTrailing,
                        startRadius: 50,
                        endRadius: 350
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: 150, y: 250)
        }
        .animation(.easeInOut(duration: 0.8), value: currentPage)
        .ignoresSafeArea()
    }

    private var skipButton: some View {
        Group {
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    withAnimation { currentPage = pages.count - 1 }
                    HapticManager.shared.light()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.gray)
            }
        }
        .frame(height: 24)
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
                withAnimation(.easeOut(duration: 0.2)) {
                    isPresented = false
                }
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
                        colors: pages[currentPage].gradient,
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: pages[currentPage].gradient.first?.opacity(0.4) ?? .clear, radius: 12, y: 6)
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }
}
