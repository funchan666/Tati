import Foundation

/// Editorial interaction content for bundled videos, not server engagement statistics.
struct CuratedClipEngagement: Decodable {
    let likes: Int
    let comments: [VideoComment]
}

/// Read-only bundled media is separate from the visitor's editable local files.
struct ContentLibrary: Decodable {
    let portraits: [String: String]
    let additionalPeople: [FoodPerson]
    let roomCovers: [String: String]
    let clips: [FoodClip]
    let roomClips: [String: FoodClip]?
    let curatedEngagement: [String: CuratedClipEngagement]?

    static let shared: ContentLibrary = {
        guard let url = Bundle.main.url(forResource: "content-library", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(ContentLibrary.self, from: data) else {
            return ContentLibrary(portraits: [:], additionalPeople: [], roomCovers: [:], clips: [], roomClips: nil, curatedEngagement: nil)
        }
        return library
    }()

    static var unavailable: Bool { shared.portraits.isEmpty || shared.clips.isEmpty }
}
