import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let pages: [(icon: String, title: String, subtitle: String, gradient: [Color])] = [
        ("film.stack", "Welcome to\nFrameForge",
         "Professional video editing at your fingertips. Multi-track timeline, 4K export, and AI-powered tools.",
         [Color(red: 0.42, green: 0.36, blue: 0.91), Color(red: 0.99, green: 0.32, blue: 0.56)]),

        ("wand.and.stars", "Powerful\nEffects",
         "Keyframe animation, motion tracking, 3D text, LUT color grading, chroma key, and 16+ real-time effects.",
         [Color(red: 0.99, green: 0.32, blue: 0.56), .orange]),

        ("sparkles", "AI-Powered\nCaptions",
         "Auto-generate captions with Apple Speech AI. Choose from 6 professional styles — all on-device.",
         [.orange, .yellow]),

        ("icloud.and.arrow.up", "Create\n& Share",
         "Export in H.264, H.265, or ProRes. Cloud backup, collaboration, and plugin ecosystem built in.",
         [Color(red: 0.42, green: 0.36, blue: 0.91), .cyan])
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageContent(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                pageIndicator
                    .padding(.bottom, 24)

                actionButton
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
            }
        }
    }

    private func pageContent(_ page: (icon: String, title: String, subtitle: String, gradient: [Color])) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.gradient.first?.opacity(0.35) ?? .clear, .clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: page.gradient,
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
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
