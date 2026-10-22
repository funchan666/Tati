import SwiftUI

struct TatiNotice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var actionTitle: String = "OK"
    var action: (() -> Void)?
    var destructive = false
    var artwork: String? = nil
    var personID: String? = nil
}

@MainActor
final class MemberKitchenStore: ObservableObject {
    @Published private(set) var account = MemberKitchenState() {
        didSet { cachedMessageIndex = nil }
    }
    private var cachedMessageIndex: [String: [ConversationOutboxItem]]?
    private var messageIndex: [String: [ConversationOutboxItem]] {
        if let cachedMessageIndex { return cachedMessageIndex }
        let index = Dictionary(grouping: account.messages, by: \.recipientID)
            .mapValues { $0.sorted { $0.createdAt < $1.createdAt } }
        cachedMessageIndex = index
        return index
    }
    @Published var notice: TatiNotice?

    @Published private var noticeHosts: [(id: UUID, isRoot: Bool)] = []

    func registerNoticeHost(_ id: UUID, isRoot: Bool) {
        guard !noticeHosts.contains(where: { $0.id == id }) else { return }
        noticeHosts.append((id, isRoot))
    }

    func unregisterNoticeHost(_ id: UUID) {
        noticeHosts.removeAll { $0.id == id }
    }

    func ownsNotice(_ id: UUID) -> Bool {
        let host = noticeHosts.last(where: { !$0.isRoot }) ?? noticeHosts.last
        return host?.id == id
    }
    @Published var paymentInProgress = false
    @Published private(set) var storageFailure: String?
    private(set) var hasStoredProfile = false
    private let fileURL: URL
    let mediaDirectory: URL

