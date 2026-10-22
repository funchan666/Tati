import SwiftUI
import UIKit

@MainActor
final class TableSessionCoordinator: ObservableObject {
    enum Route: Equatable { case undecided, preparingB, showingA, showingB, webFailure }
    @Published private(set) var route: Route = .undecided
    @Published private(set) var entering = false
    @Published private(set) var errorText: String?
    @Published private(set) var connectionState = "stopped"
    let content = KitchenContentRepository()
    let web = SupperWebOwner()
    private weak var store: MemberKitchenStore?
    private weak var purchases: KitchenCoinPurchases?
    private weak var playback: FoodFilmPlayback?
    private weak var roomSession: CookingRoomSession?
    private let sceneID = UUID()
    private(set) var sessionID = UUID()
    private var sessionValid = false
    private var installed = false
    private var auth: Task<Void, Never>?
    private var routeDeadline: Task<Void, Never>?
    private var receiver: TableBusinessReceiver?
    private var channel: TableMessageChannel?
    private var realtime: ConfiguredRealtimeClient?
    private var theme: KitchenThemeInbox?
    private var coreIDs: Set<String> = []
    private var webPending = false
    private var firstReady = false
    private let authentication = KitchenAuthentication()
    private(set) var lastDiagnostic: String?
    private var deferredPurchases: [ConfiguredCoreEvent] = []

