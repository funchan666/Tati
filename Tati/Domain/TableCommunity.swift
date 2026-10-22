import Foundation

enum ConversationBackdrop: String, CaseIterable, Identifiable {
    case blue = "stage-blue"
    case gifts = "stage-gifts"
    case purple = "stage-purple"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .blue: return "Blue stage"
        case .gifts: return "Party curtain"
        case .purple: return "Purple lights"
        }
    }
}

struct TableMember: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let country: String
    let language: String
    let interest: String
    let bio: String
    var portraitArtwork: String? { KitchenEditorialLibrary.shared.portraits[id] }
    var locationLabel: String? {
        let place = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = country.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty, place != "Tati collection" else { return nil }
        return place == region || region.isEmpty ? place : "\(place) · \(region)"
    }
    let cityName: String
    var city: String { cityName }
}
struct CookingRoom: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let hostID: String
    let title: String
    let topic: String
    let isVoice: Bool
    let background: String

    let summaryText: String
    let initialAudienceCount: Int
    var coverArtwork: String? { KitchenEditorialLibrary.shared.roomCovers[id] }
    var videoClip: FoodFilm? { KitchenEditorialLibrary.shared.roomClips?[id] }
    var foodFocused: Bool { topic != "Home cooking" }
}
struct FoodFilm: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var authorID: String
    var dishCaption: String
    var recordedMovieFile: String?
    var createdAt: Date
    var isEditorial: Bool
    var packagedMovieName: String? = nil
    var posterAssetName: String? = nil

    var publicationReviewState: String? = nil
    var isHouseCollection: Bool { authorID == "tati-collection" }
    private enum CodingKeys: String, CodingKey {
        case id
        case authorID
        case dishCaption = "caption"
        case recordedMovieFile = "fileName"
        case createdAt
        case isEditorial = "isSample"
        case packagedMovieName = "bundledFile"
        case posterAssetName = "posterArtwork"
        case publicationReviewState = "moderationStatus"
    }

}
struct TableCelebration: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let name: String
    let artwork: String
    let cost: Int
}
struct ConversationOutboxItem: Identifiable, Codable {
    var id = UUID().uuidString
    var recipientID: String
    var text: String
    var createdAt = Date()

    var status = "Draft · not sent"
    var senderID: String? = nil
    var imageFile: String? = nil
}
struct FilmDiscussionReply: Identifiable, Codable, Sendable {
    var id = UUID().uuidString
    var clipID: String
    var authorID: String
    var text: String
    var createdAt = Date()
    var isCurated: Bool? = nil
}
struct RoomEffectPurchase: Identifiable, Codable {
    var id = UUID().uuidString
    var giftID: String
    var recipientID: String
    var quantity: Int
    var spent: Int
    var date = Date()
    var roomID: String? = nil
}
struct RoomConversationEntry: Identifiable, Codable {
    var id = UUID().uuidString
    var roomID: String
    var text: String
    var createdAt = Date()
}
struct RoomConversationCue: Identifiable, Codable, Sendable {
    var id: String
    var authorID: String
    var text: String
    var giftID: String? = nil
    var quantity = 1
    var isEditorial = true

    var delaySeconds: Double? = nil
    private enum CodingKeys: String, CodingKey {
        case id
        case authorID
        case text
        case giftID
        case quantity
        case isEditorial = "isSample"
        case delaySeconds
    }

}

struct CommunitySafetyRecord: Identifiable, Codable {
    var id = UUID().uuidString
    var subjectID: String
    var reason: String
    var details: String
    var imageFile: String? = nil
    var date = Date()
    var recorded: Bool? = nil
    var authorID: String? = nil
    var contextID: String? = nil
}
struct MemberKitchenProfile: Codable {
    var id = UUID().uuidString
    var name = ""
    var bio = ""
    var country = ""
    var interest = ""
    var avatarFile: String?
    var coverFile: String?
}
struct CoinPurchaseIntent: Codable {
    let token: UUID
    let ownerID: String
    let productID: String
    let coins: Int
    let createdAt: Date
}
struct CoinPurchaseCredit: Codable {
    let transactionID: String
    let token: UUID
    let ownerID: String
    let productID: String
    let coins: Int
    let creditedAt: Date
    var revoked = false
}
struct KitchenCoinExpense: Codable, Identifiable {
    var id = UUID().uuidString
    let title: String
    let coins: Int
    var date = Date()
}
struct CookingQuestionExchange: Codable, Identifiable {
    var id = UUID().uuidString
    let question: String
    var reply: CookingNoteTopic? = nil
    var createdAt = Date()
}

