import SwiftUI
import AVFoundation

struct MotionTrackingView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tracker = MotionTracker()
    @State private var trackRegion = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
    @State private var phase: TrackingPhase = .select

    enum TrackingPhase {
        case select
        case tracking
        case done
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch phase {
                case .select:
                    selectRegionView
                case .tracking:
                    trackingProgressView
                case .done:
                    resultsView
                }
            }
            .navigationTitle("Motion Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        tracker.cancel()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.visible)
    }

    private var selectRegionView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 44))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                Text("Select an object to track")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Position the playhead on the frame where the object is visible, then start tracking.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Region X")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    Slider(value: $trackRegion.origin.x, in: 0...0.8)
                        .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
                HStack {
                    Text("Region Y")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    Slider(value: $trackRegion.origin.y, in: 0...0.8)
                        .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
                HStack {
                    Text("Size")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    Slider(value: $trackRegion.size.width, in: 0.1...0.6)
                        .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .padding(.horizontal)

            Button(action: { startTracking() }) {
                HStack {
                    Image(systemName: "scope")
                    Text("Start Tracking")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                 Color(red: 0.99, green: 0.32, blue: 0.56)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .padding(.horizontal)
        }
    }

    private var trackingProgressView: some View {
        VStack(spacing: 20) {
            ProgressView(value: tracker.progress)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .scaleEffect(x: 1, y: 2)

            Text("Tracking object... \(Int(tracker.progress * 100))%")
                .font(.headline)
                .foregroundColor(.white)

            Text("\(tracker.trackingPoints.count) points captured")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }

    private var resultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)

            Text("Tracking Complete!")
                .font(.headline)
                .foregroundColor(.white)

            Text("\(tracker.trackingPoints.count) tracking points captured")
                .font(.subheadline)
                .foregroundColor(.gray)

            if let error = tracker.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: { applyTracking() }) {
                HStack {
                    Image(systemName: "scope")
                    Text("Apply Motion Track")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.42, green: 0.36, blue: 0.91))
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .padding(.horizontal)
        }
    }

    private func startTracking() {
        guard let clip = viewModel.selectedClip,
              let url = clip.assetURL else { return }

        phase = .tracking
        let region = CGRect(
            x: trackRegion.origin.x,
            y: trackRegion.origin.y,
            width: trackRegion.size.width,
            height: trackRegion.size.width
        )

        Task {
            let asset = AVAsset(url: url)
            await tracker.trackObject(in: asset, region: region)
            phase = .done
        }
    }

    private func applyTracking() {
        guard let clipID = viewModel.selectedClipID else { return }
        let trackData = tracker.toTrackData()
        viewModel.applyMotionTrack(trackData, toClip: clipID)
        HapticManager.shared.success()
        dismiss()
    }
}
