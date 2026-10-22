import Foundation

/// Editorial interaction content for bundled videos, not server engagement statistics.
struct CuratedClipEngagement: Decodable {
    let likes: Int
    let comments: [FilmDiscussionReply]
}

/// Read-only bundled media is separate from the visitor's editable local files.
struct KitchenEditorialLibrary: Decodable {
    let portraits: [String: String]
    let additionalPeople: [TableMember]
    let roomCovers: [String: String]
    let clips: [FoodFilm]
    let roomClips: [String: FoodFilm]?
    let curatedEngagement: [String: CuratedClipEngagement]?
    let curatedRoomActivity: [String: [RoomConversationCue]]?

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

    static let shared: KitchenEditorialLibrary = {
        guard let url = Bundle.main.url(forResource: "table-editorial-content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(KitchenEditorialLibrary.self, from: data) else {
            return KitchenEditorialLibrary(portraits: [:], additionalPeople: [], roomCovers: [:], clips: [], roomClips: nil, curatedEngagement: nil, curatedRoomActivity: nil)
        }
        return library
    }()

    static var unavailable: Bool { shared.portraits.isEmpty || shared.clips.isEmpty }
    static let activeFilmIDs = Set(shared.clips.map(\.id) + Array((shared.roomClips ?? [:]).values).map(\.id))
}
