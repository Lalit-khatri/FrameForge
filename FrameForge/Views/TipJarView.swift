import SwiftUI
import StoreKit

struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreKitManager.shared
    @State private var showThankYou = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let tipEmojis: [String: String] = [
        StoreKitManager.tipSmallID: "☕",
        StoreKitManager.tipMediumID: "🍕",
        StoreKitManager.tipLargeID: "🎬"
    ]

    private let tipNames: [String: String] = [
        StoreKitManager.tipSmallID: "Coffee",
        StoreKitManager.tipMediumID: "Pizza",
        StoreKitManager.tipLargeID: "Studio Time"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        tipCards
                        footerText
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                if showThankYou {
                    thankYouOverlay
                }
            }
            .navigationTitle("Tip Jar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("❤️")
                .font(.system(size: 56))
            Text("Support FrameForge")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text("FrameForge is built by an indie developer. Tips help keep the app updated and ad-free for everyone.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var tipCards: some View {
        VStack(spacing: 12) {
            ForEach(store.tipProducts, id: \.id) { product in
                tipCard(product: product)
            }
        }
    }

    private func tipCard(product: Product) -> some View {
        Button(action: {
            Task {
                do {
                    let success = try await store.purchase(product)
                    if success {
                        withAnimation(.spring(response: 0.4)) {
                            showThankYou = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showThankYou = false }
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }) {
            HStack(spacing: 16) {
                Text(tipEmojis[product.id] ?? "🎁")
                    .font(.system(size: 36))
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tipNames[product.id] ?? product.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("One-time tip")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline.bold())
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.15))
                    .cornerRadius(12)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .disabled(store.purchaseInProgress)
    }

    private var footerText: some View {
        Text("Tips are consumable purchases. You can tip as many times as you like! 💜")
            .font(.caption)
            .foregroundColor(.gray.opacity(0.6))
            .multilineTextAlignment(.center)
    }

    private var thankYouOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 72))
                Text("Thank You!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Your support means the world.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .scaleEffect(showThankYou ? 1.0 : 0.5)
            .opacity(showThankYou ? 1.0 : 0)
        }
        .transition(.opacity)
    }
}
