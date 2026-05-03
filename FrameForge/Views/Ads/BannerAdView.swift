import SwiftUI

struct AdBannerContainer: View {
    @ObservedObject private var store = StoreKitManager.shared

    var body: some View {
        if !store.isPro {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.03))
                    .frame(height: 50)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "megaphone.fill")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Ad Space")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.5))
                            Spacer()
                            Text("Upgrade to Pro to remove")
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        .padding(.horizontal, 12)
                    )
            }
        }
    }
}

