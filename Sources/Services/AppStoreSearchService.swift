import Foundation
import Combine

public struct OnlineAppSearchResult: Identifiable, Hashable {
    public var id: String { bundleId }
    public let trackId: Int
    public let appName: String
    public let bundleId: String
    public let iconURL: URL?
    public let artistName: String
    public let priceFormatted: String
    public let genres: [String]
}

public final class AppStoreSearchService: ObservableObject {
    public static let shared = AppStoreSearchService()

    @Published public private(set) var searchResults: [OnlineAppSearchResult] = []
    @Published public private(set) var isSearching = false
    @Published public private(set) var lastError: String?

    private init() {}

    public func clear() {
        searchResults = []
        lastError = nil
    }

    /// Searches Apple's public iTunes Search API. If the query is an App
    /// Store URL or an `id123…` token, the lookup endpoint is used so bundle
    /// IDs remain stable.
    public func searchAppStore(query: String, country: String = "vn") {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { clear(); return }
        isSearching = true
        lastError = nil

        let numericID = Self.extractNumericAppID(from: trimmed)
        var components: URLComponents
        if let numericID {
            components = URLComponents(string: "https://itunes.apple.com/lookup")!
            components.queryItems = [URLQueryItem(name: "id", value: numericID), URLQueryItem(name: "country", value: country)]
        } else {
            components = URLComponents(string: "https://itunes.apple.com/search")!
            components.queryItems = [
                URLQueryItem(name: "term", value: trimmed),
                URLQueryItem(name: "entity", value: "software"),
                URLQueryItem(name: "country", value: country),
                URLQueryItem(name: "limit", value: "25")
            ]
        }

        guard let url = components.url else {
            isSearching = false
            lastError = "Query không hợp lệ"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async { self.isSearching = false }
            if let error {
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
                return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data else {
                DispatchQueue.main.async { self.lastError = "App Store trả về lỗi mạng" }
                return
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let results = object?["results"] as? [[String: Any]] ?? []
                let mapped = results.compactMap(Self.mapResult)
                DispatchQueue.main.async { self.searchResults = mapped }
            } catch {
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
            }
        }.resume()
    }

    private static func extractNumericAppID(from query: String) -> String? {
        let pattern = #"(?:^|/)(?:id)?([0-9]{7,})(?:\?|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let range = Range(match.range(at: 1), in: query) else { return nil }
        return String(query[range])
    }

    private static func mapResult(_ object: [String: Any]) -> OnlineAppSearchResult? {
        guard let bundleID = object["bundleId"] as? String, !bundleID.isEmpty else { return nil }
        let iconString = object["artworkUrl100"] as? String
        return OnlineAppSearchResult(
            trackId: object["trackId"] as? Int ?? 0,
            appName: object["trackName"] as? String ?? bundleID,
            bundleId: bundleID,
            iconURL: iconString.flatMap(URL.init(string:)),
            artistName: object["artistName"] as? String ?? "",
            priceFormatted: object["formattedPrice"] as? String ?? "Miễn phí",
            genres: object["genres"] as? [String] ?? []
        )
    }
}