    func install(store: MemberKitchenStore, purchases: KitchenCoinPurchases, playback: FoodFilmPlayback, roomSession: CookingRoomSession) {
        guard !installed else { return }; installed = true
        self.store = store; self.purchases = purchases; self.playback = playback; self.roomSession = roomSession
        content.store = store
        theme = KitchenThemeInbox(store: store)
        content.didInstall = { [weak self] in self?.theme?.drain() }
        purchases.isSessionCurrent = { [weak self] id in self?.sessionValid == true && self?.sessionID == id }
        purchases.didConfirmRemote = { [weak self] in self?.web.webView?.reload() }
        web.didFinish = { [weak self] in self?.webReady() }
        web.didFail = { [weak self] in self?.webFailed() }
        purchases.start(store: store)
        KitchenNetworkGate.shared.didChange = { [weak self] ready in
            if ready { self?.realtime?.networkBecameAvailable() } else { self?.realtime?.networkBecameUnavailable() }
        }
        KitchenNetworkGate.shared.start(); TablePushToken.shared.start()
        if store.account.signedIn { begin(restoring: true) }
    }
    func begin(restoring: Bool = false) {
        guard !entering, let store, store.storageFailure == nil, let purchases else { return }
        clearSession(keepError: false)
        entering = true; route = .undecided; sessionValid = true
        let captured = sessionID
        auth = Task {
            await purchases.waitForStartupRelease()
            guard isCurrent(captured), !Task.isCancelled else { return }
            content.reload()
            do {
                let result = try await authentication.authenticate()
                guard isCurrent(captured), !Task.isCancelled else { return }
                switch result {
                case .native: commitNative()
                case .connected(let ticket): try connect(ticket, captured: captured)
                }
            } catch {
                guard isCurrent(captured), !Task.isCancelled else { return }
                loginFailed()
            }
        }
    }
    func isCurrent(_ id: UUID) -> Bool { sessionValid && sessionID == id }
    private func connect(_ ticket: ConfiguredRealtimeTicket, captured: UUID) throws {
        let context = TableMessageContext(sessionID: captured, sceneID: sceneID)
        let channel = TableMessageChannel(context: context)
        self.channel = channel
        receiver = try TableBusinessReceiver(channel: channel, isCurrent: { [weak self] context in self?.isCurrent(context.sessionID) == true && self?.sceneID == context.sceneID }, core: { [weak self] event in try self?.accept(event) }, theme: { [weak self] event in try self?.theme?.accept(event) })
        var callbacks = ConfiguredRealtimeClient.Callbacks()
        callbacks.onState = { [weak self] state in
            guard let self, self.isCurrent(captured) else { return }
            self.connectionState = String(describing: state)
            if (state == .failed || state == .closed) && self.entering && !self.webPending { self.loginFailed() }
        }
        callbacks.onReady = { [weak self] first in
            guard let self, self.isCurrent(captured) else { return }
            self.theme?.reconnect()
            guard first, !self.firstReady else { return }; self.firstReady = true
            guard self.route == .undecided, !self.webPending else { return }
            self.routeDeadline = Task {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                guard self.isCurrent(captured), self.route == .undecided, !self.webPending else { return }
                self.commitNative()
            }
        }
        callbacks.onMessage = { [weak self, weak channel] message in
            guard let self, self.isCurrent(captured) else { return }
            guard let channel, channel.post(message) else { self.loginFailed(); return }
        }
        callbacks.onDiagnostic = { [weak self] reason in
            guard let self, self.isCurrent(captured) else { return }
            self.lastDiagnostic = reason
        }
        let client = ConfiguredRealtimeClient(callbacks: callbacks, refresh: { [weak self] completion in
            let task = Task { @MainActor in
                guard let self, self.isCurrent(captured) else { completion(.failure(KitchenServiceFailure.cancelled)); return }
                do {
                    let result = try await self.authentication.authenticate()
                    guard self.isCurrent(captured), !Task.isCancelled else { completion(.failure(KitchenServiceFailure.cancelled)); return }
                    guard case .connected(let ticket) = result else { throw KitchenServiceFailure.configuration }
                    completion(.success(ticket))
                } catch { completion(.failure(error)) }
            }
            return { task.cancel() }
        })
        realtime = client
        theme?.publish = { [weak self] event, completion in
            guard let self, self.isCurrent(captured), let realtime = self.realtime else { completion(false); return }
            realtime.publish(name: event.name, data: event.data) { result in
                if case .success = result { completion(true) } else { completion(false) }
            }
        }
        client.connect(ticket: ticket)
    }
    private func accept(_ event: ConfiguredCoreEvent) throws {
        guard isCurrent(event.requestID), !coreIDs.contains(event.messageID) else { return }
        switch event.kind {
        case .page:
            guard route != .showingA else { return }
            switch event.pageDestination {
            case .absent:
                guard route == .undecided else { return }
                coreIDs.insert(event.messageID); routeDeadline?.cancel(); commitNative()
            case .url(let url):
                guard route == .undecided || route == .showingB else { return }
                coreIDs.insert(event.messageID)
                if route == .showingB { web.prepare(url); return }
                webPending = true; routeDeadline?.cancel(); routeDeadline = nil
                route = .preparingB
                playback?.stop(); roomSession?.leave()
                web.prepare(url)
            case .invalid, .notPage: loginFailed(); throw KitchenServiceFailure.configuration
            }
        case .purchase:
            guard route == .showingA || route == .showingB else {
                guard deferredPurchases.count < 8, !deferredPurchases.contains(where: { $0.messageID == event.messageID }) else { return }
                deferredPurchases.append(event); return
            }
            guard let request = event.purchase else { throw KitchenServiceFailure.configuration }
            coreIDs.insert(event.messageID)
            let captured = sessionID
            Task { await purchases?.buyFromTable(productID: request.sku, reference: request.reference, session: captured) }
        case .expire:
            coreIDs.insert(event.messageID)
            _ = store?.change { $0.signedIn = false }
            clearSession(keepError: false)
        case .externalOpen:
            guard let url = event.externalURL else { throw KitchenServiceFailure.configuration }
            coreIDs.insert(event.messageID)
            let captured = sessionID
            UIApplication.shared.open(url, options: [:]) { [weak self] opened in
                Task { @MainActor in
                    guard let self, self.isCurrent(captured), !opened else { return }
                    self.store?.tell("Link unavailable", "Your device could not open this link.")
                }
            }
        }
    }
    private func commitNative() {
        guard sessionValid, route == .undecided, !webPending else { return }
        store?.signIn()
        guard store?.account.signedIn == true else { loginFailed(); return }
        route = .showingA; entering = false; errorText = nil; drainPurchases()
    }
    private func drainPurchases() {
        let pending = deferredPurchases; deferredPurchases.removeAll()
        for event in pending { try? accept(event) }
    }
    private func webReady() {
        guard sessionValid, webPending, route == .preparingB else { return }
        store?.signIn()
        guard store?.account.signedIn == true else { loginFailed(); return }
        webPending = false; route = .showingB; entering = false; errorText = nil; drainPurchases()
    }
    private func webFailed() {
        guard sessionValid else { return }
        routeDeadline?.cancel(); routeDeadline = nil; webPending = false
        route = .webFailure; entering = false
        errorText = "The page could not be opened. You can try again or return to the welcome screen."
    }
    func retryWeb() {
        guard route == .webFailure, sessionValid else { return }
        errorText = nil; entering = true; webPending = true; route = .preparingB; web.retry()
    }
    func returnToWelcome() { clearSession(keepError: false) }
    private func loginFailed() {
        clearSession(keepError: false)
        errorText = "Tati could not finish connecting. Please try again."
    }
    func signedOut() { clearSession(keepError: false) }
    private func clearSession(keepError: Bool) {
        sessionValid = false; sessionID = UUID()
        auth?.cancel(); auth = nil; routeDeadline?.cancel(); routeDeadline = nil
        receiver?.stop(); receiver = nil; channel = nil
        realtime?.stop(); realtime = nil; theme?.stop(); theme?.publish = nil
        web.stop(); content.clear(); coreIDs.removeAll(); deferredPurchases.removeAll(); firstReady = false; webPending = false
        playback?.stop(); roomSession?.leave()
        route = .undecided; entering = false
        if !keepError { errorText = nil }
    }
    func becameActive(_ active: Bool) {
        KitchenNetworkGate.shared.setActive(active); web.setActive(active); theme?.setActive(active)
        if active {
            realtime?.applicationDidBecomeActive()
            Task { await TablePushToken.shared.becameActive() }
        }
    }
    func wake(_ url: URL) {
        guard url.scheme == Bundle.main.bundleIdentifier else { return }
        becameActive(UIApplication.shared.applicationState == .active)
    }
}
