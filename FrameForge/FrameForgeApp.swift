import SwiftUI
import SwiftData
import AVFoundation
import GoogleMobileAds

@main
struct FrameForgeApp: App {
    @StateObject private var storeKit = StoreKitManager.shared

    init() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
        StoreKitManager.shared.start()
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environmentObject(storeKit)
        }
        .modelContainer(for: [Project.self])
    }
}
