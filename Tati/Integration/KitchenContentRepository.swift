import Foundation
import Combine
import os

struct CookingPrompt: Decodable, Sendable { let title: String; let question: String }
struct CookingAnswerRule: Decodable, Sendable { let topic: String; let keywords: [String] }
struct KitchenProfileDefaults: Decodable, Sendable { let name: String; let bio: String; let country: String; let interest: String }
struct TableCatalogPayload: Decodable, Sendable {
    let members: [TableMember]
    let rooms: [CookingRoom]
    let celebrations: [TableCelebration]
    let cities: [String]
    let languages: [String]
    let topics: [String]
    struct PopularTopic: Decodable, Sendable { let title: String; let artwork: String }
    let popularTopics: [PopularTopic]
    let editorial: KitchenEditorialLibrary
}
struct CookingNotebookPayload: Decodable, Sendable { let chapters: [RecipeChapter]; let recipes: [KitchenRecipe] }
struct KitchenOffersPayload: Decodable, Sendable {
    let coinPacks: [KitchenCoinPack]
    let answers: [String: String]
    let answerRules: [CookingAnswerRule]
    let prompts: [CookingPrompt]
    let supportArticles: [HelpArticle]
    let welcomeCoins: Int
    let frameCost: Int
    let profileDefaults: KitchenProfileDefaults
}
struct KitchenContentSnapshot: Sendable {
    private static let storage = OSAllocatedUnfairLock(initialState: Optional<KitchenContentSnapshot>.none)
    static fileprivate(set) var current: KitchenContentSnapshot? {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
    let catalog: TableCatalogPayload
    let notebook: CookingNotebookPayload
    let offers: KitchenOffersPayload
    func validate() throws {
        func unique(_ ids: [String]) throws { guard ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count else { throw KitchenServiceFailure.configuration } }
        try unique(catalog.members.map(\.id)); try unique(catalog.rooms.map(\.id)); try unique(catalog.celebrations.map(\.id))
        try unique(offers.supportArticles.map(\.id))
        try unique(notebook.recipes.map(\.id)); try unique(notebook.chapters.map(\.id)); try unique(offers.coinPacks.map(\.id))
        let people = Set(catalog.members.map(\.id)), chapters = Set(notebook.chapters.map(\.id))
        let editorial = catalog.editorial
        guard let images = editorial.imageSources, let movies = editorial.movieSources, let posters = editorial.posterSources,
              let roomClips = editorial.roomClips, let engagement = editorial.curatedEngagement, let activity = editorial.curatedRoomActivity else { throw KitchenServiceFailure.configuration }
        let films = editorial.clips + Array(roomClips.values)
        for (clipID, item) in engagement {
            try unique(item.comments.map(\.id))
            guard item.comments.allSatisfy({ $0.clipID == clipID }) else { throw KitchenServiceFailure.configuration }
        }
        for cues in activity.values { try unique(cues.map(\.id)) }
        try unique(films.map(\.id))
        func hosted(_ value: String, _ folder: String) -> Bool {
            guard let url = URL(string: value) else { return false }
            return url.scheme == "https" && url.host == "pub-d00704a92e07453dbab85506699e0218.r2.dev" && url.user == nil && url.password == nil && url.path.hasPrefix("/" + folder + "/")
        }
        guard images.values.allSatisfy({ hosted($0, "photo") }), movies.values.allSatisfy({ hosted($0, "videos") }), posters.values.allSatisfy({ hosted($0.movieURL, "videos") && $0.seconds.isFinite && $0.seconds >= 0 }),
              catalog.members.allSatisfy({ !$0.name.isEmpty }),
              editorial.portraits.allSatisfy({ people.contains($0.key) && images[$0.value] != nil }),
              editorial.roomCovers.allSatisfy({ Set(catalog.rooms.map(\.id)).contains($0.key) && (images[$0.value] != nil || posters[$0.value] != nil) }),
              catalog.celebrations.allSatisfy({ $0.cost > 0 && $0.cost <= Int.max / 99 }),
              notebook.chapters.allSatisfy({ $0.coinCost > 0 }),
              catalog.rooms.allSatisfy({ people.contains($0.hostID) && !$0.title.isEmpty && $0.initialAudienceCount >= 0 }),
              Set(roomClips.keys).isSubset(of: Set(catalog.rooms.map(\.id))),
              films.allSatisfy({ people.contains($0.authorID) && $0.packagedMovieName.flatMap({ movies[$0] }) != nil && $0.posterAssetName.flatMap({ posters[$0] }) != nil }),
              Set(engagement.keys).isSubset(of: Set(films.map(\.id))),
              engagement.values.allSatisfy({ $0.likes >= 0 && $0.comments.allSatisfy({ people.contains($0.authorID) }) }),
              Set(activity.keys).isSubset(of: Set(catalog.rooms.map(\.id))),
              activity.values.flatMap({ $0 }).allSatisfy({ cue in people.contains(cue.authorID) && cue.quantity > 0 && (cue.giftID == nil || catalog.celebrations.contains(where: { $0.id == cue.giftID })) }),
              notebook.recipes.allSatisfy({ $0.baseServings > 0 && $0.activeMinutes > 0 && ($0.chapterID == nil || chapters.contains($0.chapterID!)) && !$0.methodSteps.isEmpty && $0.pantryLines.allSatisfy({ $0.baseQuantity.isFinite && $0.baseQuantity > 0 }) }),
              offers.coinPacks.allSatisfy({ $0.coins > 0 && Decimal(string: $0.usdPrice) != nil }),
              offers.welcomeCoins >= 0, offers.frameCost > 0,
              Set(offers.answers.keys).isSubset(of: Set(["crispy", "plating", "balance", "pasta", "dinner", "baking", "vegetables", "clarify"])),
              offers.answers.values.allSatisfy({ !$0.isEmpty }), offers.answerRules.allSatisfy({ offers.answers[$0.topic] != nil && !$0.keywords.isEmpty }) else { throw KitchenServiceFailure.configuration }
    }
}

@MainActor
final class KitchenContentRepository: ObservableObject {
    @Published private(set) var loading = false
    @Published private(set) var failure = false
    @Published private(set) var loaded = false
    private var generation = UUID()
    private var task: Task<Void, Never>?
    weak var store: MemberKitchenStore?
    var didInstall: (() -> Void)?
    func clear() {
        generation = UUID(); task?.cancel(); task = nil
        KitchenContentSnapshot.current = nil; loaded = false; loading = false; failure = false
        store?.contentDidChange()
    }
    func reload() {
        clear(); loading = true
        let captured = generation
        task = Task {
            do {
                async let catalog: TableCatalogPayload = fetch(ConfiguredContentPaths.tableCatalog)
                async let notebook: CookingNotebookPayload = fetch(ConfiguredContentPaths.cookingNotebook)
                async let offers: KitchenOffersPayload = fetch(ConfiguredContentPaths.kitchenOffers)
                let snapshot = try await KitchenContentSnapshot(catalog: catalog, notebook: notebook, offers: offers)
                try Task.checkCancellation(); try snapshot.validate()
                guard generation == captured else { return }
                KitchenContentSnapshot.current = snapshot; loading = false; loaded = true; failure = false
                store?.contentDidChange(); didInstall?()
            } catch {
                guard generation == captured, !Task.isCancelled else { return }
                loading = false; loaded = false; failure = true
                store?.contentDidChange()
            }
        }
    }
    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let (bytes, http) = try await KitchenHTTP.shared.post(path, object: [:])
        guard (200...299).contains(http.statusCode), let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any], ConfiguredRealtimeJSON.integer(object[ConfiguredWireFields.code]) == 0, let data = object[ConfiguredWireFields.data], data is [String: Any] else { throw KitchenServiceFailure.response }
        return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: data))
    }
}
