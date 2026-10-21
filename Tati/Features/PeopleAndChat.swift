import SwiftUI
import PhotosUI

struct PersonProfileView: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    @State private var more = false
    @Environment(\.dismiss) private var dismiss
    private var clips: [FoodClip] { store.visibleClips.filter { $0.authorID == person.id } }

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 0) {
                    NavigationLink(destination: PortraitPhotoView(person: person)) {
                        ContentPhoto(asset: person.portraitArtwork,
                                     height: min(300, max(180, viewport.size.height * 0.34)))
                    }.buttonStyle(.plain).accessibilityLabel("View full photo")
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .center, spacing: 12) {
                                Avatar(asset: person.portraitArtwork, size: 66)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(person.name).font(.title2.weight(.bold))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(person.city == person.country ? person.country : "\(person.city) · \(person.country)")
                                        .font(.subheadline).foregroundStyle(Color.tatiOlive)
                                        .fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if !person.bio.isEmpty {
                                Text(person.bio).font(.subheadline).lineSpacing(4)
                                    .foregroundStyle(Color.tatiOlive).fixedSize(horizontal: false, vertical: true)
                            }
                            FilterTagLayout() {
                                profileTag(person.interest, highlighted: true)
                                profileTag(person.language, highlighted: false)
                            }
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 12) { followAction; messageAction }
                                VStack(spacing: 10) { followAction; messageAction }
                            }
                        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 24))
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Videos").font(.title3.weight(.bold))
                                Spacer()
                                Text(clips.count.formatted()).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.tatiOlive)
                            }
                            if clips.isEmpty {
                                HStack(spacing: 14) {
                                    Art(name: "support-mascot", width: 48, height: 54)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("No videos yet").font(.subheadline.weight(.semibold))
                                        Text("New videos will appear here.").font(.caption).foregroundStyle(Color.tatiOlive)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
                            } else {
                                ForEach(clips) { clip in FeedVideoCard(clip: clip) }
                            }
                        }
                    }.padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 28)
                }.frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
                .safeAreaInset(edge: .top, spacing: 0) {
                    TatiHeader(title: "Profile", trailing: "more", trailingLabel: "Report or block") { more = true }
                        .padding(.vertical, 4).background(Color.tatiCream)
                }
        }.background { Color.tatiCream.ignoresSafeArea(.container) }
            .foregroundStyle(Color.tatiInk).tatiScreen()
            .sheet(isPresented: $more) { SafetyActionsView(subjectID: "person:" + person.id, authorID: person.id) }
            .onChange(of: store.account.blocked) { _, _ in closeIfHidden() }
            .onChange(of: store.account.hiddenSubjects) { _, _ in closeIfHidden() }
    }

    private var followAction: some View {
        FollowControl(userID: person.id, style: .artwork(height: 44)).frame(maxWidth: .infinity)
    }
    private var messageAction: some View {
        NavigationLink(destination: ConversationView(person: person)) {
            Art(name: "chat-button", height: 44).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.plain).accessibilityLabel("Chat with " + person.name)
    }
    private func profileTag(_ text: String, highlighted: Bool) -> some View {
        Text(text).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
            .background(highlighted ? Color.tatiLime.opacity(0.65) : Color.tatiCream, in: Capsule())
    }
    private func closeIfHidden() { if store.isPersonHidden(person.id) { dismiss() } }
}
struct MyProfileView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .top) {
                        GeometryReader { geometry in
                            coverImage.resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        }.frame(height: 230 + viewport.safeAreaInsets.top)
                        HStack(spacing: 2) {
                            Art(name: "profile-heading", width: 136, height: 48, alignment: .leading)
                            Spacer()
                            NavigationLink(destination: WalletView()) { Art(name: "coin", width: 22).frame(width: 44, height: 44) }.accessibilityLabel("Wallet")
                            NavigationLink(destination: SettingsView()) { Art(name: "settings", width: 22).frame(width: 44, height: 44) }.accessibilityLabel("Settings")
                        }.padding(.horizontal, 16).padding(.top, viewport.safeAreaInsets.top + 4)
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
                            NavigationLink(destination: RelationshipView(kind: "Following")) { stat("\(store.followingIDs.count)", "Following") }
                            NavigationLink(destination: RelationshipView(kind: "Follower")) { stat("\(store.followerIDs.count)", "Follower") }
                            NavigationLink(destination: RelationshipView(kind: "Friends")) { stat("\(store.mutualIDs.count)", "Friends") }
                        }.buttonStyle(.plain).padding(.vertical, 10).background(Color(red: 1, green: 0.96, blue: 0.24)).clipShape(RoundedRectangle(cornerRadius: 7))
                        HStack(spacing: 12) {
                            NavigationLink(destination: CheckInView()) { Art(name: "checkin-entry") }.accessibilityLabel("Check in")
                            NavigationLink(destination: WalletView()) { Art(name: "wallet-entry") }.accessibilityLabel("My wallet")
                        }.padding(.vertical, 3)
                        VStack(spacing: 0) {
                            NavigationLink(destination: ConversationsView()) {
                                HStack(spacing: 12) {
                                    SupplementIcon(icon: .comment, size: 22)
                                    Text("Messages").font(.system(size: 14))
                                    Spacer()
                                    Art(name: "chevron", width: 14, height: 14)
                                }.padding(18).frame(minHeight: 50)
                            }
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
            }.ignoresSafeArea(.container, edges: .top)
        }.background { Color.tatiCream.ignoresSafeArea(.container) }
            .foregroundStyle(Color.tatiInk)
    }
    private var coverImage: Image {
        if let file = store.account.profile.coverFile,
           let image = UIImage(contentsOfFile: store.mediaURL(file).path) {
            return Image(uiImage: image)
        }
        return Image(ProfileArtwork.defaultPortrait)
    }
    private func stat(_ value: String, _ title: String) -> some View { VStack(spacing: 4) { Text(value).font(.headline); Text(title).font(.caption) }.frame(maxWidth: .infinity) }
}
struct RelationshipView: View {
    var kind: String
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: kind) {
            let ids = kind == "Following" ? store.followingIDs : kind == "Friends" ? store.mutualIDs : store.followerIDs
            let people = store.visiblePeople.filter { ids.contains($0.id) }
            if people.isEmpty { EmptyContent(title: "No \(kind.lowercased()) yet", detail: "Connections appear here after people choose to follow.") }
            ForEach(people) { person in
                HStack(spacing: 10) {
                    UserProfileLink(userID: person.id) { HStack { Avatar(asset: person.portraitArtwork, size: 38); Text(person.name).font(.system(size: 14)) } }
                    Spacer()
                    FollowControl(userID: person.id)
                    NavigationLink(destination: ConversationView(person: person)) { SupplementIcon(icon: .comment, size: 22).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Chat with " + person.name)
                }.padding(.horizontal, 12).padding(.vertical, 4).background { Image("outlined-card").resizable() }
            }
        }
    }
}
struct MyVideosView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: "My videos") {
            NavigationLink(destination: PublishVideoView()) { SettingRow(title: "Add a video", asset: "add-video") }
            if store.account.clips.isEmpty { EmptyContent(title: "Your story starts here", detail: "Add a food video to your collection.") }
            ForEach(store.account.clips.filter { !store.isHidden("video:" + $0.id) }) { clip in
                VStack(alignment: .leading, spacing: 8) {
                    Text(clip.moderationStatus == "approved" ? "Published" : "Awaiting review · Only you can see this")
                        .font(.caption).foregroundStyle(Color.tatiOlive)
                    FeedVideoCard(clip: clip)
                }
            }
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
    @State private var loadedProfile = false
    private var loading: Bool { loadingAvatar || loadingCover }
    var body: some View {
        TatiEditingForm(title: "Edit profile") {
            profilePhotos
            TatiEditingField(label: "Display name", placeholder: "What should we call you?", text: $name, limit: 32)
            TatiEditingField(label: "About you", placeholder: "Your favourite food, a little about you…", text: $bio, limit: 200, multiline: true)
            TatiEditingField(label: "Country / region", placeholder: "Add your country or region (optional)", text: $country)
            VStack(alignment: .leading, spacing: 10) {
                Text("Favourite food").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                FilterTagLayout {
                    ForEach(Array(FoodCatalog.topics.dropFirst()), id: \.self) { value in
                        BrowseFilterChip(title: value, selected: interest == value) { interest = value }
                    }
                }
            }
        } footer: {
            TatiEditingButton(title: loading ? "Loading photo…" : "Save changes", enabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !loading) { save() }
        }.onAppear {
            guard !loadedProfile else { return }
            loadedProfile = true
            name = store.account.profile.name; bio = store.account.profile.bio
            country = store.account.profile.country; interest = store.account.profile.interest
        }
        .task(id: avatarItem) { guard let avatarItem else { return }; loadingAvatar = true; defer { loadingAvatar = false }; do { let data = try await avatarItem.loadTransferable(type: Data.self); guard !Task.isCancelled else { return }; avatarData = data; removeAvatar = false } catch { store.tell("Photo unavailable", "Please choose another photo. Your other edits are still here.") } }
        .task(id: coverItem) { guard let coverItem else { return }; loadingCover = true; defer { loadingCover = false }; do { let data = try await coverItem.loadTransferable(type: Data.self); guard !Task.isCancelled else { return }; coverData = data; removeCover = false } catch { store.tell("Photo unavailable", "Please choose another cover. Your other edits are still here.") } }
    }
    private var profilePhotos: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profile photos").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Spacer()
                if coverData != nil || (!removeCover && store.account.profile.coverFile != nil) {
                    Button("Reset cover") { coverData = nil; coverItem = nil; removeCover = true }
                        .font(.caption.weight(.semibold)).frame(minHeight: 44).buttonStyle(.plain)
                        .disabled(loadingCover)
                }
            }.frame(minHeight: 28)
            VStack(spacing: 0) {
                PhotosPicker(selection: $coverItem, matching: .images) {
                    GeometryReader { geometry in
                        Group {
                            if let image = preview(coverData, removeCover ? nil : store.account.profile.coverFile) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else { Image(ProfileArtwork.defaultPortrait).resizable().scaledToFill() }
                        }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            .overlay(alignment: .bottomTrailing) {
                                Text(loadingCover ? "Loading…" : "Change cover")
                                    .font(.caption.weight(.semibold)).foregroundStyle(Color.tatiInk)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.white, in: Capsule()).padding(12)
                            }
                    }.frame(height: 144)
                }.buttonStyle(.plain).disabled(loadingCover).accessibilityLabel("Change cover photo")
                HStack(spacing: 12) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        HStack(spacing: 12) {
                            Group {
                                if let image = preview(avatarData, removeAvatar ? nil : store.account.profile.avatarFile) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else { Image(ProfileArtwork.defaultPortrait).resizable().scaledToFill() }
                            }.frame(width: 64, height: 64).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Profile picture").font(.subheadline.weight(.semibold))
                                Text(loadingAvatar ? "Loading…" : "Tap to change").font(.caption).foregroundStyle(Color.tatiOlive)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(loadingAvatar).accessibilityLabel("Change profile picture")
                    if avatarData != nil || (!removeAvatar && store.account.profile.avatarFile != nil) {
                        Button("Reset") { avatarData = nil; avatarItem = nil; removeAvatar = true }
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.tatiOlive)
                            .frame(minWidth: 44, minHeight: 44).buttonStyle(.plain).disabled(loadingAvatar)
                            .accessibilityLabel("Reset profile picture")
                    }
                }.padding(14)
            }.background(.white).clipShape(RoundedRectangle(cornerRadius: 20))
        }
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
struct ConversationsView: View {
    @EnvironmentObject private var store: VisitorStore
    private var people: [FoodPerson] {
        store.visiblePeople.filter { person in
            !store.messages(with: person.id).isEmpty || !(store.account.drafts[person.id] ?? "").isEmpty
                || store.account.draftImages?[person.id] != nil
        }
    }
    var body: some View {
        TatiPage(title: "Messages") {
            if people.isEmpty { EmptyContent(title: "No conversations yet", detail: "Open a profile to start a conversation.") }
            ForEach(people) { person in
                HStack(spacing: 12) {
                    UserProfileLink(userID: person.id) { Avatar(asset: person.portraitArtwork, size: 44) }
                    VStack(alignment: .leading, spacing: 4) {
                        UserProfileLink(userID: person.id) { Text(person.name).font(.headline) }
                        NavigationLink(destination: ConversationView(person: person)) {
                            Text(store.messages(with: person.id).last?.text ?? store.account.drafts[person.id] ?? "Photo attachment")
                                .font(.caption).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                    NavigationLink(destination: ConversationView(person: person)) {
                        Art(name: "chevron", width: 14, height: 14).frame(width: 44, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Open conversation")
                }.padding(.vertical, 8)
            }
        }
    }
}

struct ConversationView: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    @State private var text = ""
    @State private var gifts = false
    @State private var showCall = false
    @State private var showSafety = false
    @State private var reportedMessage: LocalMessage?
    @Environment(\.dismiss) private var dismiss
    private var messages: [LocalMessage] { store.messages(with: person.id) }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ArtButton(asset: "back", label: "Back") { dismiss() }
                    UserProfileLink(userID: person.id) {
                        HStack(spacing: 7) {
                            Avatar(asset: person.portraitArtwork, size: 38)
                            Text(person.name).font(.system(size: 15, weight: .medium)).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    FollowControl(userID: person.id)
                    ArtButton(asset: "add-video", label: "Video call", size: 24) {
                        if store.requireMutualFollow(person.id) { showCall = true }
                    }
                    ArtButton(asset: "more", label: "Report or block", size: 22) { showSafety = true }
                }.padding(.horizontal, 6)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                let mine = message.senderID == nil || message.senderID == store.account.profile.id
                                HStack(alignment: .top, spacing: 8) {
                                    if mine { Spacer(minLength: 36) }
                                    else { UserProfileLink(userID: person.id) { Avatar(asset: person.portraitArtwork, size: 32) } }
                                    VStack(alignment: .leading, spacing: 6) {
                                        if !mine { UserProfileLink(userID: person.id) { Text(person.name).font(.caption.bold()) } }
                                        if let file = message.imageFile, let image = UIImage(contentsOfFile: store.mediaURL(file).path) {
                                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        if !message.text.isEmpty { Text(message.text).font(.system(size: 14)).textSelection(.enabled) }
                                        HStack {
                                            Text(message.createdAt, style: .time)
                                            if mine { Text(message.status) }
                                        }.font(.system(size: 10)).opacity(0.8)
                                    }.padding(12).foregroundStyle(mine ? Color.white : Color.tatiInk)
                                        .background(mine ? Color.tatiPink : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    if !mine {
                                        ArtButton(asset: "more", label: "Report message", size: 18) { reportedMessage = message }
                                        Spacer(minLength: 16)
                                    }
                                }.id(message.id)
                            }
                        }.padding(16)
                    }.scrollDismissesKeyboard(.interactively)
                    .onAppear { if let id = messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
                    .onChange(of: messages.map(\.id)) { _, ids in if let id = ids.last { proxy.scrollTo(id, anchor: .bottom) } }
                }
                if store.account.draftImages?[person.id] != nil { DraftPhotoAttachment(draftKey: person.id).padding(.horizontal, 12) }
                let inputLayout = geometry.size.width < 350
                    ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 4))
                    : AnyLayout(HStackLayout(spacing: 2))
                inputLayout {
                    HStack(spacing: 2) {
                        ArtButton(asset: "chat-mic", label: "Voice message", size: 32) {
                            if store.requireMutualFollow(person.id) { store.tell("Voice messaging unavailable", "No recording has started.") }
                        }
                        HStack(spacing: 0) {
                            TextField("Say Hi~", text: $text, axis: .vertical).lineLimit(1...4)
                                .font(.system(size: 13)).padding(.leading, 12).padding(.vertical, 8).tint(.white)
                                .onChange(of: text) { _, value in
                                    let limited = String(value.prefix(2000))
                                    if limited != value { text = limited }
                                    _ = store.saveDraft(person.id, text: limited)
                                }
                            Button { if store.attemptMessage(to: person.id, text: text) { text = "" } } label: {
                                SupplementIcon(icon: .send, size: 22, tint: .white).frame(width: 44, height: 44)
                            }.buttonStyle(.plain).accessibilityLabel("Send message")
                        }.foregroundStyle(.white).background(Color.tatiPink).clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    HStack(spacing: 2) {
                        DraftPhotoAttachment(draftKey: person.id, compact: true)
                        ArtButton(asset: "gift-chat", label: "Gifts", size: 32) { gifts = true }
                    }
                }.padding(.horizontal, 8).padding(.vertical, 6).background(Color.tatiLime.opacity(0.7))
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).tatiScreen()
        .onAppear { text = store.account.drafts[person.id] ?? ""; if store.isPersonHidden(person.id) { dismiss() } }
        .onChange(of: store.account.blocked) { _, _ in if store.isPersonHidden(person.id) { dismiss() } }
        .onChange(of: store.account.hiddenSubjects) { _, _ in if store.isPersonHidden(person.id) { dismiss() } }
        .sheet(isPresented: $showSafety) { SafetyActionsView(subjectID: "person:" + person.id, authorID: person.id) }
        .sheet(item: $reportedMessage) { message in SafetyActionsView(subjectID: "message:" + message.id, authorID: person.id, contextID: person.id) }
        .fullScreenCover(isPresented: $showCall) { VideoCallView(person: person).overlay { NoticeLayer() } }
        .sheet(isPresented: $gifts) { NavigationStack { GiftShopView(recipient: person) }.overlay { NoticeLayer() } }
    }
}

