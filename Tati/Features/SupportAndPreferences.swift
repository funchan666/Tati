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
                .buttonStyle(.plain).disabled(importing).accessibilityLabel("Attach photo")
            if !compact, let file = store.account.draftImages?[draftKey], let image = UIImage(contentsOfFile: store.mediaURL(file).path) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: compact ? 36 : 70, height: compact ? 36 : 70).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                if !compact { Note(text: "Attachment · not sent") }
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
        HelpArticle(question: "How do I recharge diamonds?", answer: "Open your wallet from Me, or tap the balance in the gift panel. Recharge is currently unavailable. You can collect free reward coins through daily check-ins."),
        HelpArticle(question: "My purchase is still processing", answer: "Purchases are currently unavailable, so no payment can be started. Check-in rewards are separate from purchased coins."),
        HelpArticle(question: "Why did my call pause?", answer: "Calls are currently unavailable. Video playback and the camera stop when you leave the page or Tati enters the background."),
        HelpArticle(question: "How can I change my language?", answer: "Open Settings, then Language. You can save a preferred language and cancel or confirm the choice. The interface and supplied artwork currently remain in English until translations are available."),
        HelpArticle(question: "Where is my saved content?", answer: "Open Me for your profile, videos, rewards and gift records. Logging out keeps them. Deleting your profile removes its records and imported files from Tati.")
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
                        HStack { Text(article.question).font(.system(size: 13, weight: .medium)).multilineTextAlignment(.leading); Spacer(); Art(name: expanded.contains(article.id) ? "dropdown" : "chevron", width: 13, height: 13) }.frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityValue(expanded.contains(article.id) ? "Expanded" : "Collapsed")
                    if expanded.contains(article.id) { Text(article.answer).font(.system(size: 12)).foregroundStyle(Color.tatiOlive.opacity(0.7)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 8) }
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
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ArtButton(asset: "back", label: "Back") { dismiss() }
                Art(name: "support-avatar", width: 42, height: 42)
                Text("Customer support").font(.system(size: 15, weight: .medium)).lineLimit(2)
                Spacer(minLength: 0)
            }.padding(.horizontal, 8).padding(.bottom, 8)
            ScrollView {
            VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                Art(name: "support-avatar", width: 30, height: 30)
                Text("What can we help with?").font(.system(size: 14)).padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if let draft = store.account.drafts["support-chat"], !draft.isEmpty {
                HStack {
                    Spacer(minLength: 44)
                    VStack(alignment: .leading, spacing: 6) { Text(draft).font(.system(size: 14)); Text("Draft · not sent").font(.system(size: 10)) }.padding(14).background(Color.tatiPink).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            if store.account.draftImages?["support-chat"] != nil { DraftPhotoAttachment(draftKey: "support-chat") }
            }.padding(.horizontal, 18).padding(.vertical, 14).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            HStack(spacing: 6) {
                ArtButton(asset: "chat-mic", label: "Voice message", size: 32) {
                    store.tell("Voice messaging unavailable", "Voice messages are currently unavailable. No recording has started.")
                }
                HStack(spacing: 0) {
                    TextField("Describe your question", text: $text, axis: .vertical).lineLimit(1...4)
                        .font(.system(size: 13)).padding(.leading, 12).padding(.vertical, 8).tint(.white)
                    Button {
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        if store.saveDraft("support-chat", text: text) { store.tell("Draft saved", "Your message and attachment have been saved as a draft. They have not been sent.") }
                    } label: { SupplementIcon(icon: .send, size: 23).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Save support draft")
                }.foregroundStyle(.white).background(Color.tatiPink).clipShape(RoundedRectangle(cornerRadius: 22))
                DraftPhotoAttachment(draftKey: "support-chat", compact: true)
            }.padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: 600).frame(maxWidth: .infinity).background(Color.tatiLime.opacity(0.7))
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).tatiScreen()
            .onAppear { text = store.account.drafts["support-chat"] ?? "" }
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
                        .background {
                            if (store.account.preferredLanguage ?? "English") == language { Color.tatiLime.opacity(0.55).clipShape(RoundedRectangle(cornerRadius: 8)) }
                            Image("outlined-card").resizable().opacity((store.account.preferredLanguage ?? "English") == language ? 0.35 : 1)
                        }
                }.buttonStyle(.plain)
            }
        }
    }
}
