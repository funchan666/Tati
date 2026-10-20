import Foundation

/// Read-only bundled media is separate from the visitor's editable local files.
struct ContentLibrary: Decodable {
    let portraits: [String: String]
    let additionalPeople: [FoodPerson]
    let roomCovers: [String: String]
    let clips: [FoodClip]

    static let shared: ContentLibrary = {
        guard let url = Bundle.main.url(forResource: "content-library", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(ContentLibrary.self, from: data) else {
            return ContentLibrary(portraits: [:], additionalPeople: [], roomCovers: [:], clips: [])
        }
        return library
    }()

    static var unavailable: Bool { shared.portraits.isEmpty || shared.clips.isEmpty }
}
