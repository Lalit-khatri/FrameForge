import SwiftUI

struct StickersView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: StickerCategory = .smileys
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var gifResults: [TenorGif] = []
    @State private var isSearchingGifs = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let tenorAPIKey = "AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ"

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()

                VStack(spacing: 0) {
                    tabPicker
                    if selectedTab == 0 {
                        categoryBar
                        stickerGrid
                    } else {
                        gifSearchBar
                        gifGrid
                    }
                }
            }
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .onAppear {
                if gifResults.isEmpty {
                    loadTrendingGifs()
                }
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            Button {
                selectedTab = 0
            } label: {
                Text("Emoji")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == 0 ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.clear)
                    .foregroundColor(selectedTab == 0 ? .white : .gray)
            }
            Button {
                selectedTab = 1
            } label: {
                Text("GIFs")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == 1 ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.clear)
                    .foregroundColor(selectedTab == 1 ? .white : .gray)
            }
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var gifSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search GIFs...", text: $searchText)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .onSubmit { searchGifs() }
        }
        .padding(10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(StickerCategory.allCases, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                        HapticManager.shared.selection()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.caption)
                            Text(category.rawValue)
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category
                            ? Color(red: 0.42, green: 0.36, blue: 0.91)
                            : Color.white.opacity(0.08)
                        )
                        .foregroundColor(
                            selectedCategory == category ? .white : .gray
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var filteredStickers: [String] {
        let stickers = selectedCategory.stickers
        guard !searchText.isEmpty else { return stickers }
        let query = searchText.lowercased()
        return stickers.filter { emoji in
            emojiDescription(emoji).lowercased().contains(query)
        }
    }

    private func emojiDescription(_ emoji: String) -> String {
        var names: [String] = []
        for scalar in emoji.unicodeScalars {
            if let name = scalar.properties.name {
                names.append(name)
            }
        }
        return names.joined(separator: " ")
    }

    private var stickerGrid: some View {
        ScrollView {
            if !searchText.isEmpty && selectedTab == 0 {
                let allFiltered = StickerCategory.allCases.flatMap { cat in
                    cat.stickers.filter { emoji in
                        emojiDescription(emoji).lowercased().contains(searchText.lowercased())
                    }
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(allFiltered, id: \.self) { emoji in
                        emojiButton(emoji)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredStickers, id: \.self) { emoji in
                        emojiButton(emoji)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search emoji...", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func emojiButton(_ emoji: String) -> some View {
        Button {
            viewModel.addSticker(emoji: emoji)
            HapticManager.shared.medium()
            dismiss()
        } label: {
            Text(emoji)
                .font(.system(size: 36))
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
        }
    }

    private var gifGrid: some View {
        ScrollView {
            if isSearchingGifs {
                ProgressView()
                    .tint(.gray)
                    .padding(.top, 40)
            } else if gifResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No results")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
            } else if gifResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.4))
                    Text("Loading GIFs...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
            } else {
                let gifColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                LazyVGrid(columns: gifColumns, spacing: 8) {
                    ForEach(gifResults) { gif in
                        AsyncImage(url: URL(string: gif.previewURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 100)
                                    .clipped()
                                    .cornerRadius(10)
                            case .failure:
                                Color.gray.opacity(0.2)
                                    .frame(height: 100)
                                    .cornerRadius(10)
                                    .overlay(
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.gray)
                                    )
                            default:
                                Color.gray.opacity(0.1)
                                    .frame(height: 100)
                                    .cornerRadius(10)
                                    .overlay(ProgressView().tint(.gray))
                            }
                        }
                        .onTapGesture {
                            viewModel.addSticker(emoji: gif.contentDescription, gifURL: gif.previewURL)
                            HapticManager.shared.medium()
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }

            HStack {
                Text("Powered by Tenor")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.bottom, 8)
        }
    }

    private func searchGifs() {
        guard !searchText.isEmpty else { return }
        isSearchingGifs = true
        let query = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText
        let urlString = "https://tenor.googleapis.com/v2/search?q=\(query)&key=\(tenorAPIKey)&client_key=frameforge&limit=30"

        guard let url = URL(string: urlString) else {
            isSearchingGifs = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isSearchingGifs = false
                guard let data = data, error == nil else { return }
                if let response = try? JSONDecoder().decode(TenorResponse.self, from: data) {
                    gifResults = response.results
                }
            }
        }.resume()
    }

    private func loadTrendingGifs() {
        isSearchingGifs = true
        let urlString = "https://tenor.googleapis.com/v2/featured?key=\(tenorAPIKey)&client_key=frameforge&limit=30"

        guard let url = URL(string: urlString) else {
            isSearchingGifs = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isSearchingGifs = false
                guard let data = data, error == nil else { return }
                if let response = try? JSONDecoder().decode(TenorResponse.self, from: data) {
                    gifResults = response.results
                }
            }
        }.resume()
    }
}

struct TenorResponse: Codable {
    let results: [TenorGif]
}

struct TenorGif: Codable, Identifiable {
    let id: String
    let title: String
    let contentDescription: String
    let mediaFormats: [String: TenorMediaFormat]

    var previewURL: String {
        mediaFormats["tinygif"]?.url ?? mediaFormats["nanogif"]?.url ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case contentDescription = "content_description"
        case mediaFormats = "media_formats"
    }
}

struct TenorMediaFormat: Codable {
    let url: String
    let dims: [Int]?
    let duration: Double?
    let size: Int?
}
