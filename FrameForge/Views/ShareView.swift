import SwiftUI

struct ShareView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var exportedURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var shareFormat: ShareFormat = .project

    enum ShareFormat: String, CaseIterable {
        case project = "Project File"
        case video = "Rendered Video"
        case link = "Copy Link"

        var icon: String {
            switch self {
            case .project: return "doc.fill"
            case .video: return "film"
            case .link: return "link"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))

                    Text("Share Project")
                        .font(.headline)
                        .foregroundColor(.white)

                    VStack(spacing: 8) {
                        ForEach(ShareFormat.allCases, id: \.self) { format in
                            Button(action: { shareFormat = format }) {
                                HStack {
                                    Image(systemName: format.icon)
                                        .frame(width: 24)
                                    Text(format.rawValue)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    if shareFormat == format {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                                    }
                                }
                                .padding()
                                .background(
                                    shareFormat == format
                                    ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.15)
                                    : Color.white.opacity(0.04)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if isExporting {
                        ProgressView()
                            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                    }

                    Button(action: { shareProject() }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
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
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 12)
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheetView(items: [url])
            }
        }
    }

    private func shareProject() {
        guard let project = viewModel.currentProject else { return }

        switch shareFormat {
        case .project:
            isExporting = true
            Task {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(project) {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(project.name).frameforge")
                    try? data.write(to: url)
                    exportedURL = url
                    showShareSheet = true
                }
                isExporting = false
            }
        case .video:
            UIPasteboard.general.string = "frameforge://project/\(project.id.uuidString)"
            HapticManager.shared.success()
        case .link:
            UIPasteboard.general.string = "frameforge://project/\(project.id.uuidString)"
            HapticManager.shared.light()
        }
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
