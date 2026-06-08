import SwiftUI
import StoreKit

struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreKitManager.shared
    @State private var showThankYou = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = true

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

    private let tipDescriptions: [String: String] = [
        StoreKitManager.tipSmallID: "Keep the coffee coming ☕",
        StoreKitManager.tipMediumID: "Fuel a late-night coding session 🍕",
        StoreKitManager.tipLargeID: "Sponsor a whole feature build 🎬"
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
            .onAppear {
                // Reload products if not yet fetched
                if store.tipProducts.isEmpty {
                    Task {
                        await store.loadProducts()
                        withAnimation { isLoading = false }
                    }
                } else {
                    isLoading = false
                }
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

    @ViewBuilder
    private var tipCards: some View {
        if isLoading {
            // Loading skeleton while StoreKit fetches products
            VStack(spacing: 16) {
                ProgressView()
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .scaleEffect(1.2)
                Text("Loading tips...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(48)
        } else if store.tipProducts.isEmpty {
            // Failed to load — show retry option
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundColor(.gray)
                Text("Tips unavailable right now")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("Check your connection and try again.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Button(action: {
                    isLoading = true
                    Task {
                        await store.loadProducts()
                        withAnimation { isLoading = false }
                    }
                }) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.42, green: 0.36, blue: 0.91))
                        .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(Color.white.opacity(0.04))
            .cornerRadius(20)
        } else {
            VStack(spacing: 12) {
                ForEach(store.tipProducts, id: \.id) { product in
                    tipCard(product: product)
                }
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(tipNames[product.id] ?? product.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(tipDescriptions[product.id] ?? "One-time tip")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
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
        .opacity(store.purchaseInProgress ? 0.6 : 1.0)
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