enum CookingNoteTopic: String, Codable {
    case crispy, plating, balance, pasta, dinner, baking, vegetables, clarify

    var answer: String { KitchenContentSnapshot.current?.offers.answers[rawValue] ?? "" }
    static func matching(_ question: String) -> Self {
        let text = question.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        var result: Self = .clarify
        var score = 0
        for rule in KitchenContentSnapshot.current?.offers.answerRules ?? [] {
            let matches = rule.keywords.filter { text.contains($0) }.count
            if matches > score, let topic = Self(rawValue: rule.topic) { result = topic; score = matches }
        }
        return result
    }

}

struct MemberKitchenState: Codable {
    var recipeChapterUnlocks: Set<String>? = nil
    var pantryShoppingList: [PantryChecklistLine]? = nil
    var cookingTrialNotes: [CookingTrialNote]? = nil
    var tableSyncState: KitchenThemeState? = nil
    var version = 1
    var profile = MemberKitchenProfile()
    var signedIn = false
    var following: Set<String> = []

    var followers: Set<String>? = nil
    var hiddenSubjects: Set<String>? = nil
    var blocked: Set<String> = []
    var likes: Set<String> = []
    var rewardCoins = 0
    var purchasedCoins = 0
    var claimedDays: Set<String> = []
    var gifts: [RoomEffectPurchase] = []
    var roomMessages: [RoomConversationEntry]? = nil
    var drafts: [String: String] = [:]
    var foodExpertExchanges: [CookingQuestionExchange]? = nil
    var messages: [ConversationOutboxItem] = []
    var videoComments: [FilmDiscussionReply]? = nil
    var reports: [CommunitySafetyRecord] = []
    var clips: [FoodFilm] = []
    var notifications = false
    var preferredLanguage: String? = nil
    var draftImages: [String: String]? = nil
    var roomBackgrounds: [String: String] = [:]
    var roomLayouts: [String: String] = [:]
    var processedTransactions: Set<String> = []
    var purchaseOwnerByProduct: [String: String] = [:]
    var equippedFrame = false
    var frameUnlocked: Bool? = false
    var welcomeGranted: Bool? = false
    var welcomeAcknowledged: Bool? = false
    var purchaseIntents: [String: CoinPurchaseIntent]? = [:]
    var purchaseCredits: [String: CoinPurchaseCredit]? = [:]
    var purchaseDebt: Int? = 0
    var coinExpenses: [KitchenCoinExpense]? = []
    private enum CodingKeys: String, CodingKey {
        case recipeChapterUnlocks
        case pantryShoppingList
        case cookingTrialNotes
        case tableSyncState
        case version
        case profile
        case signedIn
        case following
        case followers
        case hiddenSubjects
        case blocked
        case likes
        case rewardCoins = "demoCoins"
        case purchasedCoins
        case claimedDays
        case gifts
        case roomMessages
        case drafts
        case foodExpertExchanges
        case messages
        case videoComments
        case reports
        case clips
        case notifications
        case preferredLanguage
        case draftImages
        case roomBackgrounds
        case roomLayouts
        case processedTransactions
        case purchaseOwnerByProduct
        case equippedFrame
        case frameUnlocked
        case welcomeGranted
        case welcomeAcknowledged
        case purchaseIntents
        case purchaseCredits
        case purchaseDebt
        case coinExpenses
    }

}

enum TableCommunity {
    static var people: [TableMember] { KitchenContentSnapshot.current?.catalog.members ?? [] }
    static var rooms: [CookingRoom] { KitchenContentSnapshot.current?.catalog.rooms ?? [] }
    static var gifts: [TableCelebration] { KitchenContentSnapshot.current?.catalog.celebrations ?? [] }
    static var cities: [String] { KitchenContentSnapshot.current?.catalog.cities ?? [] }
    static var languages: [String] { KitchenContentSnapshot.current?.catalog.languages ?? [] }
    static var topics: [String] { KitchenContentSnapshot.current?.catalog.topics ?? [] }
    static var popularTopics: [(String, String)] { (KitchenContentSnapshot.current?.catalog.popularTopics ?? []).map { ($0.title, $0.artwork) } }
    static var editorialFilms: [FoodFilm] { KitchenEditorialLibrary.shared.clips }
    static var editorialFilmIDs: Set<String> { Set(editorialFilms.map(\.id)) }
    static func person(_ id: String) -> TableMember? { people.first { $0.id == id } }
    static func gift(_ id: String) -> TableCelebration? { gifts.first { $0.id == id } }
}
