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
    var compact = false
    @EnvironmentObject private var store: VisitorStore
    @State private var selection: PhotosPickerItem?
    @State private var importing = false
    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selection, matching: .images) { Art(name: "chat-photo", width: 36, height: 36).frame(width: 44, height: 44) }
                .buttonStyle(.plain).disabled(importing).accessibilityLabel("Attach local photo")
            if !compact, let file = store.account.draftImages?[draftKey], let image = UIImage(contentsOfFile: store.mediaURL(file).path) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: compact ? 36 : 70, height: compact ? 36 : 70).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                if !compact { Note(text: "Local attachment · not sent") }
                ArtButton(asset: "remove", label: "Remove draft photo") { _ = store.saveDraftImage(nil, key: draftKey); selection = nil }
            } else if !compact { Note(text: importing ? "Importing photo…" : "Optional photo draft") }
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
        TatiForm(title: "Help & Support") {
            Art(name: "support-banner")
            TextField("Search for a question", text: $query).font(.system(size: 13)).textFieldStyle(.plain).padding(12).background { Image("outlined-card").resizable() }
            if matches.isEmpty { EmptyContent(title: "No matching answers", detail: "Try a shorter phrase, or save a feedback draft below.") }
            ForEach(matches) { article in
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        if expanded.contains(article.id) { expanded.remove(article.id) } else { expanded.insert(article.id) }
                    } label: {
                        HStack { Text(article.question).font(.subheadline.bold()).multilineTextAlignment(.leading); Spacer(); Art(name: expanded.contains(article.id) ? "dropdown" : "chevron", width: 17, height: 17) }.frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityValue(expanded.contains(article.id) ? "Expanded" : "Collapsed")
                    if expanded.contains(article.id) { Text(article.answer).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                }.padding(.horizontal, 12).padding(.vertical, 4).background(Color.tatiLime.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } footer: {
            NavigationLink(destination: SupportDraftView()) {
                HStack(spacing: 8) { Art(name: "support", width: 22, height: 22); Text("Contact support").font(.system(size: 15)) }
                    .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(.white).background(Color.tatiPink).clipShape(Capsule())
            }.buttonStyle(.plain)
        }
    }
}
struct SupportDraftView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var text = ""
    var body: some View {
        TatiForm(title: "Customer support") {
            HStack(alignment: .top, spacing: 8) {
                Art(name: "support-avatar", width: 40, height: 40)
                Text("Support isn't connected yet. Leave a question as a local draft.").font(.system(size: 14)).padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if let draft = store.account.drafts["support-chat"], !draft.isEmpty {
                HStack {
                    Spacer(minLength: 44)
                    VStack(alignment: .leading, spacing: 6) { Text(draft).font(.system(size: 14)); Text("Draft · not sent").font(.system(size: 10)) }.padding(14).background(Color.tatiPink).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            if store.account.draftImages?["support-chat"] != nil { DraftPhotoAttachment(draftKey: "support-chat") }
        } footer: {
            HStack(spacing: 6) {
                TextField("Describe your question", text: $text, axis: .vertical).lineLimit(1...4).font(.system(size: 14)).padding(12).background(Color.tatiPink).foregroundStyle(.white).tint(.white).clipShape(Capsule())
                DraftPhotoAttachment(draftKey: "support-chat", compact: true)
                Button {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    if store.saveDraft("support-chat", text: text) { store.tell("Draft saved", "Your support message and optional photo stay on this device. Nothing was sent.") }
                } label: { SupplementIcon(icon: .send, size: 25).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Save support draft")
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
                    HStack { Text(language).font(.system(size: 14)); Spacer(); if (store.account.preferredLanguage ?? "English") == language { Art(name: "check", width: 22) } }
                        .padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        .background { Image("outlined-card").resizable() }
                }.buttonStyle(.plain)
            }
            Note(text: "Interface language: English. This choice saves a preference, not an installed translation.")
        }
    }
}
