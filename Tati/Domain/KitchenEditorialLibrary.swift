import Foundation

struct CuratedClipEngagement: Decodable, Sendable {
    let likes: Int
    let comments: [FilmDiscussionReply]
}

struct EditorialFilmPoster: Decodable, Sendable {
    let movieURL: String
    let seconds: Double
}

struct KitchenEditorialLibrary: Decodable, Sendable {
    let portraits: [String: String]
    let additionalPeople: [TableMember]
    let roomCovers: [String: String]
    let clips: [FoodFilm]
    let roomClips: [String: FoodFilm]?
    let curatedEngagement: [String: CuratedClipEngagement]?
    let curatedRoomActivity: [String: [RoomConversationCue]]?
    let imageSources: [String: String]?
    let movieSources: [String: String]?
    let posterSources: [String: EditorialFilmPoster]?

    static func photographURL(for artwork: String) -> URL? {
        hostedURL(shared.imageSources?[artwork], folder: "photo")
    }

    static func movieURL(for resource: String) -> URL? {
        let name = movieResourceAliases[resource] ?? resource
        return hostedURL(shared.movieSources?[name], folder: "videos")
    }

    static func posterMovie(for artwork: String) -> (url: URL, seconds: Double)? {
        guard let poster = shared.posterSources?[artwork],
              let url = hostedURL(poster.movieURL, folder: "videos"),
              poster.seconds.isFinite, poster.seconds >= 0 else { return nil }
        return (url, poster.seconds)
    }

    private static func hostedURL(_ value: String?, folder: String) -> URL? {
        guard let value, let url = URL(string: value),
              url.scheme == "https", url.host == "pub-d00704a92e07453dbab85506699e0218.r2.dev",
              url.user == nil, url.password == nil,
              url.path.hasPrefix("/" + folder + "/") else { return nil }
        return url
    }

    static let movieResourceAliases: [String: String] = [
        "collection-osaka-sandwich.mp4": "osaka-beef-sandwich.mp4",
        "collection-bakery-dessert.mp4": "bakery-finish.mp4",
        "collection-cafe-break.mp4": "matcha-cafe-break.mp4",
        "collection-crispy-bites.mp4": "crispy-snack-pan.mp4",
        "collection-outdoor-noodles.mp4": "noodles-outdoors.mp4",
        "collection-toasted-sandwich.mp4": "toasted-bread-story.mp4",
        "collection-street-food-table.mp4": "market-spicy-snacks.mp4",
        "collection-kitchen-soup.mp4": "soup-counter.mp4",
        "collection-dumplings.mp4": "dumpling-table.mp4",
        "collection-dinner-friends.mp4": "coffee-with-friends.mp4",
        "collection-crepe-making.mp4": "french-toast-pan.mp4",
        "collection-trail-break.mp4": "fruit-on-the-trail.mp4",
        "collection-noodle-tasting.mp4": "noodle-tasting-table.mp4",
        "collection-cooking-together.mp4": "cooking-at-home.mp4",
    ]

    static var shared: KitchenEditorialLibrary {
        KitchenContentSnapshot.current?.catalog.editorial ?? KitchenEditorialLibrary(portraits: [:], additionalPeople: [], roomCovers: [:], clips: [], roomClips: nil, curatedEngagement: nil, curatedRoomActivity: nil, imageSources: nil, movieSources: nil, posterSources: nil)
    }

    static var unavailable: Bool { shared.portraits.isEmpty || shared.clips.isEmpty }
    static var activeFilmIDs: Set<String> { Set(shared.clips.map(\.id) + Array((shared.roomClips ?? [:]).values).map(\.id)) }
}
