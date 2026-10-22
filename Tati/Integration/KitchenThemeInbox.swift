import Foundation

struct KitchenThemeChange: Codable {
    let id: String
    let signal: String
    let payload: Data
    let arrivedAt: Date
}
struct TableChangeReceipt: Codable {
    let id: String
    let changeID: String
    let createdAt: Date
    let stage: String
}
struct KitchenThemeState: Codable {
    var hiddenFilmIDs: Set<String> = []
    var applied: Set<String> = []
    var revisions: [String: Int] = [:]
    var pending: [KitchenThemeChange] = []
    var receipts: [TableChangeReceipt] = []
}
@MainActor
final class KitchenThemeInbox {
    private weak var store: MemberKitchenStore?
    var publish: ((ConfiguredOutboundEvent, @escaping (Bool) -> Void) -> Void)?
    private var inFlight: Set<String> = []
    private var retry: Task<Void, Never>?
    private var active = true
    init(store: MemberKitchenStore) { self.store = store }
    func accept(_ event: ConfiguredThemeEvent) throws {
        guard let store else { throw KitchenServiceFailure.storage }
        if event.signal == .tableReceiptAccepted {
            guard let id = event.values["receiptID"] as? String else { throw KitchenServiceFailure.response }
            guard store.change({ value in
                var state = value.tableSyncState ?? KitchenThemeState()
                state.receipts.removeAll { $0.id == id }; value.tableSyncState = state
            }) else { throw KitchenServiceFailure.storage }
            inFlight.remove(id); return
        }
        guard let id = event.values["changeID"] as? String, !id.isEmpty else { throw KitchenServiceFailure.response }
        let state = store.account.tableSyncState ?? KitchenThemeState()
        if state.applied.contains(id) { flush(); return }
        if state.pending.contains(where: { $0.id == id }) { return }
        let change = KitchenThemeChange(id: id, signal: event.signal.rawValue, payload: try JSONSerialization.data(withJSONObject: event.values), arrivedAt: Date())
        guard state.pending.count < 1000, store.change({ value in
            var next = value.tableSyncState ?? KitchenThemeState(); next.pending.append(change); value.tableSyncState = next
        }) else { throw KitchenServiceFailure.storage }
        drain()
    }
    func drain() {
        guard let store, KitchenContentSnapshot.current != nil else { return }
        for change in (store.account.tableSyncState?.pending ?? []) {
            if Date().timeIntervalSince(change.arrivedAt) > 86400 {
                guard store.change({ value in
                    var state = value.tableSyncState ?? KitchenThemeState()
                    state.pending.removeAll { $0.id == change.id }; state.applied.insert(change.id)
                    if !state.receipts.contains(where: { $0.changeID == change.id }) {
                        state.receipts.append(TableChangeReceipt(id: UUID().uuidString, changeID: change.id, createdAt: Date(), stage: "expired"))
                    }
                    value.tableSyncState = state
                }) else { return }
                continue
            }
            guard let values = (try? JSONSerialization.jsonObject(with: change.payload)) as? [String: Any],
                  let revision = ConfiguredRealtimeJSON.integer(values["revision"]), revision >= 0, revision <= Int64(Int.max),
                  let signal = ConfiguredThemeContract.Signal(rawValue: change.signal) else { continue }
            let entity: String
            switch signal {
            case .tableFollow:
                guard let member = values["memberID"] as? String, TableCommunity.person(member) != nil, values["followsYou"] is Bool else { continue }
                entity = "follow:" + member
            case .filmSafety:
                guard let film = values["filmID"] as? String, KitchenEditorialLibrary.activeFilmIDs.contains(film) || store.account.clips.contains(where: { $0.id == film }), values["hidden"] is Bool else { continue }
                entity = "video:" + film
            default: continue
            }
            let expired = Date().timeIntervalSince(change.arrivedAt) > 86400
            guard store.change({ value in
                var state = value.tableSyncState ?? KitchenThemeState()
                let isNewer = Int(revision) > (state.revisions[entity] ?? -1)
                if isNewer && !expired {
                    if signal == .tableFollow, let member = values["memberID"] as? String, let follows = values["followsYou"] as? Bool {
                        var followers = value.followers ?? []
                        if follows && !value.blocked.contains(member) { followers.insert(member) } else { followers.remove(member) }
                        value.followers = followers
                    } else if signal == .filmSafety, let film = values["filmID"] as? String, let hidden = values["hidden"] as? Bool {
                        if hidden { state.hiddenFilmIDs.insert(film) } else { state.hiddenFilmIDs.remove(film) }
                    }
                    state.revisions[entity] = Int(revision)
                }
                state.applied.insert(change.id); state.pending.removeAll { $0.id == change.id }
                if !state.receipts.contains(where: { $0.changeID == change.id }) {
                    state.receipts.append(TableChangeReceipt(id: UUID().uuidString, changeID: change.id, createdAt: Date(), stage: expired ? "expired" : isNewer ? "applied" : "superseded"))
                }
                value.tableSyncState = state
            }) else { return }
        }
        flush()
    }
    func reconnect() {
        inFlight.removeAll(); drain()
        guard let store, let event = try? ConfiguredThemeEvent.makeOutbound(signal: .tableSync, values: ["profileID": store.account.profile.id, "revisions": store.account.tableSyncState?.revisions ?? [:]]) else { return }
        publish?(event) { _ in }
    }
    func flush() {
        guard active, let store, let publish else { return }
        let owner = store.account.profile.id
        for receipt in store.account.tableSyncState?.receipts ?? [] where !inFlight.contains(receipt.id) {
            guard let event = try? ConfiguredThemeEvent.makeOutbound(signal: .tableReceipt, values: ["receiptID": receipt.id, "changeID": receipt.changeID, "stage": receipt.stage]) else { continue }
            inFlight.insert(receipt.id)
            publish(event) { [weak self] _ in
                guard let self, self.store?.account.profile.id == owner else { return }
                self.inFlight.remove(receipt.id)
            }
        }
        scheduleRetry()
    }
    private func scheduleRetry() {
        guard retry == nil, active, let store, !(store.account.tableSyncState?.receipts.isEmpty ?? true) else { return }
        let owner = store.account.profile.id
        retry = Task {
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            retry = nil
            guard active, self.store?.account.profile.id == owner else { return }
            flush()
        }
    }
    func setActive(_ active: Bool) {
        self.active = active
        if active { reconnect() } else { retry?.cancel(); retry = nil }
    }
    func stop() { retry?.cancel(); retry = nil; inFlight.removeAll() }
}
