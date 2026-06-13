import SwiftUI

struct ToastMessage: Equatable {
    let icon: String
    let text: String
    // Each new toast gets a unique ID so SwiftUI treats it as a new view
    // and reliably fires .onAppear for the dismiss timer, even when toasts
    // arrive back-to-back.
    let id: UUID = UUID()

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastOverlay: View {
    @Binding var message: ToastMessage?

    // Track the dismiss task so rapid successive toasts cancel the old timer
    // and restart it — preventing early or missed dismissals.
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        if let toast = message {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: toast.icon)
                        .font(.body.bold())
                    Text(toast.text)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                .padding(.bottom, 100)
                .padding(.horizontal, 24)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // Use .id(toast.id) so SwiftUI treats each distinct toast as a
            // fresh view. This guarantees .onAppear fires for every new toast.
            .id(toast.id)
            .onAppear {
                scheduleDismiss()
            }
        }
    }

    private func scheduleDismiss() {
        // Cancel any pending dismiss from a previous toast
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)  // 2.5s
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    message = nil
                }
            }
        }
    }
}
