import Foundation

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
}
struct GiftReceipt: Identifiable, Codable {
    var id = UUID().uuidString
    var giftID: String
    var recipientID: String
    var quantity: Int
    var spent: Int
    var date = Date()
}
struct ReportDraft: Identifiable, Codable {
    var id = UUID().uuidString
    var subjectID: String
    var reason: String
    var details: String
    var imageFile: String? = nil
    var date = Date()
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
struct LocalAccount: Codable {
    var version = 1
    var profile = LocalProfile()
    var signedIn = false
    var following: Set<String> = []
    var blocked: Set<String> = []
    var likes: Set<String> = []
    var demoCoins = 0
    var purchasedCoins = 0
    var claimedDays: Set<String> = []
    var gifts: [GiftReceipt] = []
    var drafts: [String: String] = [:]
    var messages: [LocalMessage] = []
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
        FoodRoom(id: "pasta-table", hostID: "creator-maria", title: "Homemade Pasta & More", topic: "Italian food", isVoice: false, background: "stage-confetti"),
        FoodRoom(id: "street-bites", hostID: "creator-chloe", title: "Best Street Food in Town", topic: "Street food", isVoice: false, background: "stage-blue"),
        FoodRoom(id: "kitchen-stories", hostID: "creator-luna", title: "Big Bites, Happy Vibes", topic: "Home cooking", isVoice: false, background: "stage-purple"),
        FoodRoom(id: "sweet-evening", hostID: "creator-elowen", title: "Fine Dining at Home", topic: "Dessert", isVoice: false, background: "stage-gifts"),
        FoodRoom(id: "soup-kitchen", hostID: "creator-andre", title: "Inside the Soup Kitchen", topic: "Home cooking", isVoice: false, background: "stage-blue"),
        FoodRoom(id: "crepe-station", hostID: "creator-seraphina", title: "Fresh Crepes & Sweet Bites", topic: "Dessert", isVoice: false, background: "stage-gifts"),
        FoodRoom(id: "dinner-conversation", hostID: "creator-luna", title: "What's cooking tonight?", topic: "Home cooking", isVoice: true, background: "stage-confetti"),
        FoodRoom(id: "dessert-club", hostID: "creator-elowen", title: "The dessert club", topic: "Dessert", isVoice: true, background: "stage-purple"),
        FoodRoom(id: "market-table", hostID: "creator-seraphina", title: "Fresh from the market", topic: "Healthy food", isVoice: true, background: "stage-blue"),
        FoodRoom(id: "weekend-bbq", hostID: "creator-andre", title: "Weekend BBQ stories", topic: "BBQ", isVoice: true, background: "stage-gifts")
    ]
    static let gifts = [
        FoodGift(id: "balloons", name: "Sending love", artwork: "gift-balloons", cost: 50),
        FoodGift(id: "peach", name: "Peach", artwork: "gift-peach", cost: 50),
        FoodGift(id: "drink", name: "Sweet sip", artwork: "gift-drink", cost: 50),
        FoodGift(id: "cake", name: "Cake", artwork: "gift-cake", cost: 50),
        FoodGift(id: "box", name: "Little surprise", artwork: "gift-box", cost: 100),
        FoodGift(id: "headphones", name: "Good vibes", artwork: "gift-headphones", cost: 100),
        FoodGift(id: "car", name: "Food trip", artwork: "gift-car", cost: 100),
        FoodGift(id: "crown", name: "Kitchen crown", artwork: "gift-crown", cost: 100)
    ]
    static let cities = ["All", "Singapore", "Toronto", "Bangkok", "Paris", "Los Angeles", "Kuala Lumpur"]
    static let languages = ["All", "English", "Hindi", "Español", "Türkçe", "Português", "French", "Italian"]
    static let popularTopics = [("Italian food", "category-italian"), ("Sushi", "category-sushi"), ("Street food", "category-street"), ("Dessert", "category-dessert"), ("Healthy food", "category-healthy"), ("BBQ", "category-bbq")]
    static let topics = ["All", "Home cooking", "Italian food", "Street food", "Dessert", "Healthy food", "BBQ"]
    static let sampleClips: [FoodClip] = ContentLibrary.shared.clips
    static func person(_ id: String) -> FoodPerson? { people.first { $0.id == id } }
    static func gift(_ id: String) -> FoodGift? { gifts.first { $0.id == id } }
}
