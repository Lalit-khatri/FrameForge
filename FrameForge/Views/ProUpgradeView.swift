import SwiftUI

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreKitManager.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRestoreResult = false
    @State private var restoreResultMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        headerSection
                        benefitsSection
                        purchaseButton
                        restoreButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("FrameForge Pro")
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
            .alert("Restore Purchases", isPresented: $showRestoreResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreResultMessage)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                     Color(red: 0.99, green: 0.32, blue: 0.56)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            Text("Unlock the Full Power")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("One-time purchase. No subscriptions. Yours forever.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var benefitsSection: some View {
        VStack(spacing: 12) {
            benefitCard(
                icon: "4k.tv",
                title: "4K & 1440p Export",
                description: "Export in stunning Ultra HD quality"
            )
            benefitCard(
                icon: "folder.fill",
                title: "10 Projects",
                description: "Save up to 10 projects (vs 5 free)"
            )
            benefitCard(
                icon: "hand.raised.slash.fill",
                title: "No Ads",
                description: "Remove all banner ads for a clean experience"
            )
            benefitCard(
                icon: "heart.fill",
                title: "Support Indie Dev",
                description: "Help keep FrameForge ad-free and awesome"
            )
        }
    }

    private func benefitCard(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                .frame(width: 44, height: 44)
                .background(Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var purchaseButton: some View {
        Button(action: {
            Task {
                guard let product = store.proProduct else {
                    errorMessage = "Product unavailable. Please try again shortly."
                    showError = true
                    return
                }
                do {
                    let _ = try await store.purchase(product)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }) {
            VStack(spacing: 4) {
                if store.isPro {
                    Label("You're a Pro!", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                } else if store.purchaseInProgress {
                    ProgressView()
                        .tint(.white)
                } else if store.proProduct == nil {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text("Loading price...")
                    }
                    .font(.headline)
                } else {
                    Text("Upgrade for \(store.proProduct!.displayPrice)")
                        .font(.headline)
                    Text("One-time purchase")
                        .font(.caption)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Group {
                    if store.isPro {
                        Color.green
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                     Color(red: 0.99, green: 0.32, blue: 0.56)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    }
                }
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(store.isPro || store.purchaseInProgress || store.proProduct == nil)
    }

    private var restoreButton: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await store.restorePurchases()
                    if store.isPro {
                        restoreResultMessage = "Your Pro purchase has been restored!"
                    } else {
                        restoreResultMessage = "No previous purchase found for this Apple ID."
                    }
                    showRestoreResult = true
                }
            }) {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // Required by App Store Guidelines (3.1.1) for IAP screens
            HStack(spacing: 12) {
                Link("Privacy Policy", destination: URL(string: "https://github.com/Lalit-khatri/FrameForge/blob/main/PRIVACY.md")!)
                Text("•").foregroundColor(.gray.opacity(0.5))
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption2)
            .foregroundColor(.gray.opacity(0.7))
        }
    }
}
