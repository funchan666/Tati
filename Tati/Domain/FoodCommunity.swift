import Foundation

enum VoiceRoomBackground: String, CaseIterable, Identifiable {
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

struct FoodPerson: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let country: String
    let language: String
    let interest: String
    let bio: String
    var portraitArtwork: String? { ContentLibrary.shared.portraits[id] }
    var city: String { ["creator-luna": "Paris", "creator-chloe": "Singapore", "creator-maria": "Toronto", "creator-elowen": "Los Angeles", "creator-seraphina": "Bangkok", "creator-andre": "Kuala Lumpur"][id] ?? country }
}
struct FoodRoom: Identifiable, Hashable {
    let id: String
    let hostID: String
    let title: String
    let topic: String
    let isVoice: Bool
    let background: String
    // Presentation configuration, not a realtime presence measurement.
    let initialAudienceCount: Int
    var coverArtwork: String? { ContentLibrary.shared.roomCovers[id] }
    var videoClip: FoodClip? { ContentLibrary.shared.roomClips?[id] }
    var foodFocused: Bool { topic != "Home cooking" }
}
struct FoodClip: Identifiable, Codable, Hashable {
    var id: String
    var authorID: String
    var caption: String
    var fileName: String?
    var createdAt: Date
    var isSample: Bool
    var bundledFile: String? = nil
    var posterArtwork: String? = nil
    // Only a real moderation result may promote an imported post to approved.
    var moderationStatus: String? = nil
    var isCollection: Bool { authorID == "tati-collection" }
}
struct FoodGift: Identifiable, Hashable {
    let id: String
    let name: String
    let artwork: String
    let cost: Int
}
struct LocalMessage: Identifiable, Codable {
    var id = UUID().uuidString
    var recipientID: String
    var text: String
    var createdAt = Date()
    // A draft is never represented as delivered.
    var status = "Draft · not sent"
    var senderID: String? = nil
    var imageFile: String? = nil
}
struct VideoComment: Identifiable, Codable {
    var id = UUID().uuidString
    var clipID: String
    var authorID: String
    var text: String
    var createdAt = Date()
    var isCurated: Bool? = nil
}
struct GiftReceipt: Identifiable, Codable {
    var id = UUID().uuidString
    var giftID: String
    var recipientID: String
    var quantity: Int
    var spent: Int
    var date = Date()
    var roomID: String? = nil
}
struct LocalRoomMessage: Identifiable, Codable {
    var id = UUID().uuidString
    var roomID: String
    var text: String
    var createdAt = Date()
}
struct RoomActivity: Identifiable {
    var id: String
    var authorID: String
    var text: String
    var giftID: String? = nil
    var quantity = 1
    var isSample = true

}

