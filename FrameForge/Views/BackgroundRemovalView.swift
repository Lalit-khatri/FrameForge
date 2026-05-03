import SwiftUI

struct BackgroundRemovalView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode = "blur"
    @State private var bgColor: Color = .green
    @State private var blurIntensity: Float = 0.7

    private let modes: [(id: String, name: String, icon: String)] = [
        ("blur", "Blur BG", "aqi.medium"),
        ("color", "Solid Color", "paintpalette.fill"),
        ("transparent", "Transparent", "checkerboard.rectangle"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.selectedClipID == nil {
                    noClipSelected
                } else {
                    mainContent
                }
            }
            .navigationTitle("Background Removal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.visible)
    }

    private var noClipSelected: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.rectangle")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("Select a video clip first")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "person.fill.viewfinder")
                    .font(.system(size: 36))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))

                Text("AI Person Segmentation")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Background Mode")
                    .font(.caption.bold())
                    .foregroundColor(.gray)

                HStack(spacing: 10) {
                    ForEach(modes, id: \.id) { mode in
                        Button(action: { selectedMode = mode.id }) {
                            VStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .font(.title3)
                                    .foregroundColor(selectedMode == mode.id ? .white : .gray)
                                Text(mode.name)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(selectedMode == mode.id ? .white : .gray)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 68)
                            .background(
                                selectedMode == mode.id
                                ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                : Color.white.opacity(0.06)
                            )
                            .cornerRadius(14)
                        }
                    }
                }
            }
            .padding(.horizontal)

            if selectedMode == "color" {
                HStack {
                    Text("Background Color")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    Spacer()
                    ColorPicker("", selection: $bgColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 44)
                }
                .padding(.horizontal)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            if selectedMode == "blur" {
                VStack(spacing: 4) {
                    HStack {
                        Text("Blur Strength")
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(blurIntensity * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    }
                    Slider(value: $blurIntensity, in: 0.1...1.0, step: 0.05)
                        .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
                .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: { applyEffect() }) {
                    HStack {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                        Text("Apply Background Removal")
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

                if hasExistingBGRemoval {
                    Button(action: { removeEffect() }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove BG Effect")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var hasExistingBGRemoval: Bool {
        viewModel.selectedClip?.effects.contains(where: { $0.type == .backgroundRemoval }) ?? false
    }

    private func applyEffect() {
        guard let clipID = viewModel.selectedClipID else { return }
        viewModel.removeEffect(.backgroundRemoval, fromClip: clipID)

        var effect = ClipEffect(type: .backgroundRemoval, intensity: 1.0)
        effect.parameters["bgMode"] = selectedMode == "blur" ? 0 : (selectedMode == "color" ? 1 : 2)

        if selectedMode == "blur" {
            effect.parameters["blurRadius"] = Double(blurIntensity)
        }

        if selectedMode == "color" {
            let uiColor = UIColor(bgColor)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            effect.parameters["colorR"] = Double(r)
            effect.parameters["colorG"] = Double(g)
            effect.parameters["colorB"] = Double(b)
        }

        viewModel.addEffect(effect, toClip: clipID)
        HapticManager.shared.success()
        dismiss()
    }

    private func removeEffect() {
        guard let clipID = viewModel.selectedClipID else { return }
        viewModel.removeEffect(.backgroundRemoval, fromClip: clipID)
        HapticManager.shared.light()
        dismiss()
    }
}
