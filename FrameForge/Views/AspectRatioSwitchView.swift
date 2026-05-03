import SwiftUI

struct AspectRatioSwitchView: View {
    @Bindable var viewModel: EditorViewModel
    let project: Project
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    currentPreview

                    ratioGrid

                    applyNote
                }
                .padding()
            }
            .navigationTitle("Canvas Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var currentPreview: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.42, green: 0.36, blue: 0.91), lineWidth: 2)
                .frame(
                    width: previewWidth(for: project.aspectRatio),
                    height: previewHeight(for: project.aspectRatio)
                )
                .overlay(
                    Text(project.aspectRatio.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                )

            Text("\(Int(project.aspectRatio.width)) × \(Int(project.aspectRatio.height))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    private var ratioGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(AspectRatio.allCases, id: \.self) { ratio in
                ratioCard(ratio)
            }
        }
    }

    private func ratioCard(_ ratio: AspectRatio) -> some View {
        let isActive = project.aspectRatio == ratio
        return Button(action: {
            project.aspectRatio = ratio
            viewModel.videoAspectRatio = ratio.width / ratio.height
            HapticManager.shared.light()
        }) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive
                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                        : Color.gray.opacity(0.3),
                        lineWidth: isActive ? 2 : 1)
                    .frame(
                        width: previewWidth(for: ratio) * 0.6,
                        height: previewHeight(for: ratio) * 0.6
                    )

                Text(ratio.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isActive ? .white : .gray)

                Text(ratio.rawValue)
                    .font(.system(size: 9))
                    .foregroundColor(isActive
                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                        : .gray.opacity(0.5))
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive
                        ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.15)
                        : Color.white.opacity(0.05))
            )
        }
    }

    private var applyNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text("Timeline will recompose to fit the new canvas size")
        }
        .font(.caption)
        .foregroundColor(.gray.opacity(0.6))
    }

    private func previewWidth(for ratio: AspectRatio) -> CGFloat {
        let maxH: CGFloat = 80
        let aspect = ratio.width / ratio.height
        if aspect >= 1 { return maxH * aspect }
        return maxH
    }

    private func previewHeight(for ratio: AspectRatio) -> CGFloat {
        let maxH: CGFloat = 80
        let aspect = ratio.width / ratio.height
        if aspect >= 1 { return maxH }
        return maxH / aspect
    }
}
