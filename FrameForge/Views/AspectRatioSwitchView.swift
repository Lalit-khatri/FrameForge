import SwiftUI

struct AspectRatioSwitchView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    // Read the project directly from the ViewModel (it holds a weak reference
    // set during attachProject). No need to pass it separately.
    private var project: Project? { viewModel.currentProject }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let project {
                    VStack(spacing: 24) {
                        currentPreview(project: project)
                        ratioGrid(project: project)
                        applyNote
                    }
                    .padding()
                } else {
                    Text("No project loaded")
                        .foregroundColor(.gray)
                }
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

    private func currentPreview(project: Project) -> some View {
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

    private func ratioGrid(project: Project) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(AspectRatio.allCases, id: \.self) { ratio in
                ratioCard(ratio, project: project)
            }
        }
    }

    private func ratioCard(_ ratio: AspectRatio, project: Project) -> some View {
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
