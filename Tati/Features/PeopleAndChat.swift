import SwiftUI
import PhotosUI

struct PersonProfileView: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    @State private var more = false
    @State private var gift = false
    var body: some View {
        VStack(spacing: 0) {
            TatiHeader(title: person.name, trailing: "more") { more = true }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MediaPlaceholder(title: "Profile photo to come", height: 320)
                    HStack(spacing: 12) {
                        Avatar(size: 62)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(person.name).font(.title2.bold())
                            Text(person.country).font(.subheadline)
                            Note(text: "Sample profile · not a connected account")
                        }
                    }
                    Text(person.bio).font(.subheadline)
                    Text(person.interest).font(.caption.bold()).padding(10).background(Color.tatiLime).clipShape(Capsule())
                    HStack(spacing: 10) {
                        ImageAction(asset: store.account.following.contains(person.id) ? "followed-button" : "follow-button", label: "Follow") { store.toggleFollow(person.id) }
                        NavigationLink(destination: ConversationView(person: person)) { Art(name: "chat-button", height: 48) }.accessibilityLabel("Chat with \(person.name)")
                    }
                    TatiButton(title: "Preview a gift", secondary: true) { gift = true }
                    Text("Video").font(.title3.bold())
                    if store.account.blocked.contains(person.id) { EmptyContent(title: "Profile blocked", detail: "Unblock this profile in Settings to see its sample content.") }
                    else {
                        ForEach(store.visibleClips.filter { $0.authorID == person.id }) { clip in
                            NavigationLink(destination: ClipDetailView(clip: clip)) { VideoCard(clip: clip) }.buttonStyle(.plain)
                        }
                        if !store.visibleClips.contains(where: { $0.authorID == person.id }) { EmptyContent(title: "No videos yet", detail: "This profile doesn't have any sample videos.") }
                    }
                }.padding(20)
            }
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $more) {
            NavigationStack {
                TatiPage(title: "Profile options") {
                    NavigationLink(destination: ReportView(subjectID: "person:" + person.id)) { Art(name: "report-button", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Report profile")
                    ImageAction(asset: "block-button", label: "Block profile", height: 90) { more = false; store.block(person.id) }
                }
            }.overlay { NoticeLayer() }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $gift) { NavigationStack { GiftShopView(recipient: person) }.overlay { NoticeLayer() } }
    }
}
struct MyProfileView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .top) {
                    if let file = store.account.profile.coverFile, let image = UIImage(contentsOfFile: store.mediaURL(file).path) { Image(uiImage: image).resizable().scaledToFill().frame(height: 240).clipped().clipShape(RoundedRectangle(cornerRadius: 20)) }
                    else { MediaPlaceholder(title: "Your cover photo", height: 240) }
                    HStack {
                        Art(name: "profile-heading", width: 145, height: 50)
                        Spacer()
                        NavigationLink(destination: WalletView()) { Art(name: "coin", width: 26).frame(width: 44, height: 44) }.accessibilityLabel("Wallet")
                        NavigationLink(destination: SettingsView()) { Art(name: "settings", width: 26).frame(width: 44, height: 44) }.accessibilityLabel("Settings")
                    }.padding(12)
                }
                NavigationLink(destination: EditProfileView()) {
                    HStack(spacing: 12) {
                        Avatar(file: store.account.profile.avatarFile, size: 65, isCurrent: true)
                        VStack(alignment: .leading, spacing: 5) { Text(store.account.profile.name).font(.title2.bold()); Text("Local guest").font(.caption); Text("Edit profile").font(.caption.bold()).foregroundStyle(Color.tatiOlive) }
                        Spacer(); Art(name: "chevron", width: 14)
                    }
                }.buttonStyle(.plain)
                Text(store.account.profile.bio).font(.subheadline)
                Text(store.account.profile.interest).font(.caption.bold()).padding(9).background(Color.tatiLime).clipShape(Capsule())
                HStack {
                    NavigationLink(destination: RelationshipView(kind: "Following")) { stat("\(store.account.following.count)", "Following") }
                    NavigationLink(destination: RelationshipView(kind: "Follower")) { stat("0", "Follower") }
                    NavigationLink(destination: RelationshipView(kind: "Friends")) { stat("0", "Friends") }
                }.buttonStyle(.plain).padding(12).background(Color.tatiLime).clipShape(RoundedRectangle(cornerRadius: 17))
                HStack(spacing: 12) {
                    NavigationLink(destination: CheckInView()) { Art(name: "checkin-entry") }.accessibilityLabel("Check in")
                    NavigationLink(destination: WalletView()) { Art(name: "wallet-entry") }.accessibilityLabel("My wallet")
                }
                VStack(spacing: 8) {
                    NavigationLink(destination: BlacklistView()) { SettingRow(title: "Blacklist", asset: "blacklist") }
                    NavigationLink(destination: LevelView()) { SettingRow(title: "My level", asset: "level") }
                    NavigationLink(destination: SupportView()) { SettingRow(title: "Customer support", asset: "support") }
                    NavigationLink(destination: InviteView()) { SettingRow(title: "Invite code", asset: "invite") }
                    NavigationLink(destination: ReportView(subjectID: "feedback", feedback: true)) { SettingRow(title: "Feedback", asset: "feedback") }
                    NavigationLink(destination: BackpackView()) { SettingRow(title: "My backpack", asset: "backpack") }
                    NavigationLink(destination: MyVideosView()) { SettingRow(title: "My local videos", asset: "video-off", detail: "\(store.account.clips.count)") }
                }.buttonStyle(.plain)
                Note(text: "This profile is stored on this device. No automatic follows, followers or messages are created.")
            }.padding(18)
        }.foregroundStyle(Color.tatiInk)
    }
    private func stat(_ value: String, _ title: String) -> some View { VStack(spacing: 4) { Text(value).font(.headline); Text(title).font(.caption) }.frame(maxWidth: .infinity) }
}
struct RelationshipView: View {
    var kind: String
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: kind) {
            if kind == "Following" {
                let people = FoodCatalog.people.filter { store.account.following.contains($0.id) && !store.account.blocked.contains($0.id) }
                if people.isEmpty { EmptyContent(title: "Your table is open", detail: "Follow a profile to find it here.") }
                ForEach(people) { PersonRow(person: $0) }
            } else { EmptyContent(title: "No \(kind.lowercased()) yet", detail: "A connected service is needed for real follows from other people. Sample profiles never follow you automatically.") }
        }
    }
}
struct MyVideosView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: "My local videos") {
            NavigationLink(destination: PublishVideoView()) { SettingRow(title: "Add a video", asset: "add-video") }
            if store.account.clips.isEmpty { EmptyContent(title: "Your story starts here", detail: "Import a food video to keep it in your local collection.") }
            ForEach(store.account.clips) { clip in NavigationLink(destination: ClipDetailView(clip: clip)) { VideoCard(clip: clip) }.buttonStyle(.plain) }
        }
    }
}
struct EditProfileView: View {
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var bio = ""
    @State private var interest = "Home cooking"
    @State private var country = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var coverData: Data?
    @State private var loadingAvatar = false
    @State private var loadingCover = false
    private var loading: Bool { loadingAvatar || loadingCover }
    var body: some View {
        TatiPage(title: "Edit profile") {
            PhotosPicker(selection: $coverItem, matching: .images) {
                Group {
                    if let image = preview(coverData, store.account.profile.coverFile) { Image(uiImage: image).resizable().scaledToFill().frame(height: 190).clipped() }
                    else { MediaPlaceholder(title: "Change the background image", height: 190) }
                }.clipShape(RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain)
            PhotosPicker(selection: $avatarItem, matching: .images) {
                HStack {
                    if let image = preview(avatarData, store.account.profile.avatarFile) { Image(uiImage: image).resizable().scaledToFill().frame(width: 66, height: 66).clipShape(Circle()) }
                    else { Avatar(size: 66) }
                    Text("Change avatar").font(.headline)
                }
            }.buttonStyle(.plain)
            InputField(title: "Name", text: $name).onChange(of: name) { _, value in name = String(value.prefix(32)) }
            InputField(title: "About you", text: $bio, multiline: true).onChange(of: bio) { _, value in bio = String(value.prefix(200)) }
            InputField(title: "Country / region (optional)", text: $country)
            ChoiceGrid(items: Array(FoodCatalog.topics.dropFirst()), selected: $interest)
            TatiButton(title: loading ? "Loading photo…" : "Save", enabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !loading) { save() }
        }.onAppear { name = store.account.profile.name; bio = store.account.profile.bio; country = store.account.profile.country; interest = store.account.profile.interest }
        .task(id: avatarItem) { guard let avatarItem else { return }; loadingAvatar = true; defer { loadingAvatar = false }; do { let data = try await avatarItem.loadTransferable(type: Data.self); guard !Task.isCancelled else { return }; avatarData = data } catch { store.tell("Photo unavailable", "Please choose another photo. Your other edits are still here.") } }
        .task(id: coverItem) { guard let coverItem else { return }; loadingCover = true; defer { loadingCover = false }; do { let data = try await coverItem.loadTransferable(type: Data.self); guard !Task.isCancelled else { return }; coverData = data } catch { store.tell("Photo unavailable", "Please choose another cover. Your other edits are still here.") } }
    }
    private func preview(_ data: Data?, _ file: String?) -> UIImage? {
        if let data { return UIImage(data: data) }
        if let file { return UIImage(contentsOfFile: store.mediaURL(file).path) }
        return nil
    }
    private func save() {
        var newFiles: [String] = []
        do {
            var profile = store.account.profile
            let old = [profile.avatarFile, profile.coverFile].compactMap { $0 }
            profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); profile.bio = bio; profile.interest = interest; profile.country = country
            if let avatarData { let file = try store.importImage(avatarData); newFiles.append(file); profile.avatarFile = file }
            if let coverData { let file = try store.importImage(coverData); newFiles.append(file); profile.coverFile = file }
            if store.change({ $0.profile = profile }) {
                let retained = [profile.avatarFile, profile.coverFile].compactMap { $0 }
                for file in old where !retained.contains(file) { try? FileManager.default.removeItem(at: store.mediaURL(file)) }
                dismiss()
            } else { for file in newFiles { try? FileManager.default.removeItem(at: store.mediaURL(file)) } }
        } catch {
            for file in newFiles { try? FileManager.default.removeItem(at: store.mediaURL(file)) }
            store.tell("Couldn't save photo", "Use a supported image smaller than 25 MB. Your edits have been kept on this screen.")
        }
    }
}
struct ConversationView: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    @State private var text = ""
    @State private var gifts = false
    @State private var media: PhotosPickerItem?
    var body: some View {
        VStack(spacing: 0) {
            TatiHeader(title: person.name)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NavigationLink(destination: PersonProfileView(person: person)) {
                        HStack { Avatar(size: 60); VStack(alignment: .leading) { Text(person.name).font(.headline); Text(person.interest).font(.caption); Text("View profile").font(.caption.bold()) }; Spacer(); Art(name: "profile-button", width: 70) }
                    }.buttonStyle(.plain)
                    Note(text: "Sample profile · messages require mutual follows and a connected service.")
                    Text(person.bio).font(.subheadline).padding(18).background(.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 18))
                    EmptyContent(title: "Say hello over a good meal", detail: "Your message will remain a local draft until messaging is connected.", artwork: "chat-heading")
                }.padding(20)
            }
            VStack(spacing: 12) {
                HStack {
                    TextField("Say hi…", text: $text, axis: .vertical).lineLimit(1...5).padding(14).background(Color.tatiPink.opacity(0.22)).clipShape(RoundedRectangle(cornerRadius: 22))
                    Button { store.attemptMessage(to: person.id, text: text) } label: { SupplementIcon(icon: .send).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Send message")
                }
                HStack {
                    ArtButton(asset: "chat-mic", label: "Voice message", size: 35) { store.tell("Voice messaging unavailable", "A connected messaging service and mutual follows are required. No recording was started.") }
                    ArtButton(asset: "chat-photo", label: "Photo message", size: 35) { store.tell("Photo messaging unavailable", "A connected messaging service and mutual follows are required. Your photos have not been accessed or sent.") }
                    ArtButton(asset: "add-video", label: "Video call", size: 35) { store.tell("Video call unavailable", "Video calls require mutual follows and a connected calling service. No call has been placed.") }
                    Spacer()
                    ArtButton(asset: "gift-chat", label: "Gifts", size: 35) { gifts = true }
                }
                TatiButton(title: "Save draft", secondary: true, enabled: !text.isEmpty) { if store.saveDraft(person.id, text: text) { store.tell("Draft saved", "Your message is saved only on this device.") } }
            }.padding(16).background(Color.tatiLime.opacity(0.6))
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).toolbar(.hidden, for: .navigationBar)
        .onAppear { text = store.account.drafts[person.id] ?? "" }
        .sheet(isPresented: $gifts) { NavigationStack { GiftShopView(recipient: person) }.overlay { NoticeLayer() } }
    }
}
struct FoodExpertView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var question = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) { Art(name: "brand-heading", width: 150, height: 50); Text("Hi, I'm your food expert!").font(.title3.bold()) }
                    Spacer(); Art(name: "chef", width: 100, height: 115)
                }
                Text("A little inspiration for your next meal").font(.headline)
                ForEach(["How do I make crispy fried food?", "What can I cook with seasonal vegetables?", "How do I balance sweet and savoury flavours?"], id: \.self) { prompt in
                    Button { question = prompt } label: { HStack { Text(prompt).font(.subheadline).multilineTextAlignment(.leading); Spacer(); Art(name: "food-flame", width: 22) }.padding(14).background(Color.tatiLime.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain)
                }
                Note(text: "The AI service isn't connected yet. Suggested questions are prompts, not generated answers.")
                InputField(title: "Ask about food", text: $question, multiline: true)
                TatiButton(title: "Ask Tati", enabled: !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    if store.saveDraft("food-expert", text: question) { store.tell("Question saved", "AI is not connected yet. Your question has been saved as a local draft; no answer was generated.") }
                }
            }.padding(20)
        }.foregroundStyle(Color.tatiInk).onAppear { question = store.account.drafts["food-expert"] ?? "" }
    }
}
