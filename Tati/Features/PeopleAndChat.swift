import SwiftUI
import PhotosUI

struct PersonProfileView: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    @State private var more = false
    @Environment(\.dismiss) private var dismiss
    @State private var gift = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink(destination: PortraitPhotoView(person: person)) {
                    ContentPhoto(asset: person.portraitArtwork, height: 420)
                }.buttonStyle(.plain).accessibilityLabel("View full photo")
                    .overlay(alignment: .top) { TatiHeader(title: "", trailing: "more") { more = true } }
                    .overlay(alignment: .bottomLeading) {
                        if store.account.following.contains(person.id) {
                            ImageAction(asset: "followed-button", label: "Unfollow \(person.name)", height: 46) { store.toggleFollow(person.id) }
                                .frame(width: 154).padding(.leading, 20).padding(.bottom, 48)
                        }
                    }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Avatar(asset: person.portraitArtwork, size: 62).padding(.top, -24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                            Text(person.country).font(.system(size: 11)).foregroundStyle(Color.tatiOlive).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        ArtButton(asset: "gift-chat", label: "Gifts", size: 30) { gift = true }
                    }
                    Text(person.bio).font(.system(size: 13)).foregroundStyle(Color.tatiOlive)
                    Text(person.interest).font(.system(size: 10)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.tatiLime).clipShape(RoundedRectangle(cornerRadius: 3))
                    HStack(spacing: 10) {
                        ImageAction(asset: store.account.following.contains(person.id) ? "followed-button" : "follow-button", label: store.account.following.contains(person.id) ? "Unfollow \(person.name)" : "Follow \(person.name)", height: 42) { store.toggleFollow(person.id) }
                        NavigationLink(destination: ConversationView(person: person)) { Art(name: "chat-button", height: 42).frame(maxWidth: .infinity) }.accessibilityLabel("Chat with \(person.name)")
                    }.padding(.vertical, 4)
                    Text("Video").font(.system(size: 17, weight: .bold))
                    if store.account.blocked.contains(person.id) { EmptyContent(title: "Profile blocked", detail: "Unblock this profile in Settings to see its content.") }
                    else {
                        ForEach(store.visibleClips.filter { $0.authorID == person.id }) { clip in
                            FeedVideoCard(clip: clip)
                        }
                        if !store.visibleClips.contains(where: { $0.authorID == person.id }) { EmptyContent(title: "No videos yet", detail: "This profile doesn't have any videos yet.") }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 16)
            }.frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).tatiScreen()
        .sheet(isPresented: $more) { SafetyActionsView(subjectID: "person:" + person.id, authorID: person.id) }
        .onChange(of: store.account.blocked) { _, _ in if store.isPersonHidden(person.id) { dismiss() } }
        .onChange(of: store.account.hiddenSubjects) { _, _ in if store.isPersonHidden(person.id) { dismiss() } }
        .sheet(isPresented: $gift) { NavigationStack { GiftShopView(recipient: person) }.overlay { NoticeLayer() }.presentationDetents([.height(390), .large]) }
    }
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
                            NavigationLink(destination: RelationshipView(kind: "Following")) { stat("\(store.account.following.filter { !store.isPersonHidden($0) }.count)", "Following") }
                            NavigationLink(destination: RelationshipView(kind: "Follower")) { stat("\((store.account.followers ?? []).filter { !store.isPersonHidden($0) }.count)", "Follower") }
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
            let ids = kind == "Following" ? store.account.following : kind == "Friends" ? store.mutualIDs : (store.account.followers ?? [])
            let people = store.visiblePeople.filter { ids.contains($0.id) }
            if people.isEmpty { EmptyContent(title: "No \(kind.lowercased()) yet", detail: "Connections appear here after people choose to follow.") }
            ForEach(people) { person in
                HStack(spacing: 10) {
                    UserProfileLink(userID: person.id) { HStack { Avatar(asset: person.portraitArtwork, size: 38); Text(person.name).font(.system(size: 14)) } }
                    Spacer()
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
    @State private var moreDetails = false
    private var loading: Bool { loadingAvatar || loadingCover }
    var body: some View {
        TatiForm(title: "Edit profile") {
            PhotosPicker(selection: $coverItem, matching: .images) {
                Group {
                    if let image = preview(coverData, removeCover ? nil : store.account.profile.coverFile) {
                        GeometryReader { geometry in
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        }.frame(height: 190)
                    }
                    else {
                        GeometryReader { geometry in
                            Image(ProfileArtwork.defaultPortrait).resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        }.frame(height: 190)
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain)
            InputField(title: "Please enter the name…", text: $name, showsLabel: false).onChange(of: name) { _, value in name = String(value.prefix(32)) }
            PhotosPicker(selection: $avatarItem, matching: .images) {
                Group {
                    if let image = preview(avatarData, removeAvatar ? nil : store.account.profile.avatarFile) { Image(uiImage: image).resizable().scaledToFill() }
                    else { Image(ProfileArtwork.defaultPortrait).resizable().scaledToFill() }
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
        .sheet(isPresented: $gifts) { NavigationStack { GiftShopView(recipient: person) }.overlay { NoticeLayer() }.presentationDetents([.height(390), .large]) }
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
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { viewport in
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(alignment: .bottom, spacing: 8) {
                            VStack(alignment: .leading, spacing: 16) {
                                Art(name: "brand-heading", width: 130, height: 44, alignment: .leading)
                                Text("Hi, I'm your AI Food Expert Yimeng!")
                                    .font(.system(size: 18, weight: .medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 18)
                            Art(name: "chef", width: min(116, viewport.size.width * 0.29), height: 145, alignment: .bottom)
                        }.padding(.horizontal, 18).padding(.top, 4)
                            .frame(maxWidth: 680, minHeight: 160, alignment: .bottom)
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
                        }.padding(18).frame(maxWidth: 680, alignment: .leading)
                            .frame(maxWidth: .infinity, minHeight: max(0, viewport.size.height - 160), alignment: .top)
                            .background(.white).clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
                    }
                }.scrollDismissesKeyboard(.interactively)
            }
            HStack(spacing: 8) {
                TextField("Ask about food…", text: $question, axis: .vertical).lineLimit(1...4).font(.system(size: 14)).padding(12).background(Color.tatiCream).clipShape(RoundedRectangle(cornerRadius: 22))
                Button {
                    guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    if store.saveDraft("food-expert", text: question) {
                        question = ""
                        store.tell("Question saved", "AI replies are currently unavailable. Your question is saved as a draft.")
                    }
                } label: { Art(name: "ai-off", width: 30, height: 30).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Save food question")
            }.padding(.horizontal, 18).padding(.vertical, 8)
                .frame(maxWidth: 680).frame(maxWidth: .infinity).background(.white)
        }.frame(maxWidth: .infinity)
            // Keep the original full-page gradient at screen scale. Only the
            // artwork extends beneath the status bar; text remains in the safe area.
            .background {
                GeometryReader { backdrop in
                    Image("page-background").resizable()
                        .frame(width: backdrop.size.width, height: backdrop.size.height)
                }.ignoresSafeArea(.container).accessibilityHidden(true)
            }
            .foregroundStyle(Color.tatiInk)
    }
}
