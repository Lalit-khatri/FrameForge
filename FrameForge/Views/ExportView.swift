import SwiftUI

struct ExportView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsManager.shared.defaultExportSettings()
    @State private var showCancelConfirm = false
    @State private var showProUpgrade = false
    @ObservedObject private var store = StoreKitManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isExporting {
                    exportingView
                } else if let error = viewModel.exportError {
                    exportErrorView(error: error)
                } else if viewModel.exportProgress >= 1.0 && !viewModel.isExporting {
                    exportCompleteView
                } else {
                    settingsView
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.isExporting ? "Stop" : "Cancel") {
                        if viewModel.isExporting {
                            showCancelConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(viewModel.isExporting ? .red : .primary)
                }
            }
            .alert("Cancel Export?", isPresented: $showCancelConfirm) {
                Button("Keep Exporting", role: .cancel) {}
                Button("Cancel Export", role: .destructive) {
                    viewModel.cancelExport()
                    dismiss()
                }
            } message: {
                Text("Your export progress will be lost.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isExporting)
        .onAppear {
            viewModel.exportProgress = 0
            viewModel.exportError = nil
        }
    }

    private var settingsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                sectionHeader("Resolution", icon: "arrow.up.backward.and.arrow.down.forward")
                resolutionPicker

                sectionHeader("Frame Rate", icon: "timer")
                frameRatePicker

                sectionHeader("Quality", icon: "star")
                qualityPicker

                sectionHeader("Format", icon: "film")
                codecPicker

                toggleRow("Include Audio", icon: "speaker.wave.2", isOn: $settings.includeAudio)

                exportSummary

                Button(action: {
                    viewModel.exportSettings = settings
                    viewModel.startExport()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Video")
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
            }
            .padding()
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var resolutionPicker: some View {
        HStack(spacing: 8) {
            ForEach(ExportResolution.allCases, id: \.self) { res in
                let isLocked = !store.isPro && (res == .qhd1440p || res == .uhd4k)
                let isSelected = settings.resolution == res
                let fgColor: Color = isSelected ? .white : (isLocked ? .gray.opacity(0.5) : .gray)
                let bgColor: Color = isSelected
                    ? Color(red: 0.42, green: 0.36, blue: 0.91)
                    : Color.white.opacity(0.08)

                Button(action: {
                    if isLocked {
                        showProUpgrade = true
                    } else {
                        settings.resolution = res
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(res.displayName)
                            .font(.caption.bold())
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                        }
                    }
                    .foregroundColor(fgColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(bgColor)
                    .cornerRadius(10)
                }
            }
        }
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeView()
        }
    }

    private var frameRatePicker: some View {
        HStack(spacing: 8) {
            ForEach([24, 30, 60, 120], id: \.self) { fps in
                Button(action: { settings.frameRate = fps }) {
                    Text("\(fps)fps")
                        .font(.caption.bold())
                        .foregroundColor(settings.frameRate == fps ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            settings.frameRate == fps
                            ? Color(red: 0.42, green: 0.36, blue: 0.91)
                            : Color.white.opacity(0.08)
                        )
                        .cornerRadius(10)
                }
            }
        }
    }

    private var qualityPicker: some View {
        HStack(spacing: 8) {
            ForEach(ExportQuality.allCases, id: \.self) { quality in
                Button(action: { settings.quality = quality }) {
                    Text(quality.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(settings.quality == quality ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            settings.quality == quality
                            ? Color(red: 0.42, green: 0.36, blue: 0.91)
                            : Color.white.opacity(0.08)
                        )
                        .cornerRadius(10)
                }
            }
        }
    }

    private var codecPicker: some View {
        HStack(spacing: 8) {
            ForEach(VideoCodec.allCases, id: \.self) { codec in
                Button(action: { settings.codec = codec }) {
                    Text(codec.displayName)
                        .font(.caption.bold())
                        .foregroundColor(settings.codec == codec ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            settings.codec == codec
                            ? Color(red: 0.42, green: 0.36, blue: 0.91)
                            : Color.white.opacity(0.08)
                        )
                        .cornerRadius(10)
                }
            }
        }
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var exportSummary: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Estimated file size")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(estimatedFileSize)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            HStack {
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(TimeFormatter.formatDuration(seconds: viewModel.totalDuration))
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            HStack {
                Text("Watermark")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("None ✨")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var estimatedFileSize: String {
        let baseMBPerMinute: Double = 100
        let minutes = viewModel.totalDuration / 60.0
        let size = baseMBPerMinute * minutes * Double(settings.quality.bitrateFactor) * Double(settings.resolution.multiplier)
        if size > 1000 {
            return String(format: "%.1f GB", size / 1000)
        }
        return String(format: "%.0f MB", max(1, size))
    }

    private var exportingView: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Video Ad (free users only) — shown at top while user waits ──
                if !store.isPro {
                    VideoAdContainerView()
                        .padding(.top, 8)
                }

                // ── Circular progress ring ──
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.exportProgress))
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                         Color(red: 0.99, green: 0.32, blue: 0.56)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: viewModel.exportProgress)

                    Text("\(Int(viewModel.exportProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, store.isPro ? 32 : 0)

                Text("Exporting...")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Please keep the app open")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(action: { showCancelConfirm = true }) {
                    Text("Cancel Export")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }

                Spacer(minLength: 12)

                // ── Small banner ad at the bottom (free users only) ──
                if !store.isPro {
                    AdBannerContainer()
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var exportCompleteView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
            }

            Text("Export Complete!")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Video saved to Photos")
                .font(.subheadline)
                .foregroundColor(.gray)

            VStack(spacing: 12) {
                Button(action: {
                    viewModel.exportProgress = 0
                    viewModel.exportError = nil
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Export Again")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.42, green: 0.36, blue: 0.91))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 40)

            // Show native ad card for free users after successful export
            if !store.isPro {
                NativeAdCardView()
                    .padding(.top, 8)
            }
        }
    }

    private func exportErrorView(error: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.red)
            }

            Text("Export Failed")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button(action: {
                    viewModel.exportProgress = 0
                    viewModel.exportError = nil
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Try Again")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }

                Button(action: { dismiss() }) {
                    Text("Dismiss")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}
