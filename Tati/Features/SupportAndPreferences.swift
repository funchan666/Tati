import SwiftUI
import PhotosUI

struct PhotoAttachmentPicker: View {
    @Binding var data: Data?
    @State private var item: PhotosPickerItem?
    @Binding var loading: Bool
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PhotosPicker(selection: $item, matching: .images) {
                    Group {
                        if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 112, height: 112).clipped() }
                        else { Art(name: "add-photo", width: 42, height: 42).frame(width: 112, height: 112).background(Color.tatiLime.opacity(0.6)) }
                    }.clipShape(RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).disabled(loading).accessibilityLabel("Choose attachment photo")
                if data != nil { ArtButton(asset: "remove", label: "Remove attachment") { data = nil; item = nil } }
            }
            if loading { Note(text: "Loading photo…") }
        }.task(id: item) {
            guard let item else { return }
            loading = true; defer { loading = false }
            do {
                guard let selected = try await item.loadTransferable(type: Data.self), selected.count <= 25 * 1024 * 1024, UIImage(data: selected) != nil else { throw CocoaError(.fileReadCorruptFile) }
                guard !Task.isCancelled else { return }; data = selected
            } catch { if !Task.isCancelled { store.tell("Photo unavailable", "Choose a supported photo smaller than 25 MB. Your text has been kept.") } }
        }
    }
}
struct DraftPhotoAttachment: View {
    var draftKey: String
    @EnvironmentObject private var store: VisitorStore
    @State private var selection: PhotosPickerItem?
    @State private var importing = false
    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selection, matching: .images) { Art(name: "chat-photo", width: 36, height: 36).frame(width: 44, height: 44) }
                .buttonStyle(.plain).disabled(importing).accessibilityLabel("Attach local photo")
            if let file = store.account.draftImages?[draftKey], let image = UIImage(contentsOfFile: store.mediaURL(file).path) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 70, height: 70).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                Note(text: "Local attachment · not sent")
                ArtButton(asset: "remove", label: "Remove draft photo") { _ = store.saveDraftImage(nil, key: draftKey); selection = nil }
            } else { Note(text: importing ? "Importing photo…" : "Optional photo draft") }
        }.task(id: selection) {
            guard let selection else { return }; let owner = store.account.profile.id
            importing = true; defer { importing = false }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self), !Task.isCancelled, owner == store.account.profile.id else { return }
                _ = store.saveDraftImage(data, key: draftKey)
            } catch { if !Task.isCancelled { store.tell("Photo unavailable", "Your existing draft has been kept. Choose another photo.") } }
        }
    }
}
struct HelpArticle: Identifiable {
    var id: String { question }
    var question: String
    var answer: String
}
struct SupportView: View {
    @State private var query = ""
    @State private var expanded: Set<String> = []
    private let articles = [
        HelpArticle(question: "How do I recharge diamonds?", answer: "Open your wallet from Me, or tap the balance inside the gift panel. This local edition has no configured App Store products, so recharge is unavailable and no charge is made. Free demo coins come from daily check-ins."),
        HelpArticle(question: "My purchase is still processing", answer: "Tati's local edition cannot start a purchase. If a future connected version shows a pending Apple transaction, wait for its verified status rather than buying the same package again. Demo coins are separate from purchased coins."),
        HelpArticle(question: "Why did my call pause?", answer: "Live calls are not connected in this edition. Local video and camera previews stop when you leave the page or the app enters the background. Nothing is streamed to a remote person."),
        HelpArticle(question: "How can I change my language?", answer: "Open Settings, then Language. You can save a preferred language and cancel or confirm the choice. The interface and supplied artwork currently remain in English until translations are available."),
        HelpArticle(question: "Where is my saved content?", answer: "Open Me for your local profile, videos, rewards and gift previews. Logging out retains them. Deleting your local profile removes its records and associated imported files from Tati.")
    ]
    private var matches: [HelpArticle] { articles.filter { query.isEmpty || ($0.question + $0.answer).localizedCaseInsensitiveContains(query) } }
    var body: some View {
        TatiPage(title: "Help & Support") {
            Art(name: "support-banner")
            InputField(title: "Search for a question", text: $query)
            if matches.isEmpty { EmptyContent(title: "No matching answers", detail: "Try a shorter phrase, or save a feedback draft below.") }
            ForEach(matches) { article in
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        if expanded.contains(article.id) { expanded.remove(article.id) } else { expanded.insert(article.id) }
                    } label: {
                        HStack { Text(article.question).font(.subheadline.bold()).multilineTextAlignment(.leading); Spacer(); Art(name: expanded.contains(article.id) ? "dropdown" : "chevron", width: 17, height: 17) }.frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityValue(expanded.contains(article.id) ? "Expanded" : "Collapsed")
                    if expanded.contains(article.id) { Text(article.answer).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                }.padding(14).background(Color.tatiLime.opacity(0.48)).clipShape(RoundedRectangle(cornerRadius: 13))
            }
            NavigationLink(destination: SupportDraftView()) { SettingRow(title: "Write a support draft", asset: "support-avatar") }.buttonStyle(.plain)
            NavigationLink(destination: ReportView(subjectID: "feedback", feedback: true)) { SettingRow(title: "Feedback", asset: "feedback") }.buttonStyle(.plain)
            Note(text: "No support address or service is configured. Drafts are saved only on this device and are not reviewed by a support team.")
        }
    }
}
struct SupportDraftView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var text = ""
    var body: some View {
        TatiPage(title: "Customer support") {
            HStack { Art(name: "support-avatar", width: 52, height: 52); VStack(alignment: .leading) { Text("Customer support").font(.headline); Note(text: "Not connected") } }
            Note(text: "Describe your question below. No agent is online in this local preview.")
            InputField(title: "Describe your question", text: $text, multiline: true)
            DraftPhotoAttachment(draftKey: "support-chat")
            TatiButton(title: "Save message draft", enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                if store.saveDraft("support-chat", text: text) { store.tell("Draft saved", "Your support message and optional photo stay on this device. Nothing was sent.") }
            }
        }.onAppear { text = store.account.drafts["support-chat"] ?? "" }
    }
}
struct LanguagePreferenceView: View {
    @EnvironmentObject private var store: VisitorStore
    private let languages = ["English", "Español", "ภาษาไทย", "العربية", "Tiếng Việt", "한국어"]
    var body: some View {
        TatiPage(title: "Language") {
            ForEach(languages, id: \.self) { language in
                Button {
                    store.confirm("Save language preference?", language == "English" ? "Use English as your preferred language?" : "Save \(language) as your preferred language? The current interface and supplied artwork stay in English until its translations are available.", button: "Confirm") {
                        _ = store.change { $0.preferredLanguage = language }
                    }
                } label: {
                    HStack { Text(language).font(.headline); Spacer(); if (store.account.preferredLanguage ?? "English") == language { Art(name: "check", width: 22) } }
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background { Image("outlined-card").resizable() }
                }.buttonStyle(.plain)
            }
            Note(text: "Interface language: English. This choice saves a preference, not an installed translation. Duplicate Español entries in the design are combined.")
        }
    }
}