    private var pendingDrafts: [String: (text: String, owner: String)] = [:]
    private var draftSaves: [String: Task<Void, Never>] = [:]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Tati", isDirectory: true)
        fileURL = base.appendingPathComponent("visitor-v1.json")
        mediaDirectory = base.appendingPathComponent("Media", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                account = try JSONDecoder().decode(MemberKitchenState.self, from: Data(contentsOf: fileURL))
                hasStoredProfile = !account.profile.name.isEmpty || !account.profile.bio.isEmpty || account.profile.avatarFile != nil || account.profile.coverFile != nil
                guard account.version == 1 else { throw CocoaError(.fileReadCorruptFile) }

                if account.welcomeGranted == nil { account.welcomeGranted = true; account.welcomeAcknowledged = true }
                if account.frameUnlocked == nil { account.frameUnlocked = account.equippedFrame || !account.claimedDays.isEmpty }
                if account.coinExpenses == nil {
                    account.coinExpenses = account.gifts.map { KitchenCoinExpense(id: $0.id, title: "Gift · " + (TableCommunity.gift($0.giftID)?.name ?? "Gift"), coins: $0.spent, date: $0.date) }
                }
            }
        } catch {
            storageFailure = "Your saved data could not be opened. It has not been replaced. Please check available storage before trying again."
        }
        prepareVoiceRoomBackgrounds()
    }

    private func prepareVoiceRoomBackgrounds() {
        guard storageFailure == nil else { return }
        let rooms = TableCommunity.rooms.filter(\.isVoice)
        var assignments = account.roomBackgrounds
        var changed = false
        for room in rooms.shuffled() where assignments[room.id].flatMap(ConversationBackdrop.init(rawValue:)) == nil {

            let counts = Dictionary(uniqueKeysWithValues: ConversationBackdrop.allCases.map { background in
                (background, rooms.filter { assignments[$0.id] == background.rawValue }.count)
            })
            let minimum = counts.values.min() ?? 0
            let candidates = ConversationBackdrop.allCases.filter { counts[$0] == minimum }
            assignments[room.id] = (candidates.randomElement() ?? .blue).rawValue
            changed = true
        }
        if changed { _ = change { $0.roomBackgrounds = assignments } }
    }

    func voiceRoomBackground(for room: CookingRoom) -> ConversationBackdrop {
        account.roomBackgrounds[room.id].flatMap(ConversationBackdrop.init(rawValue:))
            ?? ConversationBackdrop(rawValue: room.background) ?? .blue
    }
    @discardableResult
    func change(_ edit: (inout MemberKitchenState) -> Void) -> Bool {
        guard storageFailure == nil else { tell("Storage unavailable", storageFailure ?? "Please try again."); return false }
        var next = account
        edit(&next)
        do {
            let data = try JSONEncoder().encode(next)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            let persisted = try Data(contentsOf: fileURL)
            guard persisted == data else { throw CocoaError(.fileReadCorruptFile) }
            let durable = try JSONDecoder().decode(MemberKitchenState.self, from: persisted)
            guard durable.profile.id == next.profile.id else { throw CocoaError(.fileReadCorruptFile) }
            account = durable
            return true
        } catch {
            storageFailure = "Your changes could not be verified. Saving is paused to protect your data. Check available storage, then reopen Tati."
            tell("Couldn't verify save", storageFailure!)
            return false
        }
    }
    func tell(_ title: String, _ message: String) { notice = TatiNotice(title: title, message: message) }
    func celebrate(_ title: String, _ message: String, artwork: String) {
        notice = TatiNotice(title: title, message: message, artwork: artwork)
    }
    func confirm(_ title: String, _ message: String, button: String, destructive: Bool = false, action: @escaping () -> Void) {
        notice = TatiNotice(title: title, message: message, actionTitle: button, action: action, destructive: destructive)
    }
    static var welcomeCoins: Int { KitchenContentSnapshot.current?.offers.welcomeCoins ?? 0 }
    static var frameCost: Int { KitchenContentSnapshot.current?.offers.frameCost ?? 0 }
    var coinBalance: Int { account.rewardCoins + account.purchasedCoins }
    var ownsFrame: Bool { account.frameUnlocked == true || account.equippedFrame }
    func contentDidChange() {
        objectWillChange.send()
        if KitchenContentSnapshot.current != nil {
            if !hasStoredProfile, !account.profile.name.isEmpty || !account.profile.bio.isEmpty || account.profile.avatarFile != nil || account.profile.coverFile != nil { hasStoredProfile = true }
            if !hasStoredProfile, let defaults = KitchenContentSnapshot.current?.offers.profileDefaults {
                if change({ value in value.profile.name = defaults.name; value.profile.bio = defaults.bio; value.profile.country = defaults.country; value.profile.interest = defaults.interest }) { hasStoredProfile = true }
            }
            prepareVoiceRoomBackgrounds()
            applyWelcomeCoins()
        }
    }
    private func applyWelcomeCoins() {
        guard account.signedIn, account.welcomeGranted == false, KitchenContentSnapshot.current != nil else { return }
        _ = change { value in
            value.rewardCoins += Self.welcomeCoins; value.welcomeGranted = true; value.welcomeAcknowledged = true
        }
    }
    func signIn() {
        prepareVoiceRoomBackgrounds()
        _ = change { $0.signedIn = true }
        applyWelcomeCoins()
    }
    func logout() {
        guard !paymentInProgress else { tell("Purchase in progress", "Finish the Apple purchase before signing out."); return }
        confirm("Leave Tati?", "Your profile and saved content will be kept when you log out.", button: "Log out") {
            self.flushDrafts()
            _ = self.change { $0.signedIn = false }
        }
    }
    func deleteVisitor() {
        guard !paymentInProgress else { tell("Purchase in progress", "Finish the Apple purchase before deleting this profile."); return }
        confirm("Delete profile?", "This permanently removes your Tati profile, imported photos and videos, drafts and coin balance from app storage. Consumable coins cannot be restored after deletion.", button: "Delete", destructive: true) {
            let files = [self.account.profile.avatarFile, self.account.profile.coverFile].compactMap { $0 } + self.account.clips.compactMap(\.recordedMovieFile) + self.account.reports.compactMap(\.imageFile) + self.account.messages.compactMap(\.imageFile) + Array((self.account.draftImages ?? [:]).values)
            guard self.change({ value in
                let intents = value.purchaseIntents
                let credits = value.purchaseCredits
                let processed = value.processedTransactions
                let legacyOwners = value.purchaseOwnerByProduct
                let language = value.preferredLanguage
                value = MemberKitchenState()
                self.hasStoredProfile = false

                value.purchaseIntents = intents; value.purchaseCredits = credits
                value.processedTransactions = processed; value.purchaseOwnerByProduct = legacyOwners
                value.preferredLanguage = language
            }) else { return }
            for key in Array(self.pendingDrafts.keys) { self.cancelDraftSave(key) }
            var cleanupFailed = false
            for file in files where FileManager.default.fileExists(atPath: self.mediaURL(file).path) {
                do { try FileManager.default.removeItem(at: self.mediaURL(file)) } catch { cleanupFailed = true }
            }
            if cleanupFailed { self.tell("Profile deleted", "Some imported files could not be removed. Uninstall Tati to erase the remaining app data.") }
            else { self.celebrate("Profile deleted", "Your profile and saved content have been removed.", artwork: "support-mascot") }
        }
    }

    var followingIDs: Set<String> { account.following.filter { $0 != account.profile.id && !isPersonHidden($0) } }
    var followerIDs: Set<String> { (account.followers ?? []).filter { $0 != account.profile.id && !isPersonHidden($0) } }
    func isFollowing(_ id: String) -> Bool {
        id != account.profile.id && account.following.contains(id) && !isPersonHidden(id)
    }
    func canChangeFollow(_ id: String) -> Bool {
        account.signedIn && id != account.profile.id && TableCommunity.person(id) != nil && !isPersonHidden(id)
    }
    @discardableResult
    func setFollowing(_ following: Bool, for id: String) -> Bool {
        guard canChangeFollow(id) else { return false }
        guard account.following.contains(id) != following else { return true }

        return change { value in
            if following { value.following.insert(id) }
            else { value.following.remove(id) }
        }
    }
    func block(_ id: String) {
        guard id != account.profile.id else { return }
        let person = TableCommunity.person(id)
        notice = TatiNotice(title: person.map { "Block \($0.name)?" } ?? "Block this profile?",
                            message: "Their posts, comments, rooms and conversations will be hidden. You can unblock them in Settings.",
                            actionTitle: "Block", action: {
            if self.change({ $0.blocked.insert(id); $0.following.remove(id); $0.followers?.remove(id) }) {
                self.celebrate("Profile blocked", "Their content and conversations are now hidden.", artwork: "blacklist")
            }
        }, destructive: true, artwork: "blacklist", personID: person?.id)
    }
    func isHidden(_ subject: String) -> Bool { account.hiddenSubjects?.contains(subject) == true }
    func unblock(_ id: String) {
        confirm("Unblock this profile?", "This removes the profile from your blacklist. Previous follows will not be restored automatically.", button: "Unblock") {
            if self.change({ $0.blocked.remove(id) }) {
                self.celebrate("Profile unblocked", "Your blacklist has been updated.", artwork: "blacklist")
            }
        }
    }
    func isPersonHidden(_ id: String) -> Bool { account.blocked.contains(id) || isHidden("person:" + id) }
    var visiblePeople: [TableMember] { TableCommunity.people.filter { !isPersonHidden($0.id) } }
    var visibleRooms: [CookingRoom] { TableCommunity.rooms.filter { room in !isPersonHidden(room.hostID) && !isHidden("room:" + room.id) && (room.videoClip.map { account.tableSyncState?.hiddenFilmIDs.contains($0.id) != true } ?? true) } }
    var mutualIDs: Set<String> { followingIDs.intersection(followerIDs) }
    func canCommunicate(with id: String) -> Bool {
        account.signedIn && id != account.profile.id && !isPersonHidden(id) && mutualIDs.contains(id)
    }
    @discardableResult
    func requireMutualFollow(_ id: String) -> Bool {
        guard !isPersonHidden(id) else { tell("Conversation unavailable", "This profile is hidden or blocked."); return false }
        guard canCommunicate(with: id) else {
            tell("Follow each other first", "You can send messages and start calls after you both choose to follow each other. Your draft is kept.")
            return false
        }
        return true
    }
    func messages(with id: String) -> [ConversationOutboxItem] {
        guard !isPersonHidden(id) else { return [] }
        return (messageIndex[id] ?? []).filter { !isHidden("message:" + $0.id) }
    }
    func latestMessage(with id: String) -> ConversationOutboxItem? {
        guard !isPersonHidden(id) else { return nil }
        return messageIndex[id]?.reversed().first { !isHidden("message:" + $0.id) }
    }
    func hasMessage(with id: String, matching text: String) -> Bool {
        guard !isPersonHidden(id) else { return false }
        return messageIndex[id]?.contains { !isHidden("message:" + $0.id) && $0.text.localizedCaseInsensitiveContains(text) } == true
    }
    func hasConversationDraft(with id: String) -> Bool {
        !(account.drafts[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var conversationPeople: [TableMember] {
        let latest = messageIndex.compactMapValues { messages in
            messages.reversed().first { !isHidden("message:" + $0.id) }?.createdAt
        }
        return visiblePeople.filter { latest[$0.id] != nil || hasConversationDraft(with: $0.id) }
            .sorted {
                let left = latest[$0.id] ?? .distantPast
                let right = latest[$1.id] ?? .distantPast
                return left == right ? $0.id < $1.id : left > right
            }
    }
    func toggleLike(_ id: String) {
        guard visibleClips.contains(where: { $0.id == id }) else { return }
        _ = change { if $0.likes.contains(id) { $0.likes.remove(id) } else { $0.likes.insert(id) } }
    }
    private func curatedEngagement(for clip: FoodFilm) -> CuratedClipEngagement? {

        guard clip.isEditorial, TableCommunity.editorialFilmIDs.contains(clip.id) else { return nil }
        return KitchenEditorialLibrary.shared.curatedEngagement?[clip.id]
    }
    func likeCount(for clip: FoodFilm) -> Int {
        max(0, curatedEngagement(for: clip)?.likes ?? 0) + (account.likes.contains(clip.id) ? 1 : 0)
    }
    func commentCount(for clip: FoodFilm) -> Int {
        let visible: (FilmDiscussionReply) -> Bool = {
            $0.clipID == clip.id && !self.isPersonHidden($0.authorID) && !self.isHidden("comment:" + $0.id)
        }

        return (curatedEngagement(for: clip)?.comments ?? []).lazy.filter(visible).count
            + (account.videoComments ?? []).lazy.filter { $0.isCurated != true }.filter(visible).count
    }
    func comments(for clip: FoodFilm) -> [FilmDiscussionReply] {
        let curated = curatedEngagement(for: clip)?.comments ?? []
        return (curated + (account.videoComments ?? []).filter { $0.isCurated != true })
            .filter { $0.clipID == clip.id && !isPersonHidden($0.authorID) && !isHidden("comment:" + $0.id) }
            .sorted { $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt }
    }
    func addComment(to clip: FoodFilm, text: String) -> Bool {
        let body = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !body.isEmpty, permitsCommunityText(body), visibleClips.contains(where: { $0.id == clip.id }), !account.blocked.contains(clip.authorID) else { return false }
        return change { value in
            var comments = value.videoComments ?? []
            comments.append(FilmDiscussionReply(clipID: clip.id, authorID: value.profile.id, text: body))
            value.videoComments = comments
            value.drafts.removeValue(forKey: "comment:" + clip.id)
        }
    }
    func removeComment(_ id: String) {
        _ = change { value in
            value.videoComments?.removeAll { $0.id == id && $0.authorID == account.profile.id }
        }
    }
    var dayKey: String {

        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: Date())
    }
    var checkedIn: Bool { account.claimedDays.contains(dayKey) }
    var nextCheckInReward: Int { (account.claimedDays.count % 8 + 1) * 10 }
    func checkIn() {
        let day = dayKey
        guard !account.claimedDays.contains(day) else { return }
        let reward = nextCheckInReward
        if change({ $0.claimedDays.insert(day); $0.rewardCoins += reward }) {
            tell("A delicious little reward", "\(reward) reward coins added to your balance. They have no cash value.")
        }
    }
    func requestGift(_ gift: TableCelebration, quantity: Int, recipient: String, roomID: String?, recharge: @escaping () -> Void, completed: @escaping () -> Void) {
        guard let roomID else { tell("Room gift effects", "Open a room to play a gift effect. Private chats are free."); return }
        guard (1...99).contains(quantity), !isPersonHidden(recipient),
              visibleRooms.contains(where: { $0.id == roomID && $0.hostID == recipient }) else { return }
        let cost = gift.cost * quantity
        requestSpend(cost, title: "Play \(gift.name) ×\(quantity)?", purpose: "Room effect · \(gift.name)",
                     detail: "Plays a gift effect on your screen. It does not transfer coins to the host.", recharge: recharge,
                     valid: { self.visibleRooms.contains { $0.id == roomID && $0.hostID == recipient } },
                     edit: { value in value.gifts.append(RoomEffectPurchase(giftID: gift.id, recipientID: recipient, quantity: quantity, spent: cost, roomID: roomID)) },
                     completed: completed)
    }
    func requestFrame(recharge: @escaping () -> Void) {
        if ownsFrame { _ = change { $0.equippedFrame.toggle() }; return }
        requestSpend(Self.frameCost, title: "Unlock Kitchen spotlight?", purpose: "Kitchen spotlight frame",
                     detail: "Keep this profile frame and wear it whenever you like.", recharge: recharge,
                     valid: { !self.ownsFrame },
                     edit: { $0.frameUnlocked = true; $0.equippedFrame = true },
                     completed: { self.celebrate("Your frame is ready", "Kitchen spotlight is now on your profile.", artwork: "host-frame") })
    }
    func requestSpend(_ amount: Int, title: String, purpose: String, detail: String,
                              recharge: @escaping () -> Void, valid: @escaping () -> Bool,
                              edit: @escaping (inout MemberKitchenState) -> Void, completed: @escaping () -> Void) {
        let owner = account.profile.id
        guard account.signedIn, amount > 0, valid() else { return }
        guard coinBalance >= amount else { insufficientCoins(amount, recharge: recharge); return }
        confirm(title, "\(detail)\n\n\(amount.formatted()) coins · Balance \(coinBalance.formatted())", button: "Use \(amount.formatted()) coins") {
            guard self.account.profile.id == owner, self.account.signedIn, valid() else { return }
            guard self.coinBalance >= amount else { self.insufficientCoins(amount, recharge: recharge); return }
            if self.change({ value in
                let bonusUsed = min(value.rewardCoins, amount)
                value.rewardCoins -= bonusUsed
                value.purchasedCoins -= amount - bonusUsed
                var expenses = value.coinExpenses ?? []
                expenses.append(KitchenCoinExpense(title: purpose, coins: amount)); value.coinExpenses = expenses
                edit(&value)
            }) { completed() }
        }
    }
    private func insufficientCoins(_ amount: Int, recharge: @escaping () -> Void) {
        notice = TatiNotice(title: "A little more sparkle", message: "You need \((amount - coinBalance).formatted()) more coins. Your balance is \(coinBalance.formatted()).", actionTitle: "Recharge", action: recharge, artwork: "coin-pile")
    }
    func saveRoomMessage(roomID: String, text: String) -> Bool {
        let body = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        guard !body.isEmpty, permitsCommunityText(body),
              let room = TableCommunity.rooms.first(where: { $0.id == roomID }),
              visibleRooms.contains(where: { $0.id == room.id }) else { return false }
        let saved = change { value in
            var messages = value.roomMessages ?? []
            messages.append(RoomConversationEntry(roomID: roomID, text: body))
            let overflow = messages.filter { $0.roomID == roomID }.count - 100
            if overflow > 0 {
                let oldest = Set(messages.filter { $0.roomID == roomID }.prefix(overflow).map(\.id))
                messages.removeAll { oldest.contains($0.id) }
            }
            value.roomMessages = messages
            value.drafts["room-" + roomID] = ""
        }
        if saved { cancelDraftSave("room-" + roomID) }
        return saved
    }

    func scheduleDraft(_ key: String, text: String) {
        guard account.signedIn, storageFailure == nil else { return }
        let owner = account.profile.id
        if pendingDrafts[key]?.text == text, pendingDrafts[key]?.owner == owner { return }
        cancelDraftSave(key)
        guard (account.drafts[key] ?? "") != text else { return }
        pendingDrafts[key] = (text, owner)
        draftSaves[key] = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.flushDraft(key)
        }
    }

    func flushDraft(_ key: String) {
        guard let pending = pendingDrafts[key] else { return }
        guard pending.owner == account.profile.id, account.signedIn else { cancelDraftSave(key); return }
        _ = saveDraft(key, text: pending.text)
    }

    func flushDrafts() {
        for key in Array(pendingDrafts.keys) { flushDraft(key) }
    }

    private func cancelDraftSave(_ key: String) {
        draftSaves.removeValue(forKey: key)?.cancel()
        pendingDrafts.removeValue(forKey: key)
    }

    func saveDraft(_ key: String, text: String) -> Bool {
        cancelDraftSave(key)
        guard (account.drafts[key] ?? "") != text else { return storageFailure == nil }
        return change { $0.drafts[key] = text }
    }

    @discardableResult
    func askFoodExpert(_ question: String) -> Bool {
        let text = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200))
        guard account.signedIn, !text.isEmpty,
              !(account.foodExpertExchanges ?? []).contains(where: { $0.reply == nil }) else { return false }
        let saved = change { value in
            var exchanges = value.foodExpertExchanges ?? []
            exchanges.append(CookingQuestionExchange(question: text))
            value.foodExpertExchanges = Array(exchanges.suffix(40))
            value.drafts.removeValue(forKey: "food-expert")
        }
        if saved { cancelDraftSave("food-expert") }
        return saved
    }

    func finishFoodExpertReply(_ id: String, owner: String) {
        guard account.signedIn, account.profile.id == owner, storageFailure == nil,
              let exchange = account.foodExpertExchanges?.first(where: { $0.id == id }),
              exchange.reply == nil else { return }
        let tip = CookingNoteTopic.matching(exchange.question)
        _ = change { value in
            guard let index = value.foodExpertExchanges?.firstIndex(where: { $0.id == id }) else { return }
            value.foodExpertExchanges?[index].reply = tip
        }
    }
    @discardableResult
    func attemptMessage(to recipient: String, text: String) -> Bool {
        let body = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        guard !body.isEmpty, permitsCommunityText(body) else { return false }
        guard saveDraft(recipient, text: text), requireMutualFollow(recipient) else { return false }

        return change { value in
            var message = ConversationOutboxItem(recipientID: recipient, text: body)
            message.senderID = value.profile.id
            message.status = "Waiting to send"
            value.messages.append(message)
            value.drafts.removeValue(forKey: recipient)
        }
    }
    func saveReport(subject: String, reason: String, details: String, imageFile: String? = nil, authorID: String? = nil, contextID: String? = nil, feedback: Bool = false) -> Bool {
        guard !reason.isEmpty else { return false }
        return change { value in
            var report = CommunitySafetyRecord(subjectID: subject, reason: reason, details: details, imageFile: imageFile)
            report.recorded = true; report.authorID = authorID; report.contextID = contextID
            value.reports.append(report)
            if !feedback {
                var hidden = value.hiddenSubjects ?? []
                hidden.insert(subject)
                value.hiddenSubjects = hidden
            }
        }
    }
    func removeReport(_ report: CommunitySafetyRecord) {
        if change({ $0.reports.removeAll { $0.id == report.id } }), let file = report.imageFile { removeUnusedMedia(file) }
    }
    func removeUnusedMedia(_ file: String) {
        guard storageFailure == nil else { return }
        let referenced = [account.profile.avatarFile, account.profile.coverFile].compactMap { $0 }
            + account.clips.compactMap(\.recordedMovieFile) + account.reports.compactMap(\.imageFile)
            + account.messages.compactMap(\.imageFile)
            + Array((account.draftImages ?? [:]).values)
        guard !referenced.contains(file) else { return }
        if FileManager.default.fileExists(atPath: mediaURL(file).path) {
            do { try FileManager.default.removeItem(at: mediaURL(file)) }
            catch { tell("Media cleanup incomplete", "The record was removed, but its unused file could not be erased from device storage.") }
        }
    }
    func saveDraftImage(_ data: Data?, key: String) -> Bool {
        let old = account.draftImages?[key]
        var imported: String?
        do {
            if let data { imported = try importImage(data) }
            guard change({ value in
                var images = value.draftImages ?? [:]
                images[key] = imported
                value.draftImages = images
            }) else { if let imported { removeUnusedMedia(imported) }; return false }
            if let old { removeUnusedMedia(old) }
            return true
        } catch { tell("Photo unavailable", "Choose a supported photo smaller than 25 MB. Your draft has been kept."); return false }
    }
    func mediaURL(_ file: String) -> URL { mediaDirectory.appendingPathComponent(URL(fileURLWithPath: file).lastPathComponent) }
    func importImage(_ data: Data) throws -> String {
        guard data.count <= 25 * 1024 * 1024, UIImage(data: data) != nil else { throw CocoaError(.fileReadCorruptFile) }
        let name = UUID().uuidString + ".image"
        try data.write(to: mediaURL(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }
    func videoURL(for clip: FoodFilm) -> URL? {
        if let resource = clip.packagedMovieName {
            return KitchenEditorialLibrary.movieURL(for: resource)
        }
        if let local = clip.recordedMovieFile { return mediaURL(local) }
        return nil
    }
    func authorName(for clip: FoodFilm) -> String {
        if clip.isHouseCollection { return "Tati picks" }
        if clip.authorID == account.profile.id { return account.profile.name }
        return TableCommunity.person(clip.authorID)?.name ?? "Creator"
    }
    func isClipVisible(_ clip: FoodFilm) -> Bool {
        if clip.isEditorial && !KitchenEditorialLibrary.activeFilmIDs.contains(clip.id) { return false }
        return !isPersonHidden(clip.authorID) && !isHidden("video:" + clip.id) && account.tableSyncState?.hiddenFilmIDs.contains(clip.id) != true
            && (clip.packagedMovieName != nil || clip.publicationReviewState == "approved")
    }
    var visibleClips: [FoodFilm] { (account.clips.filter { !$0.isEditorial } + TableCommunity.editorialFilms).filter { isClipVisible($0) } }
    func submitPost(_ clip: FoodFilm) -> Bool {
        guard clip.authorID == account.profile.id, clip.recordedMovieFile != nil, permitsCommunityText(clip.dishCaption) else { return false }
        var pending = clip
        pending.publicationReviewState = "pendingReview"
        return change { $0.clips.insert(pending, at: 0) }
    }
}
