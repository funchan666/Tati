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
            }
        } catch {
            storageFailure = "Your saved data could not be opened. It has not been replaced. Please check available storage before trying again."
        }
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
    func signIn() { _ = change { $0.signedIn = true } }
    func logout() {
        confirm("Leave Tati?", "Your profile and saved content will be kept when you log out.", button: "Log out") {
            _ = self.change { $0.signedIn = false }
        }
    }
    func deleteVisitor() {
        confirm("Delete profile?", "This permanently removes your Tati profile, imported photos and videos, drafts and rewards from app storage.", button: "Delete", destructive: true) {
            let files = [self.account.profile.avatarFile, self.account.profile.coverFile].compactMap { $0 } + self.account.clips.compactMap(\.fileName) + self.account.reports.compactMap(\.imageFile) + self.account.messages.compactMap(\.imageFile) + Array((self.account.draftImages ?? [:]).values)
            guard self.change({ $0 = LocalAccount() }) else { return }
            var cleanupFailed = false
            for file in files where FileManager.default.fileExists(atPath: self.mediaURL(file).path) {
                do { try FileManager.default.removeItem(at: self.mediaURL(file)) } catch { cleanupFailed = true }
            }
            if cleanupFailed { self.tell("Profile deleted", "Some imported files could not be removed. Uninstall Tati to erase the remaining app data.") }
        }
    }
    func toggleFollow(_ id: String) {
        guard id != account.profile.id, FoodCatalog.person(id) != nil else { return }
        guard !isPersonHidden(id) else { tell("Profile unavailable", "This profile is hidden or blocked."); return }
        _ = change { if $0.following.contains(id) { $0.following.remove(id) } else { $0.following.insert(id) } }
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
    var mutualIDs: Set<String> { account.following.intersection(account.followers ?? []).filter { !isPersonHidden($0) } }
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
        _ = change { if $0.likes.contains(id) { $0.likes.remove(id) } else { $0.likes.insert(id) } }
    }
    func likeCount(for clip: FoodClip) -> Int { account.likes.contains(clip.id) ? 1 : 0 }
    func comments(for clip: FoodClip) -> [VideoComment] {
        (account.videoComments ?? []).filter { $0.clipID == clip.id && !isPersonHidden($0.authorID) && !isHidden("comment:" + $0.id) }
            .sorted { $0.createdAt < $1.createdAt }
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
    func previewGift(_ gift: FoodGift, quantity: Int, recipient: String, roomID: String? = nil) -> Bool {
        guard (1...99).contains(quantity), FoodCatalog.person(recipient) != nil, !isPersonHidden(recipient) else { return false }
        if let roomID {
            guard visibleRooms.contains(where: { $0.id == roomID && $0.hostID == recipient }) else { return false }
        }
        let total = gift.cost * quantity
        guard account.demoCoins >= total else { tell("More reward coins needed", "Visit Check-in to collect reward coins. No purchase is required."); return false }
        return change { value in
            value.demoCoins -= total
            value.gifts.append(GiftReceipt(giftID: gift.id, recipientID: recipient, quantity: quantity, spent: total, roomID: roomID))
        }
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
