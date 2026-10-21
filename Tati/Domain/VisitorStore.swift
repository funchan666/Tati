import SwiftUI

struct TatiNotice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var actionTitle: String = "OK"
    var action: (() -> Void)?
    var destructive = false
    var artwork: String? = nil
}

@MainActor
final class VisitorStore: ObservableObject {
    @Published private(set) var account = LocalAccount()
    @Published var notice: TatiNotice?
    @Published var paymentInProgress = false
    @Published private(set) var storageFailure: String?
    private let fileURL: URL
    let mediaDirectory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Tati", isDirectory: true)
        fileURL = base.appendingPathComponent("visitor-v1.json")
        mediaDirectory = base.appendingPathComponent("Media", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                account = try JSONDecoder().decode(LocalAccount.self, from: Data(contentsOf: fileURL))
                guard account.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
                // Existing profiles retain their rewards and previously earned frame.
                if account.welcomeGranted == nil { account.welcomeGranted = true; account.welcomeAcknowledged = true }
                if account.frameUnlocked == nil { account.frameUnlocked = account.equippedFrame || !account.claimedDays.isEmpty }
                if account.coinExpenses == nil {
                    account.coinExpenses = account.gifts.map { CoinExpense(id: $0.id, title: "Gift · " + (FoodCatalog.gift($0.giftID)?.name ?? "Gift"), coins: $0.spent, date: $0.date) }
                }
            }
        } catch {
            storageFailure = "Your saved data could not be opened. It has not been replaced. Please check available storage before trying again."
        }
        prepareVoiceRoomBackgrounds()
    }

    // Assign once, not during rendering. Keep every valid explicit selection.
    private func prepareVoiceRoomBackgrounds() {
        guard storageFailure == nil else { return }
        let rooms = FoodCatalog.rooms.filter(\.isVoice)
        var assignments = account.roomBackgrounds
        var changed = false
        for room in rooms.shuffled() where assignments[room.id].flatMap(VoiceRoomBackground.init(rawValue:)) == nil {
            // Randomize among the least-used originals so all three get exposure.
            let counts = Dictionary(uniqueKeysWithValues: VoiceRoomBackground.allCases.map { background in
                (background, rooms.filter { assignments[$0.id] == background.rawValue }.count)
            })
            let minimum = counts.values.min() ?? 0
            let candidates = VoiceRoomBackground.allCases.filter { counts[$0] == minimum }
            assignments[room.id] = (candidates.randomElement() ?? .blue).rawValue
            changed = true
        }
        if changed { _ = change { $0.roomBackgrounds = assignments } }
    }

    func voiceRoomBackground(for room: FoodRoom) -> VoiceRoomBackground {
        account.roomBackgrounds[room.id].flatMap(VoiceRoomBackground.init(rawValue:))
            ?? VoiceRoomBackground(rawValue: room.background) ?? .blue
    }
    @discardableResult
    func change(_ edit: (inout LocalAccount) -> Void) -> Bool {
        guard storageFailure == nil else { tell("Storage unavailable", storageFailure ?? "Please try again."); return false }
        var next = account
        edit(&next)
        do {
            let data = try JSONEncoder().encode(next)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            let persisted = try Data(contentsOf: fileURL)
            guard persisted == data else { throw CocoaError(.fileReadCorruptFile) }
            let durable = try JSONDecoder().decode(LocalAccount.self, from: persisted)
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
    static let welcomeCoins = 300
    static let frameCost = 300
    var coinBalance: Int { account.demoCoins + account.purchasedCoins }
    var ownsFrame: Bool { account.frameUnlocked == true || account.equippedFrame }
    func signIn() {
        prepareVoiceRoomBackgrounds()
        _ = change { value in
            value.signedIn = true
            if value.welcomeGranted == false {
                value.demoCoins += Self.welcomeCoins
                value.welcomeGranted = true
                value.welcomeAcknowledged = false
            }
        }
    }
    func logout() {
        guard !paymentInProgress else { tell("Purchase in progress", "Finish the Apple purchase before signing out."); return }
        confirm("Leave Tati?", "Your profile and saved content will be kept when you log out.", button: "Log out") {
            _ = self.change { $0.signedIn = false }
        }
    }
    func deleteVisitor() {
        guard !paymentInProgress else { tell("Purchase in progress", "Finish the Apple purchase before deleting this profile."); return }
        confirm("Delete profile?", "This permanently removes your Tati profile, imported photos and videos, drafts and coin balance from app storage. Consumable coins cannot be restored after deletion.", button: "Delete", destructive: true) {
            let files = [self.account.profile.avatarFile, self.account.profile.coverFile].compactMap { $0 } + self.account.clips.compactMap(\.fileName) + self.account.reports.compactMap(\.imageFile) + self.account.messages.compactMap(\.imageFile) + Array((self.account.draftImages ?? [:]).values)
            guard self.change({ value in
                let intents = value.purchaseIntents
                let credits = value.purchaseCredits
                let processed = value.processedTransactions
                let legacyOwners = value.purchaseOwnerByProduct
                value = LocalAccount()
                // Keep transaction evidence; a new profile must never inherit an old order.
                value.purchaseIntents = intents; value.purchaseCredits = credits
                value.processedTransactions = processed; value.purchaseOwnerByProduct = legacyOwners
            }) else { return }
            var cleanupFailed = false
            for file in files where FileManager.default.fileExists(atPath: self.mediaURL(file).path) {
                do { try FileManager.default.removeItem(at: self.mediaURL(file)) } catch { cleanupFailed = true }
            }
            if cleanupFailed { self.tell("Profile deleted", "Some imported files could not be removed. Uninstall Tati to erase the remaining app data.") }
        }
    }
    // All screens derive relationship state from this persisted account, never view-local flags.
    var followingIDs: Set<String> { account.following.filter { $0 != account.profile.id && !isPersonHidden($0) } }
    var followerIDs: Set<String> { (account.followers ?? []).filter { $0 != account.profile.id && !isPersonHidden($0) } }
    func isFollowing(_ id: String) -> Bool {
        id != account.profile.id && account.following.contains(id) && !isPersonHidden(id)
    }
    func canChangeFollow(_ id: String) -> Bool {
        account.signedIn && id != account.profile.id && FoodCatalog.person(id) != nil && !isPersonHidden(id)
    }
    @discardableResult
    func setFollowing(_ following: Bool, for id: String) -> Bool {
        guard canChangeFollow(id) else { return false }
        guard account.following.contains(id) != following else { return true }
        // Publish only after the durable write succeeds. Following never creates a follower.
        return change { value in
            if following { value.following.insert(id) }
            else { value.following.remove(id) }
        }
    }
    func block(_ id: String) {
        guard id != account.profile.id else { return }
        confirm("Block this profile?", "Their posts, comments, rooms and conversations will be hidden. You can unblock them in Settings.", button: "Block", destructive: true) {
            if self.change({ $0.blocked.insert(id); $0.following.remove(id); $0.followers?.remove(id) }) {
                self.celebrate("Profile blocked", "Their content and conversations are now hidden.", artwork: "blacklist")
            }
        }
    }
    func isHidden(_ subject: String) -> Bool { account.hiddenSubjects?.contains(subject) == true }
    func isPersonHidden(_ id: String) -> Bool { account.blocked.contains(id) || isHidden("person:" + id) }
    var visiblePeople: [FoodPerson] { FoodCatalog.people.filter { !isPersonHidden($0.id) } }
    var visibleRooms: [FoodRoom] { FoodCatalog.rooms.filter { !isPersonHidden($0.hostID) && !isHidden("room:" + $0.id) } }
    var mutualIDs: Set<String> { followingIDs.intersection(followerIDs) }
    func canCommunicate(with id: String) -> Bool {
        account.signedIn && id != account.profile.id && mutualIDs.contains(id)
    }
    @discardableResult
    func requireMutualFollow(_ id: String) -> Bool {
        guard !isPersonHidden(id) else { tell("Conversation unavailable", "This profile is hidden or blocked."); return false }
        guard canCommunicate(with: id) else {
            tell("Follow each other first", "You can send messages and start video calls after you both choose to follow each other. Your draft is kept.")
            return false
        }
        return true
    }
    func messages(with id: String) -> [LocalMessage] {
        guard !isPersonHidden(id) else { return [] }
        return account.messages.filter { $0.recipientID == id && !isHidden("message:" + $0.id) }.sorted { $0.createdAt < $1.createdAt }
    }
    func toggleLike(_ id: String) {
        guard visibleClips.contains(where: { $0.id == id }) else { return }
        _ = change { if $0.likes.contains(id) { $0.likes.remove(id) } else { $0.likes.insert(id) } }
    }
    private func curatedEngagement(for clip: FoodClip) -> CuratedClipEngagement? {
        // Imported/user-authored videos never receive editorial interactions.
        guard clip.isSample, ContentLibrary.shared.clips.contains(where: { $0.id == clip.id }) else { return nil }
        return ContentLibrary.shared.curatedEngagement?[clip.id]
    }
    func likeCount(for clip: FoodClip) -> Int {
        max(0, curatedEngagement(for: clip)?.likes ?? 0) + (account.likes.contains(clip.id) ? 1 : 0)
    }
    func commentCount(for clip: FoodClip) -> Int { comments(for: clip).count }
    func comments(for clip: FoodClip) -> [VideoComment] {
        let curated = curatedEngagement(for: clip)?.comments ?? []
        return (curated + (account.videoComments ?? []))
            .filter { $0.clipID == clip.id && !isPersonHidden($0.authorID) && !isHidden("comment:" + $0.id) }
            .sorted { $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt }
    }
    func addComment(to clip: FoodClip, text: String) -> Bool {
        let body = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !body.isEmpty, visibleClips.contains(where: { $0.id == clip.id }), !account.blocked.contains(clip.authorID) else { return false }
        return change { value in
            var comments = value.videoComments ?? []
            comments.append(VideoComment(clipID: clip.id, authorID: value.profile.id, text: body))
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
        // One explicit timezone prevents travel from granting two rewards for one day.
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
        if change({ $0.claimedDays.insert(day); $0.demoCoins += reward }) {
            tell("A delicious little reward", "\(reward) reward coins added to your balance. They have no cash value.")
        }
    }
    func requestGift(_ gift: FoodGift, quantity: Int, recipient: String, roomID: String?, recharge: @escaping () -> Void, completed: @escaping () -> Void) {
        guard let roomID else { tell("Room gift effects", "Open a room to play a gift effect. Private chats are free."); return }
        guard (1...99).contains(quantity), !isPersonHidden(recipient),
              visibleRooms.contains(where: { $0.id == roomID && $0.hostID == recipient }) else { return }
        let cost = gift.cost * quantity
        requestSpend(cost, title: "Play \(gift.name) ×\(quantity)?", purpose: "Room effect · \(gift.name)",
                     detail: "Plays a gift effect on your screen. It does not transfer coins to the host.", recharge: recharge,
                     valid: { self.visibleRooms.contains { $0.id == roomID && $0.hostID == recipient } },
                     edit: { value in value.gifts.append(GiftReceipt(giftID: gift.id, recipientID: recipient, quantity: quantity, spent: cost, roomID: roomID)) },
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
    private func requestSpend(_ amount: Int, title: String, purpose: String, detail: String,
                              recharge: @escaping () -> Void, valid: @escaping () -> Bool,
                              edit: @escaping (inout LocalAccount) -> Void, completed: @escaping () -> Void) {
        let owner = account.profile.id
        guard account.signedIn, amount > 0, valid() else { return }
        guard coinBalance >= amount else { insufficientCoins(amount, recharge: recharge); return }
        confirm(title, "\(detail)\n\n\(amount.formatted()) coins · Balance \(coinBalance.formatted())", button: "Use \(amount.formatted()) coins") {
            guard self.account.profile.id == owner, self.account.signedIn, valid() else { return }
            guard self.coinBalance >= amount else { self.insufficientCoins(amount, recharge: recharge); return }
            if self.change({ value in
                let bonusUsed = min(value.demoCoins, amount)
                value.demoCoins -= bonusUsed
                value.purchasedCoins -= amount - bonusUsed
                var expenses = value.coinExpenses ?? []
                expenses.append(CoinExpense(title: purpose, coins: amount)); value.coinExpenses = expenses
                edit(&value)
            }) { completed() }
        }
    }
    private func insufficientCoins(_ amount: Int, recharge: @escaping () -> Void) {
        notice = TatiNotice(title: "A little more sparkle", message: "You need \((amount - coinBalance).formatted()) more coins. Your balance is \(coinBalance.formatted()).", actionTitle: "Recharge", action: recharge, artwork: "coin-pile")
    }
    func saveRoomMessage(roomID: String, text: String) -> Bool {
        let body = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        guard !body.isEmpty,
              let room = FoodCatalog.rooms.first(where: { $0.id == roomID }),
              visibleRooms.contains(where: { $0.id == room.id }) else { return false }
        return change { value in
            var messages = value.roomMessages ?? []
            messages.append(LocalRoomMessage(roomID: roomID, text: body))
            let overflow = messages.filter { $0.roomID == roomID }.count - 100
            if overflow > 0 {
                let oldest = Set(messages.filter { $0.roomID == roomID }.prefix(overflow).map(\.id))
                messages.removeAll { oldest.contains($0.id) }
            }
            value.roomMessages = messages
            value.drafts["room-" + roomID] = ""
        }
    }
    func saveDraft(_ key: String, text: String) -> Bool { change { $0.drafts[key] = text } }
    @discardableResult
    func attemptMessage(to recipient: String, text: String) -> Bool {
        let body = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        let attachment = account.draftImages?[recipient]
        guard !body.isEmpty || attachment != nil else { return false }
        guard saveDraft(recipient, text: text), requireMutualFollow(recipient) else { return false }
        // Persist an outbox entry; without transport, never label it delivered.
        return change { value in
            var message = LocalMessage(recipientID: recipient, text: body)
            message.senderID = value.profile.id
            message.imageFile = attachment
            message.status = "Waiting to send"
            value.messages.append(message)
            value.drafts.removeValue(forKey: recipient)
            value.draftImages?.removeValue(forKey: recipient)
        }
    }
    func saveReport(subject: String, reason: String, details: String, imageFile: String? = nil, authorID: String? = nil, contextID: String? = nil, feedback: Bool = false) -> Bool {
        guard !reason.isEmpty else { return false }
        return change { value in
            var report = ReportDraft(subjectID: subject, reason: reason, details: details, imageFile: imageFile)
            report.recorded = true; report.authorID = authorID; report.contextID = contextID
            value.reports.append(report)
            if !feedback {
                var hidden = value.hiddenSubjects ?? []
                hidden.insert(subject)
                value.hiddenSubjects = hidden
            }
        }
    }
    func removeReport(_ report: ReportDraft) {
        if change({ $0.reports.removeAll { $0.id == report.id } }), let file = report.imageFile { removeUnusedMedia(file) }
    }
    func removeUnusedMedia(_ file: String) {
        guard storageFailure == nil else { return }
        let referenced = [account.profile.avatarFile, account.profile.coverFile].compactMap { $0 }
            + account.clips.compactMap(\.fileName) + account.reports.compactMap(\.imageFile)
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
        guard UIImage(data: data) != nil, data.count <= 25 * 1024 * 1024 else { throw CocoaError(.fileReadCorruptFile) }
        let name = UUID().uuidString + ".image"
        try data.write(to: mediaURL(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }
    func videoURL(for clip: FoodClip) -> URL? {
        if let bundled = clip.bundledFile {
            let file = URL(fileURLWithPath: bundled)
            return Bundle.main.url(forResource: file.deletingPathExtension().lastPathComponent, withExtension: file.pathExtension)
        }
        if let local = clip.fileName { return mediaURL(local) }
        return nil
    }
    func authorName(for clip: FoodClip) -> String {
        if clip.isCollection { return "Tati collection" }
        if clip.authorID == account.profile.id { return account.profile.name }
        return FoodCatalog.person(clip.authorID)?.name ?? "Creator"
    }
    func isClipVisible(_ clip: FoodClip) -> Bool {
        !isPersonHidden(clip.authorID) && !isHidden("video:" + clip.id)
            && (clip.bundledFile != nil || clip.moderationStatus == "approved")
    }
    var visibleClips: [FoodClip] { (account.clips + FoodCatalog.sampleClips).filter { isClipVisible($0) } }
    func submitPost(_ clip: FoodClip) -> Bool {
        guard clip.authorID == account.profile.id, clip.fileName != nil else { return false }
        var pending = clip
        pending.moderationStatus = "pendingReview"
        return change { $0.clips.insert(pending, at: 0) }
    }
}
