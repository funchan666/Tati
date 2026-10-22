import Foundation

struct TableMessageContext: Equatable {
    let sessionID: UUID
    let sceneID: UUID
}
struct TableMessageEnvelope {
    let context: TableMessageContext
    let message: ConfiguredRealtimeMessage
}
extension Notification.Name {
    static let tableBusinessMessage = Notification.Name("com.tati.app.table-business-message")
}
@MainActor
final class TableMessageChannel {
    let context: TableMessageContext
    var receiverIsReady = false
    init(context: TableMessageContext) { self.context = context }
    func post(_ message: ConfiguredRealtimeMessage) -> Bool {
        guard receiverIsReady else { return false }
        NotificationCenter.default.post(name: .tableBusinessMessage, object: self, userInfo: ["envelope": TableMessageEnvelope(context: context, message: message)])
        return true
    }
}
