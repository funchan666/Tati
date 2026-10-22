import Foundation

@MainActor
final class TableBusinessReceiver {
    private var observer: NSObjectProtocol?
    private let channel: TableMessageChannel
    private let dispatcher: ConfiguredEventDispatcher
    private let isCurrent: (TableMessageContext) -> Bool
    private(set) var lastRejection: String?
    init(channel: TableMessageChannel, isCurrent: @escaping (TableMessageContext) -> Bool, core: @escaping ConfiguredEventDispatcher.CoreHandler, theme: @escaping ConfiguredEventDispatcher.ThemeHandler) throws {
        self.channel = channel; self.isCurrent = isCurrent
        dispatcher = try ConfiguredEventDispatcher(coreHandler: core, themeHandlers: [.tableFollow: theme, .filmSafety: theme, .tableReceiptAccepted: theme])
        observer = NotificationCenter.default.addObserver(forName: .tableBusinessMessage, object: channel, queue: nil) { [weak self] notification in
            MainActor.assumeIsolated { self?.receive(notification) }
        }
        channel.receiverIsReady = true
    }
    private func receive(_ notification: Notification) {
        guard notification.object as? TableMessageChannel === channel,
              let envelope = notification.userInfo?["envelope"] as? TableMessageEnvelope,
              envelope.context == channel.context, isCurrent(envelope.context) else { return }
        do {
            let message = envelope.message
            let event = try ConfiguredIncomingEvent.parse(requestID: envelope.context.sessionID, transportID: message.id, name: message.name, clientID: message.clientID, data: message.data)
            try dispatcher.dispatch(event)
        } catch { lastRejection = "rejected_business_message" }
    }
    func stop() {
        channel.receiverIsReady = false
        if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}
