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
struct VideoComment: Identifiable, Codable {
    var id = UUID().uuidString
    var clipID: String
    var authorID: String
    var text: String
    var createdAt = Date()
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

    static func samples(for room: FoodRoom) -> [RoomActivity] {
        let lines: [String]
        switch room.id {
        case "pasta-table":
            lines = ["That toasted bread looks so crisp!", "What would you put in the filling?", "A little cheese would be perfect.", "Saving this for lunch inspiration.", "I'd add some fresh basil.", "Now I'm craving a warm sandwich."]
        case "street-bites":
            lines = ["What a street-food spread!", "Which bite would you try first?", "I'd start with the grilled wrap.", "The colours look amazing together.", "Spicy sauce on the side for me.", "This is my kind of food stop."]
        case "kitchen-stories":
            lines = ["That crunch looks incredible!", "Sweet glaze or spicy glaze?", "I'd try a little chilli with it.", "Such a satisfying bite.", "What's your favourite crispy snack?", "Perfect for a weekend food break."]
        case "sweet-evening":
            lines = ["That dessert looks so cosy.", "The golden edges are my favourite.", "I'd pair this with a cup of coffee.", "Would vanilla work in this recipe?", "Saving a little room for dessert.", "A sweet finish to the day."]
        case "soup-kitchen":
            lines = ["There's so much happening in this kitchen!", "What would you add to your soup?", "Fresh herbs at the end for me.", "That looks like a comforting bowl.", "A piece of crusty bread would be perfect.", "Soup season is my favourite."]
        case "crepe-station":
            lines = ["Watching crepes being made is so relaxing.", "Sweet filling or savoury filling?", "Lemon and sugar is my favourite.", "I'd choose strawberries and cream.", "Those thin edges look lovely.", "One more crepe, please!"]
        case "dessert-club":
            lines = ["What's everyone baking this week?", "I'm thinking about a lemon cake.", "Chocolate always wins for me.", "Does anyone like less-sweet desserts?", "Fresh fruit is my favourite topping.", "So many lovely dessert ideas."]
        case "market-table":
            lines = ["What did you find at the market?", "Tomatoes are on my shopping list.", "I love cooking with seasonal greens.", "A colourful salad sounds good.", "What's your favourite fresh herb?", "I'd pick basil every time."]
        case "weekend-bbq":
            lines = ["What's going on your grill?", "Grilled corn is a must for me.", "I'd bring a homemade dipping sauce.", "Vegetable skewers sound delicious.", "Sweet or smoky barbecue sauce?", "A weekend meal worth sharing."]
        default:
            lines = ["What's everyone cooking tonight?", "I'm making something simple and cosy.", "One-pot meals are my favourite.", "Any ideas for a quick side dish?", "A fresh salad would be lovely.", "Good food makes a good evening."]
        }
        let people = FoodCatalog.people.filter { $0.id != room.hostID }
        guard !people.isEmpty else { return [] }
        let offset = FoodCatalog.rooms.firstIndex(where: { $0.id == room.id }) ?? 0
        func author(_ index: Int) -> String { people[(offset * 3 + index) % people.count].id }
        var entries = lines.enumerated().map { index, line in
            RoomActivity(id: "\(room.id)-sample-message-\(index)", authorID: author(index), text: line)
        }
        let firstGift = FoodCatalog.gifts[offset % FoodCatalog.gifts.count]
        let secondGift = FoodCatalog.gifts[(offset + 3) % FoodCatalog.gifts.count]
        entries.insert(RoomActivity(id: "\(room.id)-sample-gift-0", authorID: author(2), text: "", giftID: firstGift.id, quantity: 1), at: 2)
        entries.insert(RoomActivity(id: "\(room.id)-sample-gift-1", authorID: author(4), text: "", giftID: secondGift.id, quantity: 3), at: 5)
        return entries
    }
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
