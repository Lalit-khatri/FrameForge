import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct AudioBrowserView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var searchResults: [AudioSearchResult] = []
    @State private var isSearching = false
    @State private var previewPlayer: AVPlayer?
    @State private var playingPreviewID: String?
    @State private var showDocumentPicker = false

    private let searchProvider = ITunesSearchProvider()
    private let defaultTerms = ["Top Hits 2025", "trending", "popular music", "hip hop", "chill vibes"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabSelector

                    switch selectedTab {
                    case 0: filesTab
                    case 1: iTunesTab
                    default: filesTab
                    }
                }
            }
            .navigationTitle("Add Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopPreview()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { urls in
                    for url in urls {
                        Task {
                            await viewModel.addAudioFromURL(url)
                        }
                    }
                    dismiss()
                }
            }
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("Files", index: 0, icon: "folder.fill")
            tabButton("iTunes", index: 1, icon: "music.note.list")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func tabButton(_ title: String, index: Int, icon: String) -> some View {
        Button {
            selectedTab = index
            stopPreview()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                selectedTab == index
                ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.3)
                : Color.clear
            )
            .cornerRadius(12)
        }
    }

    private var filesTab: some View {
        VStack(spacing: 20) {
            Spacer()

            Button {
                showDocumentPicker = true
            } label: {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                         Color(red: 0.99, green: 0.32, blue: 0.56)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 72, height: 72)
                        Image(systemName: "folder.badge.plus")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Text("Import from Files")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("MP3, WAV, M4A, AAC")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(20)
    }

    private var iTunesTab: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search songs...", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .onSubmit { performSearch() }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        loadDefaultSongs()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if isSearching {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                Spacer()
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No results found")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(searchResults) { result in
                            audioResultRow(result)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .onAppear {
            if searchResults.isEmpty && searchText.isEmpty {
                loadDefaultSongs()
            }
        }
    }

    private func audioResultRow(_ result: AudioSearchResult) -> some View {
        HStack(spacing: 12) {
            if let artworkURL = result.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .cornerRadius(8)
                    default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(result.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                Text(formatDuration(result.duration))
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.7))
            }

            Spacer()

            if result.previewURL != nil {
                Button {
                    togglePreview(result)
                } label: {
                    Image(systemName: playingPreviewID == result.id ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }

            Button {
                importPreview(result)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.1))
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.gray)
            )
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        Task {
            do {
                searchResults = try await searchProvider.search(query: searchText)
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }

    private func togglePreview(_ result: AudioSearchResult) {
        if playingPreviewID == result.id {
            stopPreview()
        } else {
            stopPreview()
            guard let url = result.previewURL else { return }
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            previewPlayer = AVPlayer(url: url)
            previewPlayer?.play()
            playingPreviewID = result.id
        }
    }

    private func stopPreview() {
        previewPlayer?.pause()
        previewPlayer = nil
        playingPreviewID = nil
    }

    private func importPreview(_ result: AudioSearchResult) {
        guard let url = result.previewURL else { return }
        stopPreview()

        Task {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "\(result.id)_\(result.title.replacingOccurrences(of: " ", with: "_")).m4a"
            let destURL = tempDir.appendingPathComponent(fileName)

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: destURL)
                await viewModel.addAudioFromURL(destURL)
                await MainActor.run {
                    dismiss()
                }
            } catch {}
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func loadDefaultSongs() {
        isSearching = true
        Task {
            do {
                let term = defaultTerms.randomElement() ?? "popular"
                searchResults = try await searchProvider.search(query: term)
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.mp3, .wav, .aiff, .audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