struct VideoCallView: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var playback: ClipPlayback
    @EnvironmentObject private var roomSession: RoomPreviewSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraPreviewController()
    @State private var cameraTask: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            TatiPage(title: "Video call", scrolling: false) {
                VStack(spacing: 16) {
                    UserProfileLink(userID: person.id) {
                        HStack { Avatar(asset: person.portraitArtwork, size: 44); Text(person.name).font(.headline) }
                    }
                    GeometryReader { geometry in
                        ZStack {
                            Color.black
                            if camera.ready { CameraSurface(session: camera.session) }
                            else { Text(camera.status).font(.subheadline).foregroundStyle(.white).multilineTextAlignment(.center).padding(24) }
                        }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    }.clipShape(RoundedRectangle(cornerRadius: 20))
                    Text("Only you can see your camera. Calls are not connected yet.").font(.caption).foregroundStyle(Color.tatiOlive)
                    if !camera.ready { TatiButton(title: camera.starting ? "Starting camera…" : "Enable camera", secondary: true, enabled: !camera.starting) { startCamera() } }
                    TatiButton(title: "Close") { cameraTask?.cancel(); camera.stop(); dismiss() }
                }
            }
        }
        .onAppear { startCamera() }
        .onDisappear { cameraTask?.cancel(); camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            // Permission sheets temporarily make the scene inactive. Keep their
            // request alive; only backgrounding should cancel camera startup.
            if phase == .background { cameraTask?.cancel(); camera.stop() }
            else if phase == .active, !camera.starting, !camera.ready { startCamera() }
        }
        .onChange(of: store.account.following) { _, _ in checkPermission() }
        .onChange(of: store.account.followers) { _, _ in checkPermission() }
        .onChange(of: store.account.blocked) { _, _ in checkPermission() }
        .onChange(of: store.account.hiddenSubjects) { _, _ in checkPermission() }
    }
    private func checkPermission() {
        if !store.canCommunicate(with: person.id) { cameraTask?.cancel(); camera.stop(); dismiss() }
    }
    private func startCamera() {
        guard store.requireMutualFollow(person.id) else { dismiss(); return }
        playback.stop(); roomSession.audio.stop()
        cameraTask?.cancel()
        cameraTask = Task { await camera.start(requiresMicrophone: true) }
    }
}

