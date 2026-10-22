import Foundation
import UIKit
import UserNotifications
import Alamofire

@MainActor
final class KitchenNetworkGate {
    static let shared = KitchenNetworkGate()
    private(set) var ready = false
    var didChange: ((Bool) -> Void)?
    private let reachability = NetworkReachabilityManager()
    private var started = false
    private var active = false
    private var generation = UUID()
    private var probe: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var failures = 0
    private struct Waiter {
        let continuation: CheckedContinuation<Void, Error>
        var remaining: TimeInterval = 30
        var since: Date?
    }
    private var waiters: [UUID: Waiter] = [:]
    private var budgetTimer: Task<Void, Never>?
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 12; configuration.timeoutIntervalForResource = 15
        configuration.httpShouldSetCookies = false; configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: KitchenHTTP.shared, delegateQueue: nil)
    }()
    func start() {
        guard !started else { return }; started = true
        active = UIApplication.shared.applicationState == .active
        _ = reachability?.startListening(onQueue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.invalidate() }
        }
        launchProbe()
    }
    func setActive(_ value: Bool) {
        guard active != value else { return }
        accountBudgets(); active = value
        for id in Array(waiters.keys) { waiters[id]?.since = value ? Date() : nil }
        scheduleBudget()
        if value { if !ready { launchProbe() } }
        else { retry?.cancel(); retry = nil }
    }
    func invalidate() {
        generation = UUID(); ready = false; didChange?(false)
        probe?.cancel(); probe = nil; retry?.cancel(); retry = nil; failures = 0
        if active { launchProbe() }
    }
    func waitUntilReady() async throws {
        try Task.checkCancellation()
        if ready { return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                waiters[id] = Waiter(continuation: continuation, since: active ? Date() : nil)
                scheduleBudget(); launchProbe()
            }
        } onCancel: { Task { @MainActor in self.finish(id, error: CancellationError()) } }
    }
    private func accountBudgets() {
        let now = Date()
        for id in Array(waiters.keys) {
            if let since = waiters[id]?.since { waiters[id]?.remaining -= now.timeIntervalSince(since); waiters[id]?.since = now }
        }
    }
    private func scheduleBudget() {
        budgetTimer?.cancel(); budgetTimer = nil
        guard active, let seconds = waiters.values.map(\.remaining).min() else { return }
        budgetTimer = Task {
            do { try await Task.sleep(for: .seconds(max(0.01, seconds))) } catch { return }
            accountBudgets()
            for id in Array(waiters.keys) where (waiters[id]?.remaining ?? 0) <= 0 { finish(id, error: KitchenServiceFailure.network) }
            scheduleBudget()
        }
    }
    private func finish(_ id: UUID, error: Error?) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        if let error { waiter.continuation.resume(throwing: error) } else { waiter.continuation.resume() }
    }
    private func launchProbe() {
        guard active, !ready, probe == nil else { return }
        retry?.cancel(); retry = nil
        let captured = generation
        probe = Task {
            var reached = false
            do {
                guard let base = IntegrationContract.baseURLString, let url = URL(string: base + "/") else { throw KitchenServiceFailure.configuration }
                var request = URLRequest(url: url); request.httpMethod = "HEAD"
                let (_, response) = try await session.data(for: request)
                reached = response is HTTPURLResponse
            } catch { }
            guard captured == generation, !Task.isCancelled else { return }
            probe = nil
            if reached {
                ready = true; failures = 0; didChange?(true)
                for id in Array(waiters.keys) { finish(id, error: nil) }
                budgetTimer?.cancel(); budgetTimer = nil
            } else if active {
                let delays: [Double] = [2, 4, 8, 16, 30]
                let delay = delays[min(failures, delays.count - 1)]; failures += 1
                retry = Task { do { try await Task.sleep(for: .seconds(delay)) } catch { return }; launchProbe() }
            }
        }
    }
}

@MainActor
final class TablePushToken {
    static let shared = TablePushToken()
    private(set) var token = ""
    private var settled = false
    private var permissionRequest: Task<Bool, Never>?
    private var started = false
    private var requestedThisProcess = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var deadlines: [UUID: Task<Void, Never>] = [:]
    func start() {
        guard !started else { return }; started = true
        UIApplication.shared.registerForRemoteNotifications()
        Task { await becameActive() }
    }
    func becameActive() async {
        guard UIApplication.shared.applicationState == .active else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .notDetermined, !requestedThisProcess { _ = await requestPermission() }
        else if status == .denied { settle() }
        else if token.isEmpty { UIApplication.shared.registerForRemoteNotifications() }
    }
    func requestPermission() async -> Bool {
        if let permissionRequest { return await permissionRequest.value }
        requestedThisProcess = true
        let task = Task { () -> Bool in
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            if status == .authorized || status == .provisional || status == .ephemeral {
                UIApplication.shared.registerForRemoteNotifications(); return true
            }
            guard status == .notDetermined else { settle(); return false }
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) == true
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            else { settle() }
            return granted
        }
        permissionRequest = task
        let value = await task.value; permissionRequest = nil
        return value
    }
    func registered(_ bytes: Data) { token = bytes.map { String(format: "%02x", $0) }.joined(); settle() }
    func failed() { settle() }
    private func settle() {
        settled = true
        for id in Array(waiters.keys) { finish(id) }
    }
    func waitForToken() async {
        if !token.isEmpty || settled || Task.isCancelled { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { continuation.resume(); return }
                waiters[id] = continuation
                deadlines[id] = Task {
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                    finish(id)
                }
            }
        } onCancel: { Task { @MainActor in self.finish(id) } }
    }
    private func finish(_ id: UUID) {
        deadlines.removeValue(forKey: id)?.cancel()
        waiters.removeValue(forKey: id)?.resume()
    }
}

final class TableApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in TablePushToken.shared.registered(deviceToken) }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in TablePushToken.shared.failed() }
    }
}
