import SwiftUI

struct EffectsView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var activeEffect: EffectType?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.selectedClipID == nil {
                    noSelectionPrompt
                } else if let active = activeEffect {
                    effectDetailView(active)
                } else {
                    effectsGrid
                }
            }
            .navigationTitle(activeEffect?.rawValue ?? "Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if activeEffect != nil {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeEffect = nil
                            }
                        }
                        .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.4)))
    }

    private var noSelectionPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.4))
            Text("Select a clip to apply effects")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 40)
    }

    private var effectsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(EffectType.allCases, id: \.self) { effectType in
                    effectCard(effectType)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private func effectCard(_ effectType: EffectType) -> some View {
        let isActive = viewModel.selectedClip?.effects.contains(where: { $0.type == effectType }) ?? false
        let currentIntensity = viewModel.selectedClip?.effects.first(where: { $0.type == effectType })?.intensity ?? 1.0

        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive
                        ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.25)
                        : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isActive ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.clear, lineWidth: 1.5)
                    )

                VStack(spacing: 4) {
                    Image(systemName: effectIcon(effectType))
                        .font(.title3)
                        .foregroundColor(isActive ? Color(red: 0.42, green: 0.36, blue: 0.91) : .white.opacity(0.6))

                    Text(effectType.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if isActive {
                        Text("\(Int(currentIntensity * 100))%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    }
                }
                .padding(.vertical, 10)
            }
            .frame(height: 90)
            .onTapGesture {
                guard let clipID = viewModel.selectedClipID else { return }
                if isActive {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeEffect = effectType
                    }
                } else {
                    viewModel.addEffect(ClipEffect(type: effectType, intensity: effectType.defaultIntensity), toClip: clipID)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeEffect = effectType
                    }
                }
            }
        }
    }

    private func effectDetailView(_ effectType: EffectType) -> some View {
        let isActive = viewModel.selectedClip?.effects.contains(where: { $0.type == effectType }) ?? false
        let currentIntensity = viewModel.selectedClip?.effects.first(where: { $0.type == effectType })?.intensity ?? effectType.defaultIntensity

        return VStack(spacing: 20) {
            HStack {
                Image(systemName: effectIcon(effectType))
                    .font(.title2)
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                Text(effectType.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()

                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { on in
                        guard let clipID = viewModel.selectedClipID else { return }
                        if on {
                            viewModel.addEffect(ClipEffect(type: effectType, intensity: effectType.defaultIntensity), toClip: clipID)
                        } else {
                            viewModel.removeEffect(effectType, fromClip: clipID)
                        }
                    }
                ))
                .labelsHidden()
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            .padding(.horizontal)

            if isActive && effectType.hasIntensitySlider {
                VStack(spacing: 8) {
                    HStack {
                        Text("Intensity")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(currentIntensity * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    }

                    Slider(value: Binding(
                        get: { currentIntensity },
                        set: { newVal in
                            guard let clipID = viewModel.selectedClipID else { return }
                            viewModel.updateEffectIntensity(effectType, intensity: Float(newVal), forClip: clipID)
                        }
                    ), in: 0.0...1.0, step: 0.01)
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))

                    HStack {
                        Text("0%")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.5))
                        Spacer()
                        Text("100%")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            if isActive {
                Button(action: {
                    guard let clipID = viewModel.selectedClipID else { return }
                    viewModel.removeEffect(effectType, fromClip: clipID)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeEffect = nil
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove Effect")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 12)
    }

    private func effectIcon(_ type: EffectType) -> String {
        switch type {
        case .blur: return "aqi.medium"
        case .vignette: return "circle.dashed"
        case .grain: return "film"
        case .glow: return "sun.max.fill"
        case .sharpen: return "triangle"
        case .pixelate: return "square.grid.3x3"
        case .mirror: return "arrow.left.and.right.righttriangle.left.righttriangle.right"
        case .glitch: return "waveform.path"
        case .reverse: return "backward.fill"
        case .rotate: return "rotate.right"
        case .flip: return "arrow.up.and.down.righttriangle.up.righttriangle.down"
        case .border: return "square.dashed"
        case .opacity: return "circle.lefthalf.filled"
        case .denoise: return "ear.trianglebadge.exclamationmark"
        case .mosaic: return "square.grid.4x3.fill"
        }
    }
}
