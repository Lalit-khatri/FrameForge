import SwiftUI

struct NativeAdCardView: View {
    @ObservedObject private var store = StoreKitManager.shared

    var body: some View {
        if !store.isPro {
            VStack(spacing: 12) {
                HStack {
                    Text("Sponsored")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    Spacer()
                }

                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "megaphone.fill")
                                .foregroundColor(.gray)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Love FrameForge?")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Upgrade to Pro to remove ads and unlock 4K export.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                AdBannerContainer()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
}
