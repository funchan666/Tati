import SwiftUI
import MessageUI
import ImageIO
import UniformTypeIdentifiers

enum TatiSupportMailbox {
    static let address = "hudden.serudiv22@gmail.com"
}

private struct SupportMailDraft: Identifiable {
    let id = UUID()
    let subject: String
    let body: String
    let evidenceData: Data?
}

struct SupportMailboxButton: View {
    var subject = "Tati support"
    var message = ""
    var evidence: Data? = nil
    var title = "Email support"
    var enabled = true
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var mailDraft: SupportMailDraft?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TatiButton(title: title, secondary: true, enabled: enabled) {
                guard MFMailComposeViewController.canSendMail() else {
                    store.tell("Mail is unavailable", "Email hudden.serudiv22@gmail.com from your mail app. You can copy the address below. Your report text has been kept.")
                    return
                }

                mailDraft = SupportMailDraft(subject: subject, body: message, evidenceData: evidence)
            }
            Text(TatiSupportMailbox.address).font(.tati(.caption)).textSelection(.enabled)
            Button("Copy email address") { UIPasteboard.general.string = TatiSupportMailbox.address }
                .font(.tati(.caption, weight: .semibold)).buttonStyle(.plain).frame(minHeight: 44)
        }
        .sheet(item: $mailDraft) { draft in
            SupportMailComposer(draft: draft) { result in
                mailDraft = nil
                if result == .sent {
                    store.tell("Mail accepted", "Your email was handed to Mail. Delivery and a reply depend on your mail account and the support team.")
                } else if result == .failed {
                    store.tell("Email not sent", "Mail could not send the message. Your text is still here; you can try again or use the support address.")
                }
            }.ignoresSafeArea(.container)
        }
    }
}

private struct SupportMailComposer: UIViewControllerRepresentable {
    let draft: SupportMailDraft
    let finished: (MFMailComposeResult) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([TatiSupportMailbox.address])
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        if let evidence = draft.evidenceData,
           let source = CGImageSourceCreateWithData(evidence as CFData, nil),
           let identifier = CGImageSourceGetType(source), let type = UTType(identifier as String) {
            controller.addAttachmentData(evidence, mimeType: type.preferredMIMEType ?? "application/octet-stream",
                                         fileName: "report-evidence." + (type.preferredFilenameExtension ?? "image"))
        }
        return controller
    }
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let finished: (MFMailComposeResult) -> Void
        init(finished: @escaping (MFMailComposeResult) -> Void) { self.finished = finished }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) { finished(error == nil ? result : .failed) }
    }
}