struct FoodExpertView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var question = ""
    @FocusState private var questionFocused: Bool
    private var savedQuestion: String { store.account.drafts["food-expert"] ?? "" }
    private var canSave: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private let prompts = [
        (title: "Make it crispy", question: "How to get crispy fried food?"),
        (title: "Plate it beautifully", question: "How to make food look delicious?"),
        (title: "Find the perfect balance", question: "How to balance sweet and savory taste?")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        introduction
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text("A little inspiration").font(.headline)
                                Art(name: "food-flame", width: 22, height: 22)
                            }
                            VStack(spacing: 0) {
                                ForEach(prompts.indices, id: \.self) { index in
                                    promptRow(index)
                                    if index < prompts.count - 1 {
                                        Color.tatiOlive.opacity(0.12).frame(height: 0.5).padding(.horizontal, 16)
                                    }
                                }
                            }.background(.white, in: RoundedRectangle(cornerRadius: 20))
                        }
                        if !savedQuestion.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your saved question").font(.headline)
                                HStack(alignment: .top, spacing: 12) {
                                    Avatar(file: store.account.profile.avatarFile, size: 34, isCurrent: true)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(savedQuestion).font(.body).fixedSize(horizontal: false, vertical: true)
                                        Text("Draft · not sent").font(.caption).foregroundStyle(Color.tatiOlive)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                            }.id("saved-question")
                        }
                    }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 20)
                        .frame(maxWidth: 680).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: savedQuestion) { _, value in
                        if !value.isEmpty { proxy.scrollTo("saved-question", anchor: .bottom) }
                    }
            }
            composer
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Color.tatiCream.ignoresSafeArea(.container) }
            .foregroundStyle(Color.tatiInk)
    }

    private var introduction: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Art(name: "brand-heading", width: 112, height: 38, alignment: .leading)
                Text("What's cooking?").font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Food & flavour with Yimeng, your AI food expert.")
                    .font(.subheadline).foregroundStyle(Color.tatiOlive)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Art(name: "chef", width: 100, height: 142, alignment: .bottom)
        }.padding(16).frame(maxWidth: .infinity, minHeight: 172)
            .background {
                GeometryReader { geometry in
                    Image("page-background").resizable()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(0.55)
                }.accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func promptRow(_ index: Int) -> some View {
        let prompt = prompts[index]
        return Button {
            question = prompt.question
            questionFocused = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(prompt.title).font(.subheadline.weight(.semibold))
                    Text(prompt.question).font(.caption).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "chevron", width: 8, height: 12)
            }.padding(16).frame(minHeight: 64).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(prompt.question)
            .accessibilityHint("Adds this question to the input field")
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about food", text: $question,
                      prompt: Text("What's on your mind?").foregroundColor(.tatiOlive), axis: .vertical)
                .lineLimit(1...4).font(.body).tint(.tatiOlive)
                .focused($questionFocused)
                .padding(.leading, 6).padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Your food question")
            Button {
                guard canSave else { return }
                if store.saveDraft("food-expert", text: question) {
                    question = ""
                    questionFocused = false
                    store.tell("Question saved", "AI replies are currently unavailable. Your question is saved as a draft.")
                }
            } label: {
                Art(name: "ai-off", width: 26, height: 26)
                    .frame(width: 46, height: 46)
                    .background(canSave ? Color.tatiLime : Color.tatiCream, in: RoundedRectangle(cornerRadius: 15))
            }.buttonStyle(.plain).disabled(!canSave).accessibilityLabel("Save food question")
        }.padding(8).background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.tatiOlive.opacity(0.16), lineWidth: 0.6).allowsHitTesting(false)
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 10)
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color.tatiCream)
    }
}
