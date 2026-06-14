import SwiftUI
import GoogleMobileAds

/// A medium-rectangle-style video/interstitial ad placeholder shown during export.
/// Uses GAM/AdMob 300×250 medium rectangle unit which supports video creatives.
struct VideoAdContainerView: View {
    @ObservedObject private var store = StoreKitManager.shared
    @State private var adLoaded = false
    @State private var shimmer = false

    private enum Keys {
        // AdMob 300×250 medium rectangle test ad unit
        static let testUnit = "ca-app-pub-3940256099942544/4411468910"
        static let plistKey = "GADVideoAdUnitID"
    }

    private var adUnitID: String {
        #if DEBUG
        return Keys.testUnit
        #else
        return Bundle.main.object(forInfoDictionaryKey: Keys.plistKey) as? String ?? Keys.testUnit
        #endif
    }

    var body: some View {
        if !store.isPro {
            VStack(spacing: 6) {
                HStack {
                    Text("Ad")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Medium rectangle slot (300×250) — supports video creatives
                VideoAdSlotView(adUnitID: adUnitID, adLoaded: $adLoaded)
                    .frame(width: 300, height: 250)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                // Shimmer placeholder while ad loads
                                adLoaded ? nil :
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.04),
                                                Color.white.opacity(shimmer ? 0.10 : 0.04),
                                                Color.white.opacity(0.04)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            shimmer = true
                        }
                    }
            }
        }
    }
}

/// UIViewRepresentable that loads a GADBannerView configured for a 300×250 medium rectangle.
/// AdMob returns video or display depending on available inventory.
private struct VideoAdSlotView: UIViewRepresentable {
    let adUnitID: String
    @Binding var adLoaded: Bool

    func makeCoordinator() -> Coordinator { Coordinator(adLoaded: $adLoaded) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeMediumRectangle)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.backgroundColor = .clear
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        guard uiView.rootViewController == nil else { return }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            uiView.rootViewController = rootVC
            uiView.load(Request())
        }
    }

    class Coordinator: NSObject, BannerViewDelegate {
        @Binding var adLoaded: Bool
        init(adLoaded: Binding<Bool>) { _adLoaded = adLoaded }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            DispatchQueue.main.async { self.adLoaded = true }
        }
    }
}
