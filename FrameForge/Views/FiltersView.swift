import SwiftUI

struct FiltersView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: FilterCategory = .color
    @State private var adjustmentMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    Picker("Mode", selection: $adjustmentMode) {
                        Text("Filters").tag(false)
                        Text("Adjust").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if adjustmentMode {
                        adjustmentControls
                    } else {
                        filterPresets
                    }
                }
            }
            .navigationTitle("Filters & Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if adjustmentMode, let clipID = viewModel.selectedClipID {
                            viewModel.applyAdjustments(toClip: clipID)
                        }
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let clip = viewModel.selectedClip {
                if let adj = clip.colorAdjustments {
                    viewModel.adjustBrightness = adj.brightness
                    viewModel.adjustContrast = adj.contrast
                    viewModel.adjustSaturation = adj.saturation
                    viewModel.adjustTemperature = adj.temperature
                    viewModel.adjustSharpness = adj.sharpness
                    viewModel.adjustVignette = adj.vignette
                } else if let filterID = clip.filterID,
                          let filter = VideoFilter.presets.first(where: { $0.id == filterID }) {
                    viewModel.adjustBrightness = filter.brightness
                    viewModel.adjustContrast = filter.contrast
                    viewModel.adjustSaturation = filter.saturation
                    viewModel.adjustTemperature = filter.temperature
                    viewModel.adjustSharpness = filter.sharpness
                    viewModel.adjustVignette = filter.vignette
                }
            }
        }
    }

    private var filterPresets: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilterCategory.allCases, id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
                            Text(category.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(selectedCategory == category ? .white : .gray)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    selectedCategory == category
                                    ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                    : Color.white.opacity(0.08)
                                )
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
            }

            let filtered = VideoFilter.presets.filter { $0.category == selectedCategory }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(filtered, id: \.id) { filter in
                        filterCard(filter)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func filterCard(_ filter: VideoFilter) -> some View {
        let isActive = viewModel.selectedClip?.filterID == filter.id
        return Button(action: {
            if let clipID = viewModel.selectedClipID {
                viewModel.applyFilter(filter, toClip: clipID)
            }
        }) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: filterGradient(filter),
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.clear, lineWidth: 2)
                    )
                    .overlay(
                        isActive ? Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                        : nil
                    )

                Text(filter.name)
                    .font(.caption2)
                    .foregroundColor(isActive ? .white : .gray)
                    .lineLimit(1)
            }
        }
    }

    private func filterGradient(_ filter: VideoFilter) -> [Color] {
        switch filter.id {
        case "original": return [.gray.opacity(0.3), .gray.opacity(0.2)]
        case "vivid": return [.red.opacity(0.6), .orange.opacity(0.6)]
        case "warm": return [.orange.opacity(0.5), .yellow.opacity(0.4)]
        case "cool": return [.blue.opacity(0.5), .cyan.opacity(0.4)]
        case "dramatic": return [.black, .gray.opacity(0.5)]
        case "noir": return [.black, .white.opacity(0.2)]
        case "cinematic": return [.indigo.opacity(0.5), .orange.opacity(0.3)]
        case "cyberpunk": return [.purple.opacity(0.7), .cyan.opacity(0.5)]
        case "golden": return [.yellow.opacity(0.5), .orange.opacity(0.5)]
        case "tokyo-night": return [.purple.opacity(0.5), .blue.opacity(0.5)]
        default: return [.gray.opacity(0.3), .gray.opacity(0.15)]
        }
    }

    private var adjustmentControls: some View {
        ScrollView {
            VStack(spacing: 16) {
                adjustmentSlider("Brightness", icon: "sun.max", value: $viewModel.adjustBrightness)
                adjustmentSlider("Contrast", icon: "circle.lefthalf.filled", value: $viewModel.adjustContrast)
                adjustmentSlider("Saturation", icon: "drop.fill", value: $viewModel.adjustSaturation)
                adjustmentSlider("Temperature", icon: "thermometer.medium", value: $viewModel.adjustTemperature)
                adjustmentSlider("Sharpness", icon: "triangle", value: $viewModel.adjustSharpness)
                adjustmentSlider("Vignette", icon: "circle.dashed", value: $viewModel.adjustVignette)

                Button(action: {
                    viewModel.adjustBrightness = 0
                    viewModel.adjustContrast = 0
                    viewModel.adjustSaturation = 0
                    viewModel.adjustTemperature = 0
                    viewModel.adjustSharpness = 0
                    viewModel.adjustVignette = 0
                    if let clipID = viewModel.selectedClipID {
                        viewModel.applyFilter(
                            VideoFilter(id: "original", name: "Original"),
                            toClip: clipID
                        )
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset All")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private func adjustmentSlider(_ label: String, icon: String, value: Binding<Float>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 20)
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f", value.wrappedValue * 100))
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .frame(width: 40, alignment: .trailing)
            }
            Slider(value: value, in: -1...1)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .onChange(of: value.wrappedValue) { _, _ in
                    if let clipID = viewModel.selectedClipID {
                        viewModel.applyAdjustments(toClip: clipID)
                    }
                }
        }
    }
}
