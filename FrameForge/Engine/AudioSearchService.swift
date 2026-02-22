import Foundation

struct AudioSearchResult: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let previewURL: URL?
    let artworkURL: URL?
    let duration: TimeInterval
}

protocol AudioSearchProvider {
    func search(query: String) async throws -> [AudioSearchResult]
}

final class ITunesSearchProvider: AudioSearchProvider {
    func search(query: String) async throws -> [AudioSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&media=music&limit=25"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)

        return response.results.compactMap { item in
            AudioSearchResult(
                id: "\(item.trackId)",
                title: item.trackName,
                artist: item.artistName,
                previewURL: URL(string: item.previewUrl ?? ""),
                artworkURL: URL(string: item.artworkUrl100 ?? ""),
                duration: (item.trackTimeMillis ?? 0) / 1000.0
            )
        }
    }
}

private struct ITunesSearchResponse: Codable {
    let resultCount: Int
    let results: [ITunesTrack]
}

private struct ITunesTrack: Codable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let previewUrl: String?
    let artworkUrl100: String?
    let trackTimeMillis: Double?
}
