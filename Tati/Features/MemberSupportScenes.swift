import SwiftUI
import PhotosUI

struct PhotoAttachmentPicker: View {
    @Binding var data: Data?
    @State private var item: PhotosPickerItem?
    @Binding var loading: Bool
    @EnvironmentObject private var store: MemberKitchenStore
    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $item, matching: .images) {
                HStack(spacing: 12) {
                    Group {
                        if let data {
                            PreparedDataPhoto(data: data, maxPixels: 256)
                                .frame(width: 58, height: 58).clipped()
                        } else {
                            Art(name: "add-photo", width: 28, height: 28)
                                .frame(width: 58, height: 58).background(Color.tatiCream)
                        }
                    }.clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(loading ? "Loading photo…" : (data == nil ? "Add a photo" : "Photo attached")))
                            .font(.tati(.subheadline).weight(.semibold))
                        Text(LocalizedStringKey(data == nil ? "One image, up to 25 MB" : "Tap to replace"))
                            .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                    }.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(loading)
                .accessibilityLabel(data == nil ? "Choose attachment photo" : "Replace attachment photo")
            if data != nil {
                ArtButton(asset: "remove", label: "Remove attachment") { data = nil; item = nil }
                    .disabled(loading)
            }
        }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18))
        .task(id: item) {
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
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var selection: PhotosPickerItem?
    @State private var importing = false
    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selection, matching: .images) { Art(name: "chat-photo", width: 36, height: 36).frame(width: 44, height: 44) }
                .buttonStyle(.plain).disabled(importing).accessibilityLabel("Attach photo")
            if !compact, let file = store.account.draftImages?[draftKey] {
                PreparedPhoto(source: .file(store.mediaURL(file)))
                    .frame(width: 70, height: 70).clipShape(RoundedRectangle(cornerRadius: 8))
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
struct HelpArticle: Identifiable, Decodable, Sendable {
    var id: String { question }
    var question: String
    var answer: String
}
struct SupportView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var query = ""
    @State private var expanded: Set<String> = []
    private var articles: [HelpArticle] { KitchenContentSnapshot.current?.offers.supportArticles ?? [] }
    private var matches: [HelpArticle] {
        let language = AppLanguage.preference(store.account.preferredLanguage)
        return articles.filter {
            query.isEmpty || (language.text($0.question) + language.text($0.answer) + $0.question + $0.answer).localizedCaseInsensitiveContains(query)
        }
    }
    var body: some View {
        TatiForm(title: "Help & Support") {
            Art(name: "support-banner")
            SupportMailboxButton()
            NavigationLink("Our table rules", destination: TableGuidelinesView()).font(.tati(.headline))
            TextField("Search for a question", text: $query).font(.tati(size: 13)).textFieldStyle(.plain).padding(12).background { Image("outlined-card").resizable() }
            if matches.isEmpty { EmptyContent(title: "No matching answers", detail: "Try a shorter phrase, or save a feedback draft below.") }
            ForEach(matches) { article in
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        if expanded.contains(article.id) { expanded.remove(article.id) } else { expanded.insert(article.id) }
                    } label: {
                        HStack { Text(LocalizedStringKey(article.question)).font(.tati(size: 13, weight: .medium)).multilineTextAlignment(.leading); Spacer(); Art(name: expanded.contains(article.id) ? "dropdown" : "chevron", width: 13, height: 13) }.frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityValue(expanded.contains(article.id) ? "Expanded" : "Collapsed")
                    if expanded.contains(article.id) { Text(LocalizedStringKey(article.answer)).font(.tati(size: 12)).foregroundStyle(Color.tatiOlive.opacity(0.7)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 8) }
                }.padding(.horizontal, 12).padding(.vertical, 4).background(Color.tatiLime.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } footer: {
            NavigationLink(destination: SupportDraftView()) {
                HStack(spacing: 8) { Art(name: "support", width: 22, height: 22); Text("Prepare a support message").font(.tati(size: 15)) }
                    .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(.white).background(Color.tatiPink).clipShape(Capsule())
            }.buttonStyle(.plain)
        }
    }
}
struct SupportDraftView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ArtButton(asset: "back", label: "Back") { dismiss() }
                Art(name: "support-avatar", width: 42, height: 42)
                Text("Customer support").font(.tati(size: 15, weight: .medium)).lineLimit(2)
                Spacer(minLength: 0)
            }.padding(.horizontal, 8).padding(.bottom, 8)
            ScrollView {
            VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                Art(name: "support-avatar", width: 30, height: 30)
                Text("What would you like help with?").font(.tati(size: 14)).padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if let draft = store.account.drafts["support-chat"], !draft.isEmpty {
                HStack {
                    Spacer(minLength: 44)
                    VStack(alignment: .leading, spacing: 6) { Text(draft).font(.tati(size: 14)); Text("Draft · not sent").font(.tati(size: 10)) }.padding(14).background(Color.tatiPink).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
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
                        .font(.tati(size: 13)).padding(.leading, 12).padding(.vertical, 8).tint(.white)
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
    @EnvironmentObject private var store: MemberKitchenStore
    private var selected: AppLanguage { AppLanguage.preference(store.account.preferredLanguage) }
    var body: some View {
        TatiPage(title: "Language") {
            Note(text: "Changes apply immediately and are saved for your next visit.")
            ForEach(AppLanguage.allCases) { language in
                Button { _ = store.change { $0.preferredLanguage = language.rawValue } } label: {
                    HStack(spacing: 12) {
                        if language == .system { Text("System default").font(.tati(.body)) }
                        else { Text(verbatim: language.nativeName).font(.tati(.body)) }
                        Spacer(minLength: 0)
                        if selected == language { Art(name: "check-pink", width: 22, height: 22) }
                    }.padding(16).frame(maxWidth: .infinity, minHeight: 56)
                        .background(selected == language ? Color.tatiLime.opacity(0.65) : .white,
                                    in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityAddTraits(selected == language ? .isSelected : [])
            }
        }
    }
}
