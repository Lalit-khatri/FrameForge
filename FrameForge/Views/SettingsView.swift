import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var defaultResolution: String
    @State private var defaultFrameRate: Int
    @State private var autoSave: Bool
    @State private var autoSaveInterval: Int
    @State private var showGrid: Bool
    @State private var snapToGrid: Bool
    @State private var hapticFeedback: Bool
    @State private var highQualityPreview: Bool
    @State private var defaultCodec: String
    @State private var maxUndoSteps: Int
    @State private var cacheSize: String = "Calculating..."
    @State private var showResetConfirmation = false
    @State private var showClearCacheConfirmation = false
    @State private var showProUpgrade = false
    @State private var showTipJar = false
    @State private var isRestoring = false
    @State private var showRestoreResult = false
    @State private var restoreResultMessage = ""
    @ObservedObject private var store = StoreKitManager.shared

    private let settings = SettingsManager.shared

    init() {
        let mgr = SettingsManager.shared
        _defaultResolution = State(initialValue: UserDefaults.standard.string(forKey: "defaultResolution") ?? "1080p")
        _defaultFrameRate = State(initialValue: mgr.defaultFrameRate)
        _autoSave = State(initialValue: mgr.autoSaveEnabled)
        _autoSaveInterval = State(initialValue: mgr.autoSaveInterval)
        _showGrid = State(initialValue: mgr.showGrid)
        _snapToGrid = State(initialValue: mgr.snapToGrid)
        _hapticFeedback = State(initialValue: mgr.hapticFeedbackEnabled)
        _highQualityPreview = State(initialValue: mgr.highQualityPreview)
        _defaultCodec = State(initialValue: UserDefaults.standard.string(forKey: "defaultCodec") ?? "H.265")
        _maxUndoSteps = State(initialValue: mgr.maxUndoSteps)
    }

    var body: some View {
        NavigationStack {
            List {
                proSection
                tipJarSection
                projectDefaults
                editorPreferences
                previewSection
                storageSection
                restoreSection
                resetSection
            }
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.08))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
            .onAppear { calculateCacheSize() }
            .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { performReset() }
            } message: {
                Text("This will restore all settings to their default values. Your projects will not be affected.")
            }
            .alert("Clear Cache?", isPresented: $showClearCacheConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { performClearCache() }
            } message: {
                Text("This will remove all cached data including thumbnails. They will be regenerated as needed.")
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView()
            }
            .sheet(isPresented: $showTipJar) {
                TipJarView()
            }
            .alert("Restore Purchases", isPresented: $showRestoreResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreResultMessage)
            }
        }
    }

    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("FrameForge Pro")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("Active")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            } else {
                Button(action: { showProUpgrade = true }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Pro")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("4K export, 10 projects, no ads")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(store.proProduct?.displayPrice ?? "$14.99")
                            .font(.subheadline.bold())
                            .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    }
                }
            }
        } header: {
            Label("Pro", systemImage: "star.fill")
                .foregroundColor(.gray)
        }
        .listRowBackground(
            LinearGradient(
                colors: [Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.12),
                         Color.white.opacity(0.05)],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    private var projectDefaults: some View {
        Section {
            Picker("Default Resolution", selection: $defaultResolution) {
                Text("720p").tag("720p")
                Text("1080p").tag("1080p")
                Text("4K").tag("4K")
            }
            .onChange(of: defaultResolution) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "defaultResolution")
            }

            Picker("Default Frame Rate", selection: $defaultFrameRate) {
                Text("24 fps").tag(24)
                Text("30 fps").tag(30)
                Text("60 fps").tag(60)
            }
            .onChange(of: defaultFrameRate) { _, newValue in
                settings.defaultFrameRate = newValue
            }

            Picker("Default Codec", selection: $defaultCodec) {
                Text("H.264").tag("H.264")
                Text("H.265 (HEVC)").tag("H.265")
            }
            .onChange(of: defaultCodec) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "defaultCodec")
            }
        } header: {
            Label("Project Defaults", systemImage: "film")
                .foregroundColor(.gray)
        } footer: {
            Text("Applied when creating new projects and opening the export dialog.")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.6))
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var editorPreferences: some View {
        Section {
            Toggle("Auto-Save", isOn: $autoSave)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .onChange(of: autoSave) { _, newValue in
                    settings.autoSaveEnabled = newValue
                }

            if autoSave {
                Picker("Save Interval", selection: $autoSaveInterval) {
                    Text("15 sec").tag(15)
                    Text("30 sec").tag(30)
                    Text("1 min").tag(60)
                    Text("5 min").tag(300)
                }
                .onChange(of: autoSaveInterval) { _, newValue in
                    settings.autoSaveInterval = newValue
                }
            }

            Toggle("Show Grid Overlay", isOn: $showGrid)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .onChange(of: showGrid) { _, newValue in
                    settings.showGrid = newValue
                }

            Toggle("Snap to Grid", isOn: $snapToGrid)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .onChange(of: snapToGrid) { _, newValue in
                    settings.snapToGrid = newValue
                }

            Toggle("Haptic Feedback", isOn: $hapticFeedback)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .onChange(of: hapticFeedback) { _, newValue in
                    settings.hapticFeedbackEnabled = newValue
                    if newValue { HapticManager.shared.light() }
                }

            Stepper("Undo Steps: \(maxUndoSteps)", value: $maxUndoSteps, in: 5...50, step: 5)
                .onChange(of: maxUndoSteps) { _, newValue in
                    settings.maxUndoSteps = newValue
                }
        } header: {
            Label("Editor", systemImage: "slider.horizontal.3")
                .foregroundColor(.gray)
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var previewSection: some View {
        Section {
            Toggle("High Quality Preview", isOn: $highQualityPreview)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .onChange(of: highQualityPreview) { _, newValue in
                    settings.highQualityPreview = newValue
                }
        } header: {
            Label("Preview", systemImage: "play.rectangle")
                .foregroundColor(.gray)
        } footer: {
            Text("High quality preview uses more battery and may cause lag on older devices.")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.6))
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var storageSection: some View {
        Section {
            HStack {
                Text("Cache Size")
                Spacer()
                Text(cacheSize)
                    .foregroundColor(.gray)
            }

            Button(role: .destructive) {
                showClearCacheConfirmation = true
            } label: {
                HStack {
                    Text("Clear Cache")
                    Spacer()
                    Image(systemName: "trash")
                }
            }
        } header: {
            Label("Storage", systemImage: "internaldrive")
                .foregroundColor(.gray)
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var resetSection: some View {
        Section {
            Button {
                showResetConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Reset All Settings")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var tipJarSection: some View {
        Section {
            Button(action: { showTipJar = true }) {
                HStack {
                    Text("❤️")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tip Jar")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Support indie development")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Label("Support", systemImage: "heart.fill")
                .foregroundColor(.gray)
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var restoreSection: some View {
        Section {
            Button(action: {
                guard !isRestoring else { return }
                isRestoring = true
                Task {
                    await store.restorePurchases()
                    isRestoring = false
                    restoreResultMessage = store.isPro
                        ? "✅ Pro purchase restored successfully!"
                        : "No previous purchase found for this Apple ID."
                    showRestoreResult = true
                }
            }) {
                HStack {
                    Text("Restore Purchases")
                        .foregroundColor(
                            isRestoring
                                ? .gray
                                : Color(red: 0.42, green: 0.36, blue: 0.91)
                        )
                    Spacer()
                    if isRestoring {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.gray)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.gray)
                    }
                }
            }
            .disabled(isRestoring)
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private func calculateCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let size = settings.formattedCacheSize()
            DispatchQueue.main.async {
                cacheSize = size
            }
        }
    }

    private func performClearCache() {
        settings.clearCache()
        cacheSize = "0 MB"
        HapticManager.shared.success()
    }

    private func performReset() {
        settings.resetAll()
        defaultResolution = "1080p"
        defaultFrameRate = 30
        autoSave = true
        autoSaveInterval = 30
        showGrid = false
        snapToGrid = true
        hapticFeedback = true
        highQualityPreview = false
        defaultCodec = "H.265"
        maxUndoSteps = 20
        // Also persist UserDefaults-backed values so next launch reads correct defaults
        UserDefaults.standard.set("1080p", forKey: "defaultResolution")
        UserDefaults.standard.set("H.265", forKey: "defaultCodec")
        HapticManager.shared.success()
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                                     Color(red: 0.99, green: 0.32, blue: 0.56)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)

                                Image(systemName: "film.stack.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }

                            Text("FrameForge")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                                 Color(red: 0.99, green: 0.32, blue: 0.56)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )

                            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                            Text("Version \(appVersion)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)

                        VStack(spacing: 12) {
                            Text("Professional video editing, right in your pocket.")
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("FrameForge is a powerful, intuitive video editor built for creators. Cut, trim, split and arrange clips on a multi-track timeline. Apply cinematic filters and color grading in real time. Add animated text overlays, mix audio tracks, adjust speed, and export in stunning quality — all from your iPhone or iPad.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 0) {
                            featureRow(icon: "scissors", title: "Multi-track Timeline",
                                       desc: "Cut, split, trim and arrange clips")
                            Divider().background(Color.white.opacity(0.1))
                            featureRow(icon: "camera.filters", title: "Filters & Color",
                                       desc: "20+ presets and manual adjustments")
                            Divider().background(Color.white.opacity(0.1))
                            featureRow(icon: "textformat", title: "Text & Overlays",
                                       desc: "Animated titles with drag-to-place")
                            Divider().background(Color.white.opacity(0.1))
                            featureRow(icon: "music.note", title: "Audio Mixing",
                                       desc: "Import music and control volume")
                            Divider().background(Color.white.opacity(0.1))
                            featureRow(icon: "square.and.arrow.up", title: "Export",
                                       desc: "Up to 4K with H.265 / ProRes")
                        }
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        Text("Made with ❤️ for creators")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.5))

                        if StoreKitManager.shared.hasTipped {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundColor(.pink)
                                Text("Supporter")
                                    .font(.caption.bold())
                                    .foregroundColor(.pink)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.pink.opacity(0.15))
                            .cornerRadius(8)
                        }

                        if StoreKitManager.shared.isPro {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text("Pro")
                                    .font(.caption.bold())
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(8)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
