import SwiftUI

struct TatiNotice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var actionTitle: String = "OK"
    var action: (() -> Void)?
    var destructive = false
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
            storageFailure = "Your local data could not be opened. It has not been replaced. Please free storage or restore the original file before continuing."
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
            storageFailure = "Local storage could not be verified. Further changes are paused to protect your data. Reopen Tati after checking device storage."
            tell("Couldn't verify save", storageFailure!)
            return false
        }
    }
    func tell(_ title: String, _ message: String) { notice = TatiNotice(title: title, message: message) }
    func confirm(_ title: String, _ message: String, button: String, destructive: Bool = false, action: @escaping () -> Void) {
        notice = TatiNotice(title: title, message: message, actionTitle: button, action: action, destructive: destructive)
    }
    func signIn() { _ = change { $0.signedIn = true } }
    func logout() {
        confirm("Leave Tati?", "Your guest profile and drafts stay on this device. You can return to the same local profile.", button: "Log out") {
            _ = self.change { $0.signedIn = false }
        }
    }
    func deleteVisitor() {
        confirm("Delete local profile?", "This removes this guest profile, local photos, videos, drafts and rewards from this device. There is no server account to delete.", button: "Delete", destructive: true) {
            let files = [self.account.profile.avatarFile, self.account.profile.coverFile].compactMap { $0 } + self.account.clips.compactMap(\.fileName) + self.account.reports.compactMap(\.imageFile) + Array((self.account.draftImages ?? [:]).values)
            guard self.change({ $0 = LocalAccount() }) else { return }
            var cleanupFailed = false
            for file in files where FileManager.default.fileExists(atPath: self.mediaURL(file).path) {
                do { try FileManager.default.removeItem(at: self.mediaURL(file)) } catch { cleanupFailed = true }
            }
            if cleanupFailed { self.tell("Profile deleted", "Some imported media files could not be removed from app storage. Remove Tati from this device to erase its remaining local storage.") }
        }
    }
    func toggleFollow(_ id: String) {
        guard !account.blocked.contains(id) else { tell("Blocked profile", "Unblock this profile in Settings to follow it."); return }
        _ = change { if $0.following.contains(id) { $0.following.remove(id) } else { $0.following.insert(id) } }
    }
    func block(_ id: String) {
        confirm("Block this profile?", "Their sample rooms and videos will be hidden on this device. You can undo this in your blacklist.", button: "Block", destructive: true) {
            _ = self.change { $0.blocked.insert(id); $0.following.remove(id) }
        }
    }
    func toggleLike(_ id: String) {
        _ = change { if $0.likes.contains(id) { $0.likes.remove(id) } else { $0.likes.insert(id) } }
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
            tell("A delicious little reward", "\(reward) demo coins saved on this device. They can be used for local gifts. They have no cash value.")
        }
    }
    func previewGift(_ gift: FoodGift, quantity: Int, recipient: String) -> Bool {
        guard (1...99).contains(quantity), FoodCatalog.person(recipient) != nil, !account.blocked.contains(recipient) else { return false }
        let total = gift.cost * quantity
        guard account.demoCoins >= total else { tell("More demo coins needed", "Visit Check-in to collect local demo coins. No purchase is required for local gifts."); return false }
        return change { value in
            value.demoCoins -= total
            value.gifts.append(GiftReceipt(giftID: gift.id, recipientID: recipient, quantity: quantity, spent: total))
        }
    }
    func saveDraft(_ key: String, text: String) -> Bool { change { $0.drafts[key] = text } }
    func attemptMessage(to recipient: String, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard saveDraft(recipient, text: text) else { return }
        if account.blocked.contains(recipient) { tell("Profile blocked", "Unblock this profile before messaging."); return }
        tell("Not sent", "Messaging requires a connected service and mutual follows. Sample profiles cannot receive messages. Your text is saved as a local draft.")
    }
    func saveReport(subject: String, reason: String, details: String, imageFile: String? = nil) -> Bool {
        change { $0.reports.append(ReportDraft(subjectID: subject, reason: reason, details: details, imageFile: imageFile)) }
    }
    func removeReport(_ report: ReportDraft) {
        if change({ $0.reports.removeAll { $0.id == report.id } }), let file = report.imageFile { removeUnusedMedia(file) }
    }
    func removeUnusedMedia(_ file: String) {
        guard storageFailure == nil else { return }
        let referenced = [account.profile.avatarFile, account.profile.coverFile].compactMap { $0 }
            + account.clips.compactMap(\.fileName) + account.reports.compactMap(\.imageFile)
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
    var visibleClips: [FoodClip] { (account.clips + FoodCatalog.sampleClips).filter { !account.blocked.contains($0.authorID) } }
}
