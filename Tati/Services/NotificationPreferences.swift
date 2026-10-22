import SwiftUI
import UserNotifications

@MainActor
final class NotificationPreferences: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var authorized = false
    private let center = UNUserNotificationCenter.current()
    private let reminderID = "tati.daily-check-in"
    private var refreshTask: Task<Void, Never>?

    /// Serialize reconciliation so an older language/account request cannot overwrite a newer one.
    func refresh(store: VisitorStore) {
        let previous = refreshTask
        previous?.cancel()
        refreshTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let settings = await center.notificationSettings()
            guard !Task.isCancelled else { return }
            authorized = Self.permitsAlerts(settings.authorizationStatus)
            center.removePendingNotificationRequests(withIdentifiers: [reminderID])
            // A revoked system permission must not leave an apparently enabled preference.
            if !authorized && store.account.notifications { _ = store.change { $0.notifications = false } }
            guard store.account.signedIn, store.account.notifications, authorized else {
                center.removeDeliveredNotifications(withIdentifiers: [reminderID])
                return
            }
            let language = AppLanguage.preference(store.account.preferredLanguage)
            let content = UNMutableNotificationContent()
            content.title = language.text("A little treat from Tati")
            content.body = language.text("Drop by Tati for food, friends and your daily check-in.")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 19, minute: 0), repeats: true)
            do {
                try await center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
            } catch {
                guard !Task.isCancelled else { return }
                store.tell("Reminder unavailable", "Your reminder could not be scheduled. Try again from Settings.")
            }
        }
    }

    func toggle(store: VisitorStore) async {
        guard !busy, store.account.signedIn else { return }
        busy = true
        defer { busy = false; refresh(store: store) }
        let owner = store.account.profile.id
        let settings = await center.notificationSettings()
        guard store.account.signedIn, store.account.profile.id == owner else { return }
        authorized = Self.permitsAlerts(settings.authorizationStatus)
        if store.account.notifications && authorized {
            _ = store.change { $0.notifications = false }
            return
        }
        if settings.authorizationStatus == .denied {
            store.confirm("Notifications are off", "Allow notifications in iPhone Settings, then return to Tati to enable your daily reminder.", button: "Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            return
        }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard store.account.signedIn, store.account.profile.id == owner else { return }
            authorized = granted
            if granted { _ = store.change { $0.notifications = true } }
            else { store.tell("Notifications are off", "You can enable notifications later in iPhone Settings.") }
        } catch {
            guard store.account.signedIn, store.account.profile.id == owner else { return }
            store.tell("Notifications unavailable", "The permission request could not finish. Please try again.")
        }
    }

    private static func permitsAlerts(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }
}
