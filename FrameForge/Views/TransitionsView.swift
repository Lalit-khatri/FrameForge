import SwiftUI

struct TransitionsView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTransitionID: String = "none"
    @State private var duration: Double = 0.5

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        HStack {
                            Text("Duration")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1fs", duration))
                                .font(.subheadline)
                                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                        }
                        .padding(.horizontal)

                        Slider(value: $duration, in: 0.1...2.0, step: 0.1)
                            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                            .padding(.horizontal)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(TransitionType.allTransitions) { transition in
                                transitionCard(transition)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Transitions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let clipID = viewModel.selectedClipID {
                            viewModel.setTransition(selectedTransitionID, forClip: clipID, duration: duration)
                        }
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func transitionCard(_ transition: TransitionType) -> some View {
        let isSelected = selectedTransitionID == transition.id
        return Button(action: {
            selectedTransitionID = transition.id
            HapticManager.shared.selection()
        }) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected
                              ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.3)
                              : Color.white.opacity(0.06))
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.clear, lineWidth: 2)
                        )
                    Image(systemName: transition.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? Color(red: 0.42, green: 0.36, blue: 0.91) : .gray)
                }

                Text(transition.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                    .lineLimit(1)
            }
        }
    }
}
