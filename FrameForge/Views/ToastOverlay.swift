import SwiftUI

struct ToastMessage: Equatable {
    let icon: String
    let text: String
}

struct ToastOverlay: View {
    @Binding var message: ToastMessage?

    var body: some View {
        if let toast = message {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: toast.icon)
                        .font(.body.bold())
                    Text(toast.text)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        message = nil
                    }
                }
            }
        }
    }
}
