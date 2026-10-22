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
                VStack(spacing: -28) {
                    NavigationLink(destination: PortraitPhotoView(person: person)) {
                        ContentPhoto(asset: person.portraitArtwork,
                                     height: min(500, max(280, viewport.size.height * 0.52)) + viewport.safeAreaInsets.top)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View full photo")

                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(person.name)
                                    .font(.largeTitle.weight(.bold))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityAddTraits(.isHeader)
                                Text(person.city == person.country ? person.country : "\(person.city) · \(person.country)")
                                    .font(.subheadline).foregroundStyle(Color.tatiOlive)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            FilterTagLayout() {
                                profileTag(person.interest, highlighted: true)
                                profileTag(person.language, highlighted: false)
                            }
                            if !person.bio.isEmpty {
                                Text(person.bio).font(.body).lineSpacing(5)
                                    .foregroundStyle(Color.tatiOlive)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 12) { followAction; messageAction }
                                VStack(spacing: 12) { followAction; messageAction }
                            }
                            .padding(.top, 4)
                        }
                        Rectangle().fill(Color.tatiInk.opacity(0.08)).frame(height: 1)
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("Videos").font(.title3.weight(.bold))
                                    .accessibilityAddTraits(.isHeader)
                                Text(clips.count.formatted())
                                    .font(.subheadline.weight(.medium)).monospacedDigit()
                                    .foregroundStyle(Color.tatiOlive)
                                Spacer()
                            }
                            if clips.isEmpty {
                                HStack(spacing: 16) {
                                    Art(name: "support-mascot", width: 48, height: 54)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("No videos yet").font(.subheadline.weight(.semibold))
                                        Text("New videos will appear here.")
                                            .font(.caption).foregroundStyle(Color.tatiOlive)
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.tatiCream.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
                            } else {
                                ForEach(clips) { clip in FeedVideoCard(clip: clip) }
                            }
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 32)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .top)
        }
        .overlay(alignment: .top) {
            profileNavigation.padding(.horizontal, 16).padding(.top, 4)
        }
        .background { Color.white.ignoresSafeArea(.container) }
        .foregroundStyle(Color.tatiInk).tatiScreen()
        .sheet(isPresented: $more) { SafetyActionsView(subjectID: "person:" + person.id, authorID: person.id) }
        .onChange(of: store.account.blocked) { _, _ in closeIfHidden() }
        .onChange(of: store.account.hiddenSubjects) { _, _ in closeIfHidden() }
    }

    // Controls remain inside the container's safe area; only the photograph extends above it.
    private var profileNavigation: some View {
        HStack {
            ArtButton(asset: "back", label: "Back", size: 24) { dismiss() }
                .background(Color.tatiCream.opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
            Spacer()
            ArtButton(asset: "more", label: "Report or block", size: 26) { more = true }
                .background(Color.tatiCream.opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var followAction: some View {
        FollowControl(userID: person.id, style: .artwork(height: 44))
            .frame(minWidth: 120, maxWidth: .infinity, minHeight: 44)
    }
    private var messageAction: some View {
        NavigationLink(destination: ConversationView(person: person)) {
            Art(name: "chat-button", height: 44)
                .frame(minWidth: 120, maxWidth: .infinity, minHeight: 44)
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
                            PreparedPhoto(source: coverSource, fallbackAsset: ProfileArtwork.defaultPortrait)
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
                        MessagesProfileEntry().padding(.vertical, 8)
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
            }.ignoresSafeArea(.container, edges: .top)
        }.background { Color.tatiCream.ignoresSafeArea(.container) }
            .foregroundStyle(Color.tatiInk)
    }
    private var coverSource: PhotoSource {
        if let file = store.account.profile.coverFile { return .file(store.mediaURL(file)) }
        return .asset(ProfileArtwork.defaultPortrait)
    }
    private func stat(_ value: String, _ title: String) -> some View { VStack(spacing: 4) { Text(value).font(.headline); Text(LocalizedStringKey(title)).font(.caption) }.frame(maxWidth: .infinity) }
}
struct RelationshipView: View {
    var kind: String
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: kind, lazyContent: true) {
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
        TatiPage(title: "My videos", lazyContent: true) {
            NavigationLink(destination: PublishVideoView()) { SettingRow(title: "Add a video", asset: "add-video") }
            if store.account.clips.isEmpty { EmptyContent(title: "Your story starts here", detail: "Add a food video to your collection.") }
            ForEach(store.account.clips.filter { !store.isHidden("video:" + $0.id) }) { clip in
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(clip.moderationStatus == "approved" ? "Published" : "Awaiting review · Only you can see this"))
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
                            photoPreview(coverData, removeCover ? nil : store.account.profile.coverFile, maxPixels: 1_200)
                        }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            .overlay(alignment: .bottomTrailing) {
                                Text(LocalizedStringKey(loadingCover ? "Loading…" : "Change cover"))
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
                                photoPreview(avatarData, removeAvatar ? nil : store.account.profile.avatarFile, maxPixels: 256)
                            }.frame(width: 64, height: 64).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Profile picture").font(.subheadline.weight(.semibold))
                                Text(LocalizedStringKey(loadingAvatar ? "Loading…" : "Tap to change")).font(.caption).foregroundStyle(Color.tatiOlive)
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

    @ViewBuilder private func photoPreview(_ data: Data?, _ file: String?, maxPixels: Int) -> some View {
        if let data { PreparedDataPhoto(data: data, maxPixels: maxPixels) }
        else if let file { PreparedPhoto(source: .file(store.mediaURL(file)), fallbackAsset: ProfileArtwork.defaultPortrait) }
        else { PreparedPhoto(source: .asset(ProfileArtwork.defaultPortrait)) }
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
// Every entry uses the same destination and the same persisted conversation state.
struct MessagesToolbarEntry: View {
    var body: some View {
        NavigationLink(destination: ConversationsView()) {
            SupplementIcon(icon: .comment, size: 23, tint: .tatiInk)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).accessibilityLabel("Messages")
    }
}

private struct MessagesProfileEntry: View {
    var body: some View {
        NavigationLink(destination: ConversationsView()) {
            HStack(spacing: 14) {
                SupplementIcon(icon: .comment, size: 28, tint: .tatiInk)
                    .frame(width: 54, height: 54)
                    .background(Color.tatiLime, in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Messages").font(.title3.weight(.bold))
                    Text("Your conversations, all together.")
                        .font(.subheadline).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "chevron", width: 12, height: 16)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                .contentShape(RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain)
    }
}

struct ConversationsView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var query = ""
    @State private var draftsOnly = false
    @FocusState private var searching: Bool
    private var people: [FoodPerson] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.conversationPeople.filter {
            (!draftsOnly || store.hasConversationDraft(with: $0.id)) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) ||
             (store.account.drafts[$0.id] ?? "").localizedCaseInsensitiveContains(search) ||
             store.hasMessage(with: $0.id, matching: search))
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            TatiHeader(title: "Messages")
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    introduction
                    searchField
                    HStack(spacing: 8) {
                        filter("All conversations", selected: !draftsOnly) { draftsOnly = false }
                        filter("Drafts", selected: draftsOnly) { draftsOnly = true }
                    }
                    if people.isEmpty { emptyState }
                    else {
                        LazyVStack(spacing: 10) {
                            ForEach(people) { person in conversationRow(person) }
                        }
                    }
                }.padding(18).padding(.bottom, 16)
                    .frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
        }.background { Color.tatiCream.ignoresSafeArea(.container) }
            .foregroundStyle(Color.tatiInk).tatiScreen()
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A little hello.").font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Good food brings us together. Keep the conversation going.")
                        .font(.subheadline).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "support-mascot", width: 62, height: 76)
            }
            NavigationLink(destination: RelationshipView(kind: "Following")) {
                HStack(spacing: 10) {
                    Text("Start a conversation").font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Art(name: "chevron", width: 10, height: 14)
                }.padding(.horizontal, 16).padding(.vertical, 13)
                    .frame(minHeight: 48)
                    .background(Color.tatiPink.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain)
            Text("Messages and calls open when you follow each other.")
                .font(.caption).foregroundStyle(Color.tatiOlive)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var searchField: some View {
        HStack(spacing: 10) {
            Art(name: "search", width: 22, height: 26)
            TextField("Search conversations", text: $query)
                .font(.subheadline).focused($searching).submitLabel(.search)
                .onSubmit { searching = false }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Art(name: "close-light", width: 20, height: 20).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }.padding(.leading, 14).padding(.trailing, 6).frame(minHeight: 54)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
    private func filter(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15).padding(.vertical, 12).frame(minHeight: 44)
                .foregroundStyle(selected ? Color.tatiCream : Color.tatiOlive)
                .background(selected ? Color.tatiInk : Color.white.opacity(0.65), in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(store.conversationPeople.isEmpty ? "Your next hello starts here" : "No matching conversations"))
                .font(.title3.weight(.bold))
            Text(LocalizedStringKey(store.conversationPeople.isEmpty
                 ? "Open a profile to write a message. Your drafts will wait here for you."
                 : "Try another name or switch back to all conversations."))
                .font(.subheadline).foregroundStyle(Color.tatiOlive)
            if !store.conversationPeople.isEmpty {
                Button("Show all conversations") { query = ""; draftsOnly = false }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44).buttonStyle(.plain)
            }
        }.fixedSize(horizontal: false, vertical: true)
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 22))
    }
    private func conversationRow(_ person: FoodPerson) -> some View {
        let draft = store.hasConversationDraft(with: person.id)
        let latest = store.latestMessage(with: person.id)
        return HStack(alignment: .top, spacing: 12) {
            UserProfileLink(userID: person.id) { Avatar(asset: person.portraitArtwork, size: 52) }
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    UserProfileLink(userID: person.id) {
                        Text(person.name).font(.headline).lineLimit(2).frame(minHeight: 44, alignment: .leading)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if draft {
                        Text("Draft").font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.tatiPink.opacity(0.2), in: Capsule())
                    } else if let latest {
                        Text(latest.createdAt, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2).foregroundStyle(Color.tatiOlive)
                    }
                }
                NavigationLink(destination: ConversationView(person: person)) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            preview(person, draft: draft, latest: latest)
                                .font(.subheadline).foregroundStyle(Color.tatiOlive).lineLimit(2)
                            if !draft, let latest,
                               latest.senderID == nil || latest.senderID == store.account.profile.id {
                                Text(LocalizedStringKey(latest.status)).font(.caption2)
                                    .foregroundStyle(Color.tatiOlive)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Art(name: "chevron", width: 9, height: 13)
                    }.frame(minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityHint("Open conversation")
            }
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
    private func preview(_ person: FoodPerson, draft: Bool, latest: LocalMessage?) -> Text {
        if draft {
            let text = (store.account.drafts[person.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? Text("Photo attachment") : Text(verbatim: text)
        }
        if let latest, !latest.text.isEmpty { return Text(verbatim: latest.text) }
        return Text("Photo attachment")
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
                                        if let file = message.imageFile {
                                            PreparedPhoto(source: .file(store.mediaURL(file)), fills: false)
                                                .frame(width: min(220, geometry.size.width * 0.58), height: 180)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                                    store.scheduleDraft(person.id, text: limited)
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
        .onDisappear { store.flushDraft(person.id) }
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
                    Text(LocalizedStringKey(prompt.title)).font(.subheadline.weight(.semibold))
                    Text(LocalizedStringKey(prompt.question)).font(.caption).foregroundStyle(Color.tatiOlive)
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