struct ReportDraft: Identifiable, Codable {
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
struct LocalProfile: Codable {
    var id = UUID().uuidString
    var name = "Tati Guest"
    var bio = "Finding joy in every little bite."
    var country = "Not set"
    var interest = "Home cooking"
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
struct CoinExpense: Codable, Identifiable {
    var id = UUID().uuidString
    let title: String
    let coins: Int
    var date = Date()
}
struct LocalAccount: Codable {
    var version = 1
    var profile = LocalProfile()
    var signedIn = false
    var following: Set<String> = []
    // Populated only by authenticated inbound relationship events, never by a follow tap.
    var followers: Set<String>? = nil
    var hiddenSubjects: Set<String>? = nil
    var blocked: Set<String> = []
    var likes: Set<String> = []
    var demoCoins = 0
    var purchasedCoins = 0
    var claimedDays: Set<String> = []
    var gifts: [GiftReceipt] = []
    var roomMessages: [LocalRoomMessage]? = nil
    var drafts: [String: String] = [:]
    var messages: [LocalMessage] = []
    var videoComments: [VideoComment]? = nil
    var reports: [ReportDraft] = []
    var clips: [FoodClip] = []
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
    var coinExpenses: [CoinExpense]? = []
}

enum FoodCatalog {
    static let people: [FoodPerson] = originalPeople + ContentLibrary.shared.additionalPeople
    private static let originalPeople = [
        FoodPerson(id: "creator-luna", name: "Luna", country: "France", language: "English", interest: "Home cooking", bio: "Simple ingredients, great taste. A little kitchen and a lot of curiosity."),
        FoodPerson(id: "creator-chloe", name: "Chloe", country: "Singapore", language: "English", interest: "Street food", bio: "Every street has a story. Let's discover it over a delicious bite."),
        FoodPerson(id: "creator-maria", name: "Maria", country: "Italy", language: "Italian", interest: "Italian food", bio: "Homemade pasta, slow Sundays, and a seat for everyone at the table."),
        FoodPerson(id: "creator-elowen", name: "Elowen", country: "USA", language: "English", interest: "Dessert", bio: "A pinch of sugar and a whole lot of happiness."),
        FoodPerson(id: "creator-seraphina", name: "Seraphina", country: "France", language: "French", interest: "Healthy food", bio: "Colourful plates and fresh ideas from my kitchen."),
        FoodPerson(id: "creator-andre", name: "André", country: "USA", language: "English", interest: "BBQ", bio: "Good food tastes better with good company.")
    ]
    static let rooms = [
        FoodRoom(id: "pasta-table", hostID: "creator-maria", title: "Homemade Pasta & More", topic: "Italian food", isVoice: false, background: "stage-confetti", initialAudienceCount: 264),
        FoodRoom(id: "street-bites", hostID: "creator-chloe", title: "Best Street Food in Town", topic: "Street food", isVoice: false, background: "stage-blue", initialAudienceCount: 486),
        FoodRoom(id: "kitchen-stories", hostID: "creator-luna", title: "Big Bites, Happy Vibes", topic: "Home cooking", isVoice: false, background: "stage-purple", initialAudienceCount: 728),
        FoodRoom(id: "sweet-evening", hostID: "creator-elowen", title: "Fine Dining at Home", topic: "Dessert", isVoice: false, background: "stage-gifts", initialAudienceCount: 193),
        FoodRoom(id: "soup-kitchen", hostID: "creator-andre", title: "Inside the Soup Kitchen", topic: "Home cooking", isVoice: false, background: "stage-blue", initialAudienceCount: 351),
        FoodRoom(id: "crepe-station", hostID: "creator-seraphina", title: "Fresh Crepes & Sweet Bites", topic: "Dessert", isVoice: false, background: "stage-gifts", initialAudienceCount: 612),
        FoodRoom(id: "dinner-conversation", hostID: "creator-luna", title: "What's cooking tonight?", topic: "Home cooking", isVoice: true, background: "stage-gifts", initialAudienceCount: 86),
        FoodRoom(id: "dessert-club", hostID: "creator-elowen", title: "The dessert club", topic: "Dessert", isVoice: true, background: "stage-purple", initialAudienceCount: 124),
        FoodRoom(id: "market-table", hostID: "creator-seraphina", title: "Fresh from the market", topic: "Healthy food", isVoice: true, background: "stage-blue", initialAudienceCount: 59),
        FoodRoom(id: "weekend-bbq", hostID: "creator-andre", title: "Weekend BBQ stories", topic: "BBQ", isVoice: true, background: "stage-gifts", initialAudienceCount: 97)
    ]
    static let gifts = [
        FoodGift(id: "balloons", name: "Sending love", artwork: "gift-balloons", cost: 50),
        FoodGift(id: "peach", name: "Peach", artwork: "gift-peach", cost: 80),
        FoodGift(id: "drink", name: "Sweet sip", artwork: "gift-drink", cost: 120),
        FoodGift(id: "cake", name: "Cake", artwork: "gift-cake", cost: 180),
        FoodGift(id: "box", name: "Little surprise", artwork: "gift-box", cost: 240),
        FoodGift(id: "headphones", name: "Good vibes", artwork: "gift-headphones", cost: 360),
        FoodGift(id: "car", name: "Food trip", artwork: "gift-car", cost: 680),
        FoodGift(id: "crown", name: "Kitchen crown", artwork: "gift-crown", cost: 1200)
    ]
    static let cities = ["All", "Singapore", "Toronto", "Bangkok", "Paris", "Los Angeles", "Kuala Lumpur"]
    static let languages = ["All", "English", "Hindi", "Español", "Türkçe", "Português", "French", "Italian"]
    static let popularTopics = [("Italian food", "category-italian"), ("Sushi", "category-sushi"), ("Street food", "category-street"), ("Dessert", "category-dessert"), ("Healthy food", "category-healthy"), ("BBQ", "category-bbq")]
    static let topics = ["All", "Home cooking", "Italian food", "Street food", "Dessert", "Healthy food", "BBQ"]
    static let sampleClips: [FoodClip] = ContentLibrary.shared.clips
    static func person(_ id: String) -> FoodPerson? { people.first { $0.id == id } }
    static func gift(_ id: String) -> FoodGift? { gifts.first { $0.id == id } }
}
