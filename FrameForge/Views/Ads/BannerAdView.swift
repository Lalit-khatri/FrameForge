import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView()
        banner.adUnitID = adUnitID
        banner.backgroundColor = .clear
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        if uiView.rootViewController == nil {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                uiView.rootViewController = rootVC
                let request = GADRequest()
                uiView.load(request)
            }
        }
    }
}

struct AdBannerContainer: View {
    @ObservedObject private var store = StoreKitManager.shared

    static let testAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    var body: some View {
        if !store.isPro {
            BannerAdView(adUnitID: Self.testAdUnitID)
                .frame(height: 50)
                .background(Color.black)
        }
    }
}
