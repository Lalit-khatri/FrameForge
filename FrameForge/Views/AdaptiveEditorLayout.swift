import SwiftUI

struct AdaptiveEditorLayout: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
    }

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Color(white: 0.12)
                    .frame(maxHeight: .infinity)
                    .overlay(
                        Text("Preview")
                            .foregroundColor(.gray)
                    )
            }
            .frame(maxWidth: .infinity)

            Divider()
                .background(Color.white.opacity(0.1))

            VStack(spacing: 0) {
                TimelineView(viewModel: viewModel)
                    .frame(maxHeight: .infinity)
                ToolbarView(viewModel: viewModel, onAddMedia: { viewModel.showMediaPicker = true })
                    .frame(height: 80)
            }
            .frame(width: 420)
        }
    }

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            Color(white: 0.12)
                .frame(maxHeight: .infinity)
                .overlay(
                    Text("Preview")
                        .foregroundColor(.gray)
                )
            TimelineView(viewModel: viewModel)
                .frame(height: 200)
            ToolbarView(viewModel: viewModel, onAddMedia: { viewModel.showMediaPicker = true })
                .frame(height: 80)
        }
    }
}
