import SwiftUI
import PhotosUI

struct PhotoImportView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var importedPhotos: [ImportedPhoto] = []
    @State private var photoDuration: Double = 5.0
    @State private var enableKenBurns = true
    @State private var kenBurnsIntensity: Double = 0.3

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 20,
                        matching: .images
                    ) {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                            Text("Select Photos")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("\(importedPhotos.count) photos selected")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.4))
                                )
                        )
                    }
                    .onChange(of: selectedItems) { _, newItems in
                        loadPhotos(newItems)
                    }

                    if !importedPhotos.isEmpty {
                        photoGrid

                        durationControl

                        kenBurnsControl
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Import Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Timeline") {
                        addPhotosToTimeline()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                    .disabled(importedPhotos.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var photoGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(importedPhotos) { photo in
                    if let img = photo.image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.42, green: 0.36, blue: 0.91), lineWidth: 2)
                            )
                    }
                }
            }
        }
    }

    private var durationControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Photo Duration")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.1fs", photoDuration))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: $photoDuration, in: 1.0...15.0, step: 0.5)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var kenBurnsControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $enableKenBurns) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    Text("Ken Burns Effect")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }
            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))

            if enableKenBurns {
                HStack {
                    Text("Subtle")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Slider(value: $kenBurnsIntensity, in: 0.1...0.6)
                        .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                    Text("Strong")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        importedPhotos.removeAll()
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data = data,
                   let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        importedPhotos.append(ImportedPhoto(image: uiImage, data: data))
                    }
                }
            }
        }
    }

    private func addPhotosToTimeline() {
        for photo in importedPhotos {
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "\(UUID().uuidString).jpg"
            let url = tempDir.appendingPathComponent(filename)
            try? photo.data.write(to: url)

            var clip = TimelineClip(
                assetURL: url,
                startTime: viewModel.totalDuration,
                duration: photoDuration,
                originalDuration: photoDuration
            )
            clip.thumbnailData = photo.image?.jpegData(compressionQuality: 0.3)

            if let trackIdx = viewModel.tracks.firstIndex(where: { $0.type == .video }) {
                viewModel.tracks[trackIdx].clips.append(clip)
            }
        }
        viewModel.recalculateStartTimes()
        Task { await viewModel.rebuildComposition() }
        viewModel.saveProject()
        HapticManager.shared.success()
    }
}

struct ImportedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage?
    let data: Data
}
