import SwiftUI
import PhotosUI

struct PersonProfileView: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    @State private var more = false
    @State private var report = false
    @State private var gift = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink(destination: PortraitPhotoView(person: person)) {
                    ContentPhoto(asset: person.portraitArtwork, height: 420)
                }.buttonStyle(.plain).accessibilityLabel("View full photo")
                    .overlay(alignment: .top) { TatiHeader(title: "", trailing: "more") { more = true } }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Avatar(asset: person.portraitArtwork, size: 62).padding(.top, -24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                            Text(person.country).font(.system(size: 11)).foregroundStyle(Color.tatiOlive).lineLimit(1)
                            Text("Food lover").font(.system(size: 11)).foregroundStyle(Color.tatiOlive)
                        }
                        Spacer(minLength: 0)
                        ArtButton(asset: "gift-chat", label: "Gifts", size: 30) { gift = true }
                    }
                    Text(person.bio).font(.system(size: 13)).foregroundStyle(Color.tatiOlive)
                    Text(person.interest).font(.system(size: 10)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.tatiLime).clipShape(RoundedRectangle(cornerRadius: 3))
                    HStack(spacing: 10) {
                        ImageAction(asset: store.account.following.contains(person.id) ? "followed-button" : "follow-button", label: "Follow", height: 42) { store.toggleFollow(person.id) }
                        NavigationLink(destination: ConversationView(person: person)) { Art(name: "chat-button", height: 42).frame(maxWidth: .infinity) }.accessibilityLabel("Chat with \(person.name)")
                    }.padding(.vertical, 4)
                    Text("Video").font(.system(size: 17, weight: .bold))
                    if store.account.blocked.contains(person.id) { EmptyContent(title: "Profile blocked", detail: "Unblock this profile in Settings to see its content.") }
                    else {
                        ForEach(store.visibleClips.filter { $0.authorID == person.id }) { clip in
                            NavigationLink(destination: ClipDetailView(clip: clip)) { VideoCard(clip: clip) }.buttonStyle(.plain)
                        }
                        if !store.visibleClips.contains(where: { $0.authorID == person.id }) { EmptyContent(title: "No videos yet", detail: "This profile doesn't have any videos yet.") }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 16)
            }.frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).tatiScreen()
        .overlay {
            if more {
                ZStack {
                    Color.black.opacity(0.48).ignoresSafeArea().onTapGesture { more = false }
                    HStack(spacing: 32) {
                        ImageAction(asset: "block-button", label: "Block profile", height: 76) { more = false; store.block(person.id) }
                        ImageAction(asset: "report-button", label: "Report profile", height: 76) { more = false; report = true }
                    }.padding(28).frame(maxWidth: 300).background(Color.tatiCream).clipShape(RoundedRectangle(cornerRadius: 10))
                }.accessibilityAddTraits(.isModal).accessibilityAction(.escape) { more = false }
            }
        }
        .sheet(isPresented: $report) { NavigationStack { ReportView(subjectID: "person:" + person.id) }.overlay { NoticeLayer() } }
        .sheet(isPresented: $gift) { NavigationStack { GiftShopView(recipient: person) }.overlay { NoticeLayer() }.presentationDetents([.height(390), .large]) }
    }
}
struct MyProfileView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .top) {
                    if let file = store.account.profile.coverFile, let image = UIImage(contentsOfFile: store.mediaURL(file).path) {
                        GeometryReader { geometry in Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: 230).clipped() }.frame(height: 230)
                    } else { MediaPlaceholder(title: "Add your cover photo", height: 230) }
                    HStack(spacing: 2) {
                        Art(name: "profile-heading", width: 136, height: 48)
                        Spacer()
                        NavigationLink(destination: WalletView()) { Art(name: "coin", width: 22).frame(width: 44, height: 44) }.accessibilityLabel("Wallet")
                        NavigationLink(destination: SettingsView()) { Art(name: "settings", width: 22).frame(width: 44, height: 44) }.accessibilityLabel("Settings")
                    }.padding(.horizontal, 14).padding(.top, 4)
                }
                VStack(alignment: .leading, spacing: 10) {
                    NavigationLink(destination: EditProfileView()) {
                        HStack(spacing: 10) {
                            Avatar(file: store.account.profile.avatarFile, size: 72, isCurrent: true).padding(.top, -24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.account.profile.name).font(.system(size: 20, weight: .semibold)).lineLimit(2)
                                Text("Edit profile").font(.system(size: 11)).foregroundStyle(Color.tatiOlive)
                            }
                            Spacer(); Art(name: "chevron", width: 12)
                        }
                    }.buttonStyle(.plain)
                    Text(store.account.profile.bio).font(.system(size: 12)).foregroundStyle(Color.tatiOlive)
                    Text(store.account.profile.interest).font(.system(size: 10)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.tatiLime).clipShape(RoundedRectangle(cornerRadius: 3))
                    HStack {
                        NavigationLink(destination: RelationshipView(kind: "Following")) { stat("\(store.account.following.count)", "Following") }
                        NavigationLink(destination: RelationshipView(kind: "Follower")) { stat("0", "Follower") }
                        NavigationLink(destination: RelationshipView(kind: "Friends")) { stat("0", "Friends") }
                    }.buttonStyle(.plain).padding(.vertical, 10).background(Color(red: 1, green: 0.96, blue: 0.24)).clipShape(RoundedRectangle(cornerRadius: 7))
                    HStack(spacing: 12) {
                        NavigationLink(destination: CheckInView()) { Art(name: "checkin-entry") }.accessibilityLabel("Check in")
                        NavigationLink(destination: WalletView()) { Art(name: "wallet-entry") }.accessibilityLabel("My wallet")
                    }.padding(.vertical, 3)
                    VStack(spacing: 0) {
                        NavigationLink(destination: BlacklistView()) { SettingRow(title: "Blacklist", asset: "blacklist") }
                        NavigationLink(destination: LevelView()) { SettingRow(title: "My level", asset: "level") }
                        NavigationLink(destination: SupportView()) { SettingRow(title: "Customer Support", asset: "support") }
                        NavigationLink(destination: InviteView()) { SettingRow(title: "Invite Code", asset: "invite") }
                        NavigationLink(destination: ReportView(subjectID: "feedback", feedback: true)) { SettingRow(title: "Feedback", asset: "feedback") }
                        NavigationLink(destination: BackpackView()) { SettingRow(title: "My backpack", asset: "backpack") }
                        NavigationLink(destination: MyVideosView()) { SettingRow(title: "My videos", asset: "video-off", detail: "\(store.account.clips.count)") }
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }.frame(maxWidth: 680).frame(maxWidth: .infinity)
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
                ForEach(people) { person in
                    HStack(spacing: 10) {
                        NavigationLink(destination: PersonProfileView(person: person)) { HStack { Avatar(asset: person.portraitArtwork, size: 38); Text(person.name).font(.system(size: 14)) } }.buttonStyle(.plain)
                        Spacer()
                        NavigationLink(destination: ConversationView(person: person)) { SupplementIcon(icon: .comment, size: 22).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Chat with \(person.name)")
                    }.padding(.horizontal, 12).padding(.vertical, 4).background { Image("outlined-card").resizable() }
                }
            } else { EmptyContent(title: "No \(kind.lowercased()) yet", detail: "New connections will appear here.") }
        }
    }
}
struct MyVideosView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: "My videos") {
            NavigationLink(destination: PublishVideoView()) { SettingRow(title: "Add a video", asset: "add-video") }
            if store.account.clips.isEmpty { EmptyContent(title: "Your story starts here", detail: "Add a food video to your collection.") }
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
    @State private var removeAvatar = false
    @State private var removeCover = false
    @State private var loadingAvatar = false
    @State private var loadingCover = false
    @State private var moreDetails = false
    private var loading: Bool { loadingAvatar || loadingCover }
    var body: some View {
        TatiForm(title: "Edit profile") {
            PhotosPicker(selection: $coverItem, matching: .images) {
                Group {
                    if let image = preview(coverData, removeCover ? nil : store.account.profile.coverFile) { Image(uiImage: image).resizable().scaledToFill().frame(height: 190).clipped() }
                    else { MediaPlaceholder(title: "Change the background image", height: 190) }
                }.clipShape(RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain)
            InputField(title: "Please enter the name…", text: $name, showsLabel: false).onChange(of: name) { _, value in name = String(value.prefix(32)) }
            PhotosPicker(selection: $avatarItem, matching: .images) {
                Group {
                    if let image = preview(avatarData, removeAvatar ? nil : store.account.profile.avatarFile) { Image(uiImage: image).resizable().scaledToFill() }
                    else { Art(name: "add", width: 24, height: 24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.tatiLime.opacity(0.55)) }
                }.frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain).accessibilityLabel("Change avatar")
            HStack {
                if avatarData != nil || (!removeAvatar && store.account.profile.avatarFile != nil) { TatiButton(title: "Remove avatar", secondary: true) { avatarData = nil; avatarItem = nil; removeAvatar = true } }
                if coverData != nil || (!removeCover && store.account.profile.coverFile != nil) { TatiButton(title: "Remove cover", secondary: true) { coverData = nil; coverItem = nil; removeCover = true } }
            }
            Button { moreDetails.toggle() } label: { HStack { Text("More profile details").font(.system(size: 13)); Spacer(); Art(name: moreDetails ? "dropdown" : "chevron", width: 13) }.frame(minHeight: 44) }.buttonStyle(.plain)
            if moreDetails {
            InputField(title: "About you", text: $bio, multiline: true).onChange(of: bio) { _, value in bio = String(value.prefix(200)) }
            InputField(title: "Country / region (optional)", text: $country)
            ChoiceGrid(items: Array(FoodCatalog.topics.dropFirst()), selected: $interest)
            }
        } footer: {
            TatiButton(title: loading ? "Loading photo…" : "Save", enabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !loading) { save() }
        }.onAppear { name = store.account.profile.name; bio = store.account.profile.bio; country = store.account.profile.country; interest = store.account.profile.interest }
        .task(id: avatarItem) { guard let avatarItem else { return }; loadingAvatar = true; defer { loadingAvatar = false }; do { let data = try await avatarItem.loadTransferable(type: Data.self); guard !Task.isCancelled else { return }; avatarData = data; removeAvatar = false } catch { store.tell("Photo unavailable", "Please choose another photo. Your other edits are still here.") } }
        .task(id: coverItem) { guard let coverItem else { return }; loadingCover = true; defer { loadingCover = false }; do { let data = try await coverItem.loadTransferable(type: Data.self); guard !Task.isCancelled else { return }; coverData = data; removeCover = false } catch { store.tell("Photo unavailable", "Please choose another cover. Your other edits are still here.") } }
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
            if removeAvatar { profile.avatarFile = nil }
            if removeCover { profile.coverFile = nil }
            if let avatarData { let file = try store.importImage(avatarData); newFiles.append(file); profile.avatarFile = file }
            if let coverData { let file = try store.importImage(coverData); newFiles.append(file); profile.coverFile = file }
            if store.change({ $0.profile = profile }) {
                let retained = [profile.avatarFile, profile.coverFile].compactMap { $0 }
                for file in old where !retained.contains(file) { store.removeUnusedMedia(file) }
                dismiss()
            } else { for file in newFiles { store.removeUnusedMedia(file) } }
        } catch {
            for file in newFiles { store.removeUnusedMedia(file) }
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
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ArtButton(asset: "back", label: "Back") { dismiss() }
                    Avatar(asset: person.portraitArtwork, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.name).font(.system(size: 17, weight: .medium)).lineLimit(1)
                    }
                    Spacer()
                    ArtButton(asset: "add-video", label: "Video call", size: 24) { store.tell("Video call unavailable", "Video calls are currently unavailable. No call has been placed.") }
                    NavigationLink(destination: PersonProfileView(person: person)) { Art(name: "profile-button", width: 64, height: 32) }.accessibilityLabel("View profile")
                }.padding(.horizontal, 6)
                ScrollView {
                    VStack(spacing: 18) {
                        if let draft = store.account.drafts[person.id], !draft.isEmpty {
                            HStack {
                                Spacer(minLength: 56)
                                VStack(alignment: .leading, spacing: 6) { Text(draft).font(.system(size: 14)); Text("Draft · not sent").font(.system(size: 10)) }
                                    .padding(14).foregroundStyle(.white).background(Color.tatiPink)
                                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12, bottomTrailingRadius: 12))
                            }
                        }
                    }.padding(.horizontal, 18)
                }
                if store.account.draftImages?[person.id] != nil { DraftPhotoAttachment(draftKey: person.id).padding(.horizontal, 12) }
                // Reflow the same children so an attachment import survives resizing.
                let inputLayout = geometry.size.width < 350
                    ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 4))
                    : AnyLayout(HStackLayout(spacing: 2))
                inputLayout {
                    HStack(spacing: 2) { microphoneButton; composer }
                    attachmentActions
                }.padding(.horizontal, 8).padding(.vertical, 6).background(Color.tatiLime.opacity(0.7))
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).tatiScreen()
        .onAppear { text = store.account.drafts[person.id] ?? "" }
        .sheet(isPresented: $gifts) { NavigationStack { GiftShopView(recipient: person) }.overlay { NoticeLayer() }.presentationDetents([.height(390), .large]) }
    }
    private var microphoneButton: some View {
        ArtButton(asset: "chat-mic", label: "Voice message", size: 32) {
            store.tell("Voice messaging unavailable", "Voice messages are currently unavailable. No recording has started.")
        }
    }
    private var composer: some View {
        HStack(spacing: 0) {
            TextField("Say Hi~", text: $text, axis: .vertical).lineLimit(1...4)
                .font(.system(size: 13)).padding(.leading, 12).padding(.vertical, 8).tint(.white)
            Button { store.attemptMessage(to: person.id, text: text) } label: {
                SupplementIcon(icon: .send, size: 22).frame(width: 40, height: 44)
            }.buttonStyle(.plain).accessibilityLabel("Send message")
        }.foregroundStyle(.white).background(Color.tatiPink).clipShape(RoundedRectangle(cornerRadius: 22))
    }
    private var attachmentActions: some View {
        HStack(spacing: 2) {
            ArtButton(asset: "chat-speaker", label: "Voice call", size: 32) {
                store.tell("Voice call unavailable", "Voice calls are currently unavailable. No call has been placed.")
            }
            DraftPhotoAttachment(draftKey: person.id, compact: true)
            ArtButton(asset: "gift-chat", label: "Gifts", size: 32) { gifts = true }
        }
    }

}
struct FoodExpertView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var question = ""
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            Art(name: "brand-heading", width: 146, height: 48)
                            Text("Hi, I'm your AI Food Expert!").font(.system(size: 18, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        }.padding(.bottom, 18)
                        Spacer(minLength: 0)
                        Art(name: "chef", width: 116, height: 150)
                    }.padding(.horizontal, 16).padding(.top, 8).background { TatiBackground() }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Talk food, flavours and recipes.").font(.system(size: 15)).foregroundStyle(.black.opacity(0.65))
                        ForEach(["How to get crispy fried food?", "How to make food look delicious?", "How to balance sweet and savory taste?"], id: \.self) { prompt in
                            Button { question = prompt } label: {
                                HStack(spacing: 7) { Text(prompt).font(.system(size: 14)).multilineTextAlignment(.leading); Art(name: "food-flame", width: 23, height: 23); Spacer(minLength: 0) }
                                    .padding(.horizontal, 12).padding(.vertical, 12).background(Color.tatiCream).clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                        if let saved = store.account.drafts["food-expert"], !saved.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Spacer(minLength: 20)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(saved).font(.system(size: 14))
                                    Text("Draft · not sent").font(.system(size: 10))
                                }.padding(16).background(Color.tatiOlive).foregroundStyle(.white).clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12, bottomTrailingRadius: 12))
                                Avatar(file: store.account.profile.avatarFile, size: 40, isCurrent: true)
                            }.padding(.top, 20)
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white).clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
                }.background(Color.tatiLime)
            }.background(.white)
            HStack(spacing: 8) {
                TextField("Ask about food…", text: $question, axis: .vertical).lineLimit(1...4).font(.system(size: 14)).padding(12).background(Color.tatiCream).clipShape(RoundedRectangle(cornerRadius: 22))
                Button {
                    guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    if store.saveDraft("food-expert", text: question) {
                        question = ""
                        store.tell("Question saved", "AI replies are currently unavailable. Your question is saved as a draft.")
                    }
                } label: { Art(name: "ai-off", width: 30, height: 30).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Save food question")
            }.padding(.horizontal, 18).padding(.vertical, 8).background(.white)
        }.frame(maxWidth: 680).frame(maxWidth: .infinity).foregroundStyle(Color.tatiInk)
    }
}
