import SwiftUI

struct SplitScreenView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLayout: SplitLayout = .halfHorizontal

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    layoutPreview

                    Text("Select Layout")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(SplitLayout.allCases, id: \.self) { layout in
                            Button(action: {
                                selectedLayout = layout
                                HapticManager.shared.light()
                            }) {
                                VStack(spacing: 6) {
                                    layout.preview
                                        .frame(width: 60, height: 40)
                                    Text(layout.label)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(selectedLayout == layout ? .white : .gray)
                                }
                                .padding(8)
                                .background(
                                    selectedLayout == layout
                                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                        : Color.white.opacity(0.06)
                                )
                                .cornerRadius(10)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Split Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applySplitScreen()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var layoutPreview: some View {
        selectedLayout.preview
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func applySplitScreen() {
        viewModel.saveState()
        HapticManager.shared.success()
    }
}

enum SplitLayout: String, CaseIterable {
    case halfHorizontal, halfVertical, thirds
    case quadrant, pipOverlay, diagonal

    var label: String {
        switch self {
        case .halfHorizontal: return "50/50 H"
        case .halfVertical: return "50/50 V"
        case .thirds: return "Thirds"
        case .quadrant: return "Quadrant"
        case .pipOverlay: return "PiP"
        case .diagonal: return "Diagonal"
        }
    }

    var preview: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                switch self {
                case .halfHorizontal:
                    VStack(spacing: 2) {
                        Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                        Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                    }
                case .halfVertical:
                    HStack(spacing: 2) {
                        Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                        Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                    }
                case .thirds:
                    HStack(spacing: 2) {
                        Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                        Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                        Color.green.opacity(0.5)
                    }
                case .quadrant:
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                            Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                        }
                        HStack(spacing: 2) {
                            Color.green.opacity(0.5)
                            Color.orange.opacity(0.5)
                        }
                    }
                case .pipOverlay:
                    ZStack(alignment: .bottomTrailing) {
                        Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.5)
                        Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.8)
                            .frame(width: w * 0.35, height: h * 0.35)
                            .cornerRadius(4)
                            .padding(4)
                    }
                case .diagonal:
                    Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.7)
                        .overlay(
                            Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)
                                .clipShape(Triangle())
                        )
                }
            }
            .cornerRadius(4)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
