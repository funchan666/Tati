import SwiftUI
import PhotosUI
import AVFoundation

struct PersonProfileView: View {
    var person: TableMember
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @State private var more = false
    private var clips: [FoodFilm] { store.visibleClips.filter { $0.authorID == person.id } }
    private let paper = Color.tatiProfilePaper
    private var location: String { person.locationLabel ?? "" }

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: -28) {
                    NavigationLink(destination: PortraitPhotoView(person: person)) {
                        ContentPhoto(asset: person.portraitArtwork,
                                     height: min(500, max(280, viewport.size.height * 0.52)) + viewport.safeAreaInsets.top)
                    }
                    .buttonStyle(.plain).accessibilityLabel("View full photo")

                    VStack(spacing: 0) {
                        identity
                            .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 26)
                            .frame(maxWidth: 680).frame(maxWidth: .infinity)
                            .background(paper, in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
                        gallery(width: viewport.size.width)
                    }
                }.frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .top)
        }
        .overlay(alignment: .top) {
            profileNavigation.padding(.horizontal, 16).padding(.top, 4)
        }
        .background { Color.tatiProfileSage.ignoresSafeArea(.container) }
        .foregroundStyle(Color.tatiInk).tatiScreen()
        .profileNavigationHost()
        .sheet(isPresented: $more) { SafetyActionsView(subjectID: "person:" + person.id, authorID: person.id) }
        .onChange(of: store.account.blocked) { _, _ in closeIfHidden() }
        .onChange(of: store.account.hiddenSubjects) { _, _ in closeIfHidden() }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(person.name)
                        .font(.tati(.largeTitle, design: .serif, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if !location.isEmpty {
                        Text(location).font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize {
                    FoodTopicArtwork(topic: person.interest, side: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
            if !person.bio.isEmpty {
                Text(person.bio).font(.tati(.body)).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FilterTagLayout {
                if !person.interest.isEmpty { profileTag(person.interest, highlighted: true) }
                if !person.language.isEmpty { profileTag(person.language, highlighted: false) }
            }
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 10) { followAction; messageAction }
                } else {
                    HStack(spacing: 10) { followAction; messageAction }
                }
            }.padding(.top, 4)
        }
    }

    private func gallery(width: CGFloat) -> some View {
        let count = typeSize.isAccessibilitySize || width < 380 || clips.count <= 1 ? 1 : width >= 650 ? 3 : 2
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Food moments")
                    .font(.tati(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Color.tatiInk).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                Text(clips.count.formatted())
                    .font(.tati(.largeTitle, design: .serif, weight: .bold)).monospacedDigit()
                    .foregroundStyle(Color.tatiOlive)
                    .accessibilityLabel("Videos").accessibilityValue(clips.count.formatted())
            }
            if clips.isEmpty {
                HStack(spacing: 18) {
                    if !typeSize.isAccessibilitySize {
                        Art(name: "discovery-live-camera", width: 92, height: 100)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No videos yet").font(.tati(.headline))
                        Text("New videos will appear here.").font(.tati(.subheadline))
                            .fixedSize(horizontal: false, vertical: true)
                    }.foregroundStyle(Color.tatiInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.vertical, 10)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: count), alignment: .leading, spacing: 22) {
                    ForEach(clips) { clip in
                        ProfileMomentTile(clip: clip, featured: count == 1)
                    }
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 32)
        .frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .center)
        .background(Color.tatiProfileSage)
    }

    // Controls stay in the safe area while the photograph remains edge to edge.
    private var profileNavigation: some View {
        HStack {
            ArtButton(asset: "back", label: "Back", size: 28) { dismiss() }
            Spacer()
            ArtButton(asset: "more", label: "Report or block", size: 28) { more = true }
        }
    }
    private var followAction: some View {
        FollowControl(userID: person.id, style: .profile).frame(maxWidth: .infinity)
    }
    private var messageAction: some View {
        NavigationLink(destination: ConversationView(person: person)) {
            HStack(spacing: 8) {
                Art(name: "discovery-messages", width: 30, height: 28)
                Text("Say hello").font(.tati(.subheadline).weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.tatiInk).padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.tatiProfileRose, in: Capsule())
        }.buttonStyle(.plain).accessibilityLabel("Chat with " + person.name)
    }
    private func profileTag(_ text: String, highlighted: Bool) -> some View {
        Text(LocalizedStringKey(text)).font(.tati(.caption).weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(highlighted ? Color.tatiInk : Color.tatiOlive)
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(highlighted ? Color.tatiProfileSage : Color.tatiProfilePaper, in: Capsule())
    }
    private func closeIfHidden() { if store.isPersonHidden(person.id) { dismiss() } }
}

/// A profile portfolio omits the repeated author/avatar; interactions use the same store.
private struct ProfileMomentTile: View {
    let clip: FoodFilm
    let featured: Bool
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.profilePageAction) private var openProfile
    @State private var showComments = false
    @State private var showOptions = false
    @State private var pendingProfile: TableMember?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                GeometryReader { geometry in
                    NavigationLink(destination: ClipDetailView(clip: clip)) {
                        ClipPoster(clip: clip, height: geometry.size.height)
                            .overlay {
                                Art(name: "film-porcelain-play", width: 48, height: 48)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Play full screen: " + clip.dishCaption)
                }
                ArtButton(asset: "more", label: "Video options: report or block", size: 24) { showOptions = true }
                    .padding(4)
            }
            .aspectRatio(featured ? 1.22 : 0.78, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            NavigationLink(destination: ClipDetailView(clip: clip)) {
                Text(clip.dishCaption).font(.tati(.subheadline).weight(.medium))
                    .lineLimit(2, reservesSpace: !featured)
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            VideoEngagementActions(clip: clip, tint: .tatiInk) { showComments = true }
        }
        .foregroundStyle(Color.tatiInk)
        .sheet(isPresented: $showComments, onDismiss: {
            if let person = pendingProfile {
                pendingProfile = nil
                if !store.isPersonHidden(person.id) { openProfile?(person) }
            }
        }) {
            NavigationStack { CommentDraftView(clip: clip) }
                .overlay { NoticeLayer() }.presentationDetents([.medium, .large])
                .environment(\.profileSheetAction, { person in
                    pendingProfile = person
                    showComments = false
                })
        }
        .sheet(isPresented: $showOptions) { VideoOptionsView(clip: clip) }
    }
}

struct MyProfileView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                                    Text(store.account.profile.name).font(.tati(size: 20, weight: .semibold)).lineLimit(2)
                                    Text("Edit profile").font(.tati(size: 11)).foregroundStyle(Color.tatiOlive)
                                }
                                Spacer(); Art(name: "chevron", width: 12)
                            }
                        }.buttonStyle(.plain)
                        profileSummary.padding(.top, 6).padding(.bottom, 4)
                        KitchenNotebookEntry().padding(.vertical, 8)
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
    private var profileSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    if !store.account.profile.bio.isEmpty {
                        Text(store.account.profile.bio).font(.tati(.subheadline))
                            .lineSpacing(3).foregroundStyle(Color.tatiCream)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !store.account.profile.interest.isEmpty {
                        Text(LocalizedStringKey(store.account.profile.interest))
                            .font(.tati(.caption).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(Color.tatiInk)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.tatiLime, in: Capsule())
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    Art(name: "profile-table-friends", width: 78, height: 82)
                }
            }
            Color.tatiCream.opacity(0.18).frame(height: 1).accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    connection("Following", count: store.followingIDs.count, accent: .tatiCream)
                    connection("Follower", count: store.followerIDs.count, accent: .tatiPink)
                    connection("Friends", count: store.mutualIDs.count, accent: .tatiLime)
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    connection("Following", count: store.followingIDs.count, accent: .tatiCream)
                    connection("Follower", count: store.followerIDs.count, accent: .tatiPink)
                    connection("Friends", count: store.mutualIDs.count, accent: .tatiLime)
                }
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tatiInk, in: RoundedRectangle(cornerRadius: 24))
    }

    private func connection(_ title: String, count: Int, accent: Color) -> some View {
        NavigationLink(destination: RelationshipView(kind: title)) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .firstTextBaseline) {
                        Text(LocalizedStringKey(title)).font(.tati(.subheadline)).foregroundStyle(Color.tatiCream)
                        Spacer(minLength: 12)
                        Text(count.formatted()).font(.tati(.title2, design: .rounded).weight(.heavy))
                            .monospacedDigit().foregroundStyle(accent)
                    }
                } else {
                    VStack(spacing: 5) {
                        Text(count.formatted()).font(.tati(.title, design: .rounded).weight(.heavy))
                            .monospacedDigit().foregroundStyle(accent)
                            .lineLimit(1).minimumScaleFactor(0.75)
                        Text(LocalizedStringKey(title)).font(.tati(.caption).weight(.medium))
                            .foregroundStyle(Color.tatiCream)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 3).frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(LocalizedStringKey(title))
            .accessibilityValue(count.formatted())
    }
}
struct RelationshipView: View {
    var kind: String
    @EnvironmentObject private var store: MemberKitchenStore
    var body: some View {
        TatiPage(title: kind, lazyContent: true) {
            let ids = kind == "Following" ? store.followingIDs : kind == "Friends" ? store.mutualIDs : store.followerIDs
            let people = store.visiblePeople.filter { ids.contains($0.id) }
            if people.isEmpty { EmptyContent(title: "No \(kind.lowercased()) yet", detail: "Connections appear here after people choose to follow.") }
            ForEach(people) { person in
                HStack(spacing: 10) {
                    UserProfileLink(userID: person.id) { HStack { Avatar(asset: person.portraitArtwork, size: 38); Text(person.name).font(.tati(size: 14)) } }
                    Spacer()
                    FollowControl(userID: person.id)
                    NavigationLink(destination: ConversationView(person: person)) { SupplementIcon(icon: .comment, size: 22).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Chat with " + person.name)
                }.padding(.horizontal, 12).padding(.vertical, 4).background { Image("outlined-card").resizable() }
            }
        }
    }
}
struct MyVideosView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    var body: some View {
        TatiPage(title: "My videos", lazyContent: true) {
            NavigationLink(destination: PublishVideoView()) { SettingRow(title: "Add a video", asset: "add-video") }
            if store.account.clips.isEmpty { EmptyContent(title: "Your story starts here", detail: "Add a food video to your collection.") }
            ForEach(store.account.clips.filter { !store.isHidden("video:" + $0.id) }) { clip in
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(clip.publicationReviewState == "approved" ? "Published" : "Private · Not published"))
                        .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                    FeedVideoCard(clip: clip)
                }
            }
        }.profileNavigationHost()
    }
}
struct EditProfileView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption) private var foodTileWidth = 86.0
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
    @State private var editingOwner = ""
    @State private var requestingCamera = false
    @State private var cameraRequestID: UUID?
    @State private var cameraReady = false
    @State private var showingCamera = false
    @State private var capturedPhoto: CameraPhotoJPEG?
    @State private var capturedPhotoID: UUID?
    @State private var saving = false
    private var loading: Bool { loadingAvatar || loadingCover || requestingCamera || cameraReady || showingCamera }
    private var ownsEdits: Bool { store.account.signedIn && editingOwner == store.account.profile.id }

    var body: some View {
        TatiEditingForm(title: "Edit profile") {
            profilePhotos
            VStack(alignment: .leading, spacing: 0) {
                profileField("Display name", placeholder: "What should we call you?", text: $name, limit: 32)
                fieldDivider
                profileField("About you", placeholder: "Your favourite food, a little about you…", text: $bio, limit: 200, multiline: true)
                fieldDivider
                profileField("Country / region", placeholder: "Add your country or region (optional)", text: $country)
            }.background(.white, in: RoundedRectangle(cornerRadius: 22))
            VStack(alignment: .leading, spacing: 14) {
                Text("Favourite food").font(.tati(.headline, design: .rounded)).accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: foodTileWidth), spacing: 8)], spacing: 14) {
                    ForEach(Array(TableCommunity.topics.dropFirst()), id: \.self) { value in
                        FoodTopicTile(topic: value, selected: interest == value) { interest = value }
                    }
                }
            }
        } footer: {
            TatiEditingButton(title: saving ? "Saving…" : loading ? "Loading photo…" : "Save changes",
                              enabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !loading && !saving && store.storageFailure == nil) { save() }
        }
        .onAppear {
            guard !loadedProfile else { return }
            loadedProfile = true; editingOwner = store.account.profile.id
            name = store.account.profile.name; bio = store.account.profile.bio
            country = store.account.profile.country == "Not set" ? "" : store.account.profile.country
            interest = store.account.profile.interest
        }
        .task(id: avatarItem) { await loadPhoto(avatarItem, avatar: true) }
        .task(id: coverItem) { await loadPhoto(coverItem, avatar: false) }
        .task(id: cameraRequestID) { @MainActor in
            guard let request = cameraRequestID, ownsEdits else { return }
            requestingCamera = true
            defer {
                requestingCamera = false
                // Consume the request: returning from the full-screen camera must
                // not restart authorization and immediately reopen capture.
                if cameraRequestID == request { cameraRequestID = nil }
            }
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                store.tell("Camera unavailable", "This device has no available camera. Choose a photo from your library instead.")
                return
            }
            let authorization = AVCaptureDevice.authorizationStatus(for: .video)
            if authorization == .denied { cameraAccessNotice(); return }
            if authorization == .restricted {
                store.tell("Camera unavailable", "Camera access is restricted. You can choose a photo from your library instead.")
                return
            }
            let authorized = await AVCaptureDevice.requestAccess(for: .video)
            guard !Task.isCancelled, cameraRequestID == request, ownsEdits else { return }
            if authorized { cameraReady = true; presentCameraIfReady() }
            // A first refusal ends this tap without a follow-up alert.
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { presentCameraIfReady() } }
        .onChange(of: store.account.profile.id) { _, _ in if !ownsEdits { dismiss() } }
        .onChange(of: store.account.signedIn) { _, signedIn in if !signedIn { dismiss() } }
        .fullScreenCover(isPresented: $showingCamera) {
            ProfileStillCamera { image in
                showingCamera = false
                guard let image, ownsEdits else { return }
                capturedPhoto = CameraPhotoJPEG(image)
                capturedPhotoID = UUID()
                loadingAvatar = true
            }.ignoresSafeArea()
        }
        .task(id: capturedPhotoID) { @MainActor in
            guard let id = capturedPhotoID, let capturedPhoto else { return }
            defer {
                if capturedPhotoID == id { self.capturedPhoto = nil; loadingAvatar = false }
            }
            let data = await capturedPhoto.data()
            guard !Task.isCancelled, capturedPhotoID == id, ownsEdits else { return }
            acceptPhoto(data, avatar: true)
        }
    }

    private var fieldDivider: some View {
        Color.tatiOlive.opacity(0.12).frame(height: 1).padding(.horizontal, 18).accessibilityHidden(true)
    }

    private func profileField(_ label: String, placeholder: String, text: Binding<String>, limit: Int? = nil, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(label)).font(.tati(.caption).weight(.semibold)).foregroundStyle(Color.tatiOlive)
                Spacer(minLength: 8)
                if let limit { Text("\(text.wrappedValue.count)/\(limit)").font(.tati(.caption2)).monospacedDigit().foregroundStyle(Color.tatiOlive) }
            }
            TextField(LocalizedStringKey(label), text: text,
                      prompt: Text(LocalizedStringKey(placeholder)).foregroundColor(.tatiOlive.opacity(0.7)), axis: .vertical)
                .font(.tati(.body)).lineLimit(multiline ? 3...6 : 1...3)
                .tint(.tatiPink).accessibilityLabel(LocalizedStringKey(label))
                .onChange(of: text.wrappedValue) { _, value in
                    if let limit, value.count > limit { text.wrappedValue = String(value.prefix(limit)) }
                }
        }.padding(18)
    }

    private var profilePhotos: some View {
        let savedCover = store.account.profile.coverFile
        let savedAvatar = store.account.profile.avatarFile
        return VStack(spacing: 0) {
            PhotosPicker(selection: $coverItem, matching: .images) {
                GeometryReader { geometry in
                    photoPreview(coverData, removeCover ? nil : savedCover, maxPixels: 1200)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: 6) {
                                Art(name: "profile-photo-camera", width: 22, height: 22)
                                Text(LocalizedStringKey(loadingCover ? "Loading…" : "Change cover"))
                                    .font(.tati(.caption).weight(.bold))
                            }.foregroundStyle(Color.tatiCream).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.tatiInk, in: Capsule()).padding(12)
                        }
                }.frame(height: 164)
            }.buttonStyle(.plain).disabled(loading).accessibilityLabel("Change cover photo")
            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 14) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        photoPreview(avatarData, removeAvatar ? nil : savedAvatar, maxPixels: 384)
                            .frame(width: 88, height: 88).clipShape(Circle())
                            .padding(4).background(Color.tatiPink, in: Circle())
                            .overlay(alignment: .bottomTrailing) {
                                Art(name: "profile-photo-camera", width: 28, height: 28)
                                    .padding(4).background(Color.tatiCream, in: Circle())
                            }
                    }.buttonStyle(.plain).disabled(loading).accessibilityLabel("Change profile picture")
                        .padding(.top, -30)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Profile picture").font(.tati(.headline, design: .rounded)).foregroundStyle(Color.tatiCream)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(LocalizedStringKey(loadingAvatar ? "Loading…" : "Tap to change"))
                            .font(.tati(.caption)).foregroundStyle(Color.tatiLime)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { libraryAction; cameraAction }
                    VStack(spacing: 10) { libraryAction; cameraAction }
                }
                if avatarData != nil || (!removeAvatar && savedAvatar != nil) || coverData != nil || (!removeCover && savedCover != nil) {
                    HStack(spacing: 12) {
                        if avatarData != nil || (!removeAvatar && savedAvatar != nil) {
                            Button("Reset profile picture") { avatarData = nil; avatarItem = nil; removeAvatar = true }
                                .frame(minHeight: 44)
                        }
                        Spacer(minLength: 0)
                        if coverData != nil || (!removeCover && savedCover != nil) {
                            Button("Reset cover") { coverData = nil; coverItem = nil; removeCover = true }
                                .frame(minHeight: 44)
                        }
                    }.font(.tati(.caption)).foregroundStyle(Color.tatiCream).buttonStyle(.plain).disabled(loading)
                }
            }.padding(.horizontal, 18).padding(.bottom, 16)
        }.background(Color.tatiInk).clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private var libraryAction: some View {
        PhotosPicker(selection: $avatarItem, matching: .images) {
            sourceLabel("Photo library", asset: "add-photo")
        }.buttonStyle(.plain).disabled(loading)
            .accessibilityLabel("Choose profile photo from library")
    }
    private var cameraAction: some View {
        Button { cameraRequestID = UUID() } label: {
            sourceLabel("Take photo", asset: "profile-photo-camera")
        }.buttonStyle(.plain).disabled(loading)
            .accessibilityLabel("Take profile photo")
    }
    private func sourceLabel(_ title: String, asset: String) -> some View {
        HStack(spacing: 7) {
            Art(name: asset, width: 23, height: 23)
            Text(LocalizedStringKey(title)).font(.tati(.subheadline).weight(.semibold))
                .fixedSize(horizontal: true, vertical: false)
        }.padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(Color.tatiInk).background(Color.tatiCream, in: RoundedRectangle(cornerRadius: 14))
    }

    @MainActor private func loadPhoto(_ item: PhotosPickerItem?, avatar: Bool) async {
        guard let item else { return }
        if avatar { loadingAvatar = true } else { loadingCover = true }
        defer {
            // Clear the selection so choosing the same image again can retry a failed
            // iCloud download or replace a later camera photo. Stale loads own no UI.
            if avatar, avatarItem == item { loadingAvatar = false; avatarItem = nil }
            if !avatar, coverItem == item { loadingCover = false; coverItem = nil }
        }
        do {
            let data = try await item.loadTransferable(type: Data.self)
            guard !Task.isCancelled, ownsEdits else { return }
            acceptPhoto(data, avatar: avatar)
        } catch {
            guard !Task.isCancelled, ownsEdits else { return }
            store.tell("Photo unavailable", "Please choose another photo. Your other edits are still here.")
        }
    }
    private func acceptPhoto(_ data: Data?, avatar: Bool) {
        guard let data, data.count <= 25 * 1024 * 1024, UIImage(data: data) != nil else {
            store.tell("Photo unavailable", "Use a supported image smaller than 25 MB. Your edits have been kept on this screen.")
            return
        }
        if avatar { avatarData = data; removeAvatar = false }
        else { coverData = data; removeCover = false }
    }
    private func presentCameraIfReady() {
        guard cameraReady, scenePhase == .active, ownsEdits else { return }
        cameraReady = false
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        showingCamera = true
    }
    private func cameraAccessNotice() {
        store.confirm("Camera unavailable", "Camera access is off. You can choose a photo from your library, or review access in Settings.", button: "Open Settings") {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    }

    @ViewBuilder private func photoPreview(_ data: Data?, _ file: String?, maxPixels: Int) -> some View {
        if let data { PreparedDataPhoto(data: data, maxPixels: maxPixels) }
        else if let file { PreparedPhoto(source: .file(store.mediaURL(file)), fallbackAsset: ProfileArtwork.defaultPortrait) }
        else { PreparedPhoto(source: .asset(ProfileArtwork.defaultPortrait)) }
    }
    private func save() {
        guard ownsEdits, !saving, !loading, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard store.permitsCommunityText(name + " " + bio + " " + country) else { return }
        saving = true; defer { saving = false }
        var newFiles: [String] = []
        do {
            var profile = store.account.profile
            let old = [profile.avatarFile, profile.coverFile].compactMap { $0 }
            profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); profile.bio = bio; profile.interest = interest
            let region = country.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.country = region.isEmpty ? "Not set" : region
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
            Art(name: "discovery-messages", width: 37, height: 37)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Messages")
    }
}

private struct MessagesProfileEntry: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        NavigationLink(destination: ConversationsView()) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Messages").font(.tati(.title2, design: .rounded).weight(.heavy))
                    Text("Your conversations, all together.")
                        .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text("Open messages").font(.tati(.caption).weight(.bold))
                        Art(name: "chevron", width: 8, height: 12)
                    }.padding(.top, 4)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    Art(name: "discovery-messages", width: 84, height: 84)
                }
            }.padding(.leading, 20).padding(.trailing, 14).padding(.vertical, 18)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                .foregroundStyle(Color.tatiInk)
                .background(Color(red: 1, green: 0.88, blue: 0.78), in: RoundedRectangle(cornerRadius: 24))
                .contentShape(RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Messages")
            .accessibilityHint("Open messages")
    }
}

struct ConversationsView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var query = ""
    @State private var draftsOnly = false
    @FocusState private var searching: Bool
    private var people: [TableMember] {
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
                    Text("A little hello.").font(.tati(.largeTitle).weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Good food brings us together. Keep the conversation going.")
                        .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "support-mascot", width: 62, height: 76)
            }
            NavigationLink(destination: RelationshipView(kind: "Following")) {
                HStack(spacing: 10) {
                    Text("Start a conversation").font(.tati(.subheadline).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Art(name: "chevron", width: 10, height: 14)
                }.padding(.horizontal, 16).padding(.vertical, 13)
                    .frame(minHeight: 48)
                    .background(Color.tatiPink.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain)
            Text("Messages and calls open when you follow each other.")
                .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var searchField: some View {
        HStack(spacing: 10) {
            Art(name: "search", width: 22, height: 26)
            TextField("Search conversations", text: $query)
                .font(.tati(.subheadline)).focused($searching).submitLabel(.search)
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
            Text(LocalizedStringKey(title)).font(.tati(.subheadline).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15).padding(.vertical, 12).frame(minHeight: 44)
                .foregroundStyle(selected ? Color.tatiCream : Color.tatiOlive)
                .background(selected ? Color.tatiInk : Color.white.opacity(0.65), in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(store.conversationPeople.isEmpty ? "Your next hello starts here" : "No matching conversations"))
                .font(.tati(.title3).weight(.bold))
            Text(LocalizedStringKey(store.conversationPeople.isEmpty
                 ? "Open a profile to write a message. Your drafts will wait here for you."
                 : "Try another name or switch back to all conversations."))
                .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
            if !store.conversationPeople.isEmpty {
                Button("Show all conversations") { query = ""; draftsOnly = false }
                    .font(.tati(.subheadline).weight(.semibold)).frame(minHeight: 44).buttonStyle(.plain)
            }
        }.fixedSize(horizontal: false, vertical: true)
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 22))
    }
    private func conversationRow(_ person: TableMember) -> some View {
        let draft = store.hasConversationDraft(with: person.id)
        let latest = store.latestMessage(with: person.id)
        return HStack(alignment: .top, spacing: 12) {
            UserProfileLink(userID: person.id) { Avatar(asset: person.portraitArtwork, size: 52) }
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    UserProfileLink(userID: person.id) {
                        Text(person.name).font(.tati(.headline)).lineLimit(2).frame(minHeight: 44, alignment: .leading)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if draft {
                        Text("Draft").font(.tati(.caption).weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.tatiPink.opacity(0.2), in: Capsule())
                    } else if let latest {
                        Text(latest.createdAt, format: .dateTime.month(.abbreviated).day())
                            .font(.tati(.caption2)).foregroundStyle(Color.tatiOlive)
                    }
                }
                NavigationLink(destination: ConversationView(person: person)) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            preview(person, draft: draft, latest: latest)
                                .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive).lineLimit(2)
                            if !draft, let latest,
                               latest.senderID == nil || latest.senderID == store.account.profile.id {
                                Text(LocalizedStringKey(latest.status)).font(.tati(.caption2))
                                    .foregroundStyle(Color.tatiOlive)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Art(name: "chevron", width: 9, height: 13)
                    }.frame(minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityHint("Open conversation")
            }
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
    private func preview(_ person: TableMember, draft: Bool, latest: ConversationOutboxItem?) -> Text {
        if draft {
            let text = (store.account.drafts[person.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? Text("Photo attachment") : Text(verbatim: text)
        }
        if let latest, !latest.text.isEmpty { return Text(verbatim: latest.text) }
        return Text("Photo attachment")
    }
}

private enum ConversationCallKind: String, Identifiable {
    case voice, video
    var id: String { rawValue }
    var title: String { self == .voice ? "Voice call" : "Video call" }
}

/// Crop either object from the original two-cell raster atlas.
private struct ConversationCallArt: View {
    var kind: ConversationCallKind
    var side: CGFloat = 40
    var body: some View {
        Image("conversation-call-icons").resizable()
            .frame(width: side * 2, height: side)
            .offset(x: kind == .voice ? 0 : -side)
            .frame(width: side, height: side, alignment: .topLeading).clipped()
            .accessibilityHidden(true)
    }
}

struct ConversationView: View {
    var person: TableMember
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var text = ""
    @State private var call: ConversationCallKind?
    @State private var showSafety = false
    @State private var reportedMessage: ConversationOutboxItem?
    @FocusState private var inputFocused: Bool
    private var messages: [ConversationOutboxItem] { store.messages(with: person.id) }
    private var canSend: Bool { store.account.signedIn && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.storageFailure == nil }
    private let paper = Color(red: 1, green: 0.96, blue: 0.90)

    var body: some View {
        VStack(spacing: 0) {
            conversationHeader
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if messages.isEmpty { invitation }
                        ForEach(messages) { message in
                            messageRow(message).id(message.id)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 24)
                    .frame(maxWidth: 680).frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { if let id = messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
                .onChange(of: messages.map(\.id)) { oldIDs, ids in
                    if let id = ids.last, !oldIDs.contains(id) { proxy.scrollTo(id, anchor: .bottom) }
                }
                .onChange(of: inputFocused) { _, focused in
                    if focused, let id = messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            composer
        }
        .background { paper.ignoresSafeArea(.container) }
        .foregroundStyle(Color.tatiInk).tatiScreen()
        .onAppear { text = store.account.drafts[person.id] ?? ""; if store.isPersonHidden(person.id) { dismiss() } }
        .onDisappear { store.flushDraft(person.id) }
        .onChange(of: store.account.blocked) { _, _ in if store.isPersonHidden(person.id) { dismiss() } }
        .onChange(of: store.account.hiddenSubjects) { _, _ in if store.isPersonHidden(person.id) { dismiss() } }
        .onChange(of: store.account.profile.id) { _, _ in dismiss() }
        .onChange(of: store.account.signedIn) { _, signedIn in if !signedIn { dismiss() } }
        .sheet(isPresented: $showSafety) { SafetyActionsView(subjectID: "person:" + person.id, authorID: person.id) }
        .sheet(item: $reportedMessage) { message in
            SafetyActionsView(subjectID: "message:" + message.id, authorID: person.id, contextID: person.id)
        }
        .fullScreenCover(item: $call) { kind in
            Group {
                if kind == .video { VideoCallView(person: person) }
                else { VoiceCallView(person: person) }
            }.overlay { NoticeLayer() }
        }
    }

    private var conversationHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ArtButton(asset: "back", label: "Back", size: 22) { dismiss() }
                UserProfileLink(userID: person.id) {
                    HStack(spacing: 10) {
                        Avatar(asset: person.portraitArtwork, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name).font(.tati(.headline)).lineLimit(2)
                            Text(LocalizedStringKey(person.interest)).font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                                .lineLimit(2)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                ArtButton(asset: "more", label: "Report or block", size: 22) { showSafety = true }
            }
            if !inputFocused || !typeSize.isAccessibilitySize {
                Group {
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 10) { callButton(.voice); callButton(.video) }
                    } else {
                        HStack(spacing: 12) { callButton(.voice); callButton(.video) }
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 18)
        .frame(maxWidth: 680).frame(maxWidth: .infinity)
        .background { Color(red: 1, green: 0.91, blue: 0.82).ignoresSafeArea(.container, edges: .top) }
    }

    private func callButton(_ kind: ConversationCallKind) -> some View {
        Button {
            inputFocused = false
            store.flushDraft(person.id)
            if store.requireMutualFollow(person.id) { call = kind }
        } label: {
            HStack(spacing: 8) {
                ConversationCallArt(kind: kind)
                Text(LocalizedStringKey(kind.title)).font(.tati(.subheadline).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(kind == .voice ? Color.tatiCream : Color.tatiInk)
            .background(kind == .voice ? Color.tatiInk : Color.tatiPink, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityLabel(LocalizedStringKey(kind.title))
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 18) {
            Art(name: "discovery-messages", width: 84, height: 74)
            Text("Good conversations start with hello.")
                .font(.tati(.title2, design: .serif, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(store.canCommunicate(with: person.id)
                 ? "Write your first message below." : "Follow each other to chat and call."))
                .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8).padding(.top, 16).padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageRow(_ message: ConversationOutboxItem) -> some View {
        let mine = message.senderID == nil || message.senderID == store.account.profile.id
        return HStack(alignment: .top, spacing: 8) {
            if mine { Spacer(minLength: 32) }
            else { UserProfileLink(userID: person.id) { Avatar(asset: person.portraitArtwork, size: 32) } }
            VStack(alignment: mine ? .trailing : .leading, spacing: 7) {
                VStack(alignment: .leading, spacing: 8) {
                    // Existing photo messages remain readable; this composer only sends text.
                    if let file = message.imageFile {
                        PreparedPhoto(source: .file(store.mediaURL(file)), fills: false)
                            .frame(maxWidth: 220).frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !message.text.isEmpty {
                        Text(message.text).font(.tati(.body)).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    }
                }
                .padding(14).foregroundStyle(mine ? Color.tatiCream : Color.tatiInk)
                .background(mine ? Color.tatiInk : Color.white,
                            in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: mine ? 18 : 5,
                                                       bottomTrailingRadius: mine ? 5 : 18, topTrailingRadius: 18))
                HStack(spacing: 8) {
                    Text(message.createdAt, style: .time)
                    if mine { Text(LocalizedStringKey(message.status)) }
                }.font(.tati(.caption2)).foregroundStyle(Color.tatiOlive)
            }
            if !mine {
                ArtButton(asset: "more", label: "Report message", size: 18) { reportedMessage = message }
                Spacer(minLength: 0)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $text, prompt: Text("Write a message…").foregroundStyle(Color.tatiOlive), axis: .vertical)
                .lineLimit(1...(typeSize.isAccessibilitySize ? 2 : 5)).font(.tati(.body)).focused($inputFocused)
                .padding(.horizontal, 16).padding(.vertical, 16)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityLabel("Message")
                .onChange(of: text) { _, value in
                    let limited = String(value.prefix(2000))
                    if limited != value { text = limited }
                    store.scheduleDraft(person.id, text: limited)
                }
            Button {
                guard canSend else { return }
                if store.attemptMessage(to: person.id, text: text) { text = "" }
            } label: {
                SupplementIcon(icon: .send, size: 24, tint: .tatiCream)
                    .frame(width: 54, height: 54)
                    .background(canSend ? Color.tatiInk : Color.tatiOlive.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(.plain).disabled(!canSend).accessibilityLabel("Send message")
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
        .frame(maxWidth: 680).frame(maxWidth: .infinity)
        .background { Color(red: 1, green: 0.91, blue: 0.82).ignoresSafeArea(.container, edges: .bottom) }
    }
}

struct VoiceCallView: View {
    var person: TableMember
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            TatiPage(title: "Voice call", scrolling: true) {
                VStack(spacing: 22) {
                    ConversationCallArt(kind: .voice, side: 136)
                    Avatar(asset: person.portraitArtwork, size: 104)
                    Text(person.name).font(.tati(.title, design: .serif, weight: .bold))
                    Text("Voice calls are unavailable. No microphone access is needed.")
                        .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    TatiButton(title: "Close", secondary: true) { dismiss() }
                }.padding(.vertical, 20)
            }
        }
    }
}

struct VideoCallView: View {
    var person: TableMember
    @EnvironmentObject private var store: MemberKitchenStore
    @EnvironmentObject private var playback: FoodFilmPlayback
    @EnvironmentObject private var roomSession: CookingRoomSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = KitchenCameraController()
    @State private var cameraTask: Task<Void, Never>?
    @State private var ownerID: String?
    var body: some View {
        NavigationStack {
            TatiPage(title: "Video call", scrolling: false) {
                VStack(spacing: 16) {
                    UserProfileLink(userID: person.id) {
                        HStack { Avatar(asset: person.portraitArtwork, size: 44); Text(person.name).font(.tati(.headline)) }
                    }
                    GeometryReader { geometry in
                        ZStack {
                            Color.black
                            if camera.ready { CameraSurface(session: camera.session) }
                            else { Text(LocalizedStringKey(camera.status)).font(.tati(.subheadline)).foregroundStyle(.white).multilineTextAlignment(.center).padding(24) }
                        }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    }.clipShape(RoundedRectangle(cornerRadius: 20))
                    Text("Your camera is not shared. Video calls are unavailable.").font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                    if !camera.ready {
                        TatiButton(title: camera.starting ? "Starting camera…" : "Enable camera", secondary: true, enabled: !camera.starting) { startCamera() }
                    }
                    TatiButton(title: "Close") { cameraTask?.cancel(); camera.stop(); dismiss() }
                }
            }
        }
        .onAppear { ownerID = store.account.profile.id }
        .onDisappear { cameraTask?.cancel(); camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            // Permission sheets temporarily make the scene inactive. Keep their
            // request alive; only backgrounding should cancel camera startup.
            if phase == .background { cameraTask?.cancel(); camera.stop() }
        }
        .onChange(of: store.account.following) { _, _ in checkPermission() }
        .onChange(of: store.account.followers) { _, _ in checkPermission() }
        .onChange(of: store.account.blocked) { _, _ in checkPermission() }
        .onChange(of: store.account.hiddenSubjects) { _, _ in checkPermission() }
        .onChange(of: store.account.profile.id) { _, _ in checkPermission() }
        .onChange(of: store.account.signedIn) { _, _ in checkPermission() }
    }
    private func checkPermission() {
        if ownerID != store.account.profile.id || !store.canCommunicate(with: person.id) { cameraTask?.cancel(); camera.stop(); dismiss() }
    }
    private func startCamera() {
        guard ownerID == store.account.profile.id, store.requireMutualFollow(person.id) else { dismiss(); return }
        playback.stop(); roomSession.audio.stop()
        cameraTask?.cancel()
        cameraTask = Task {
            let outcome = await camera.start()
            guard !Task.isCancelled, ownerID == store.account.profile.id else { return }
            if outcome == .declined { dismiss() }
            else { store.explainCameraAvailability(outcome) }
        }
    }
}

struct CookingNotesView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var question = ""
    @FocusState private var questionFocused: Bool
    private var exchanges: [CookingQuestionExchange] { store.account.foodExpertExchanges ?? [] }
    private var pending: CookingQuestionExchange? { exchanges.first { $0.reply == nil } }
    private var canAsk: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && pending == nil && store.storageFailure == nil
    }
    private var replyTaskID: String {
        "\(store.account.profile.id):\(pending?.id ?? ""):\(scenePhase == .active)"
    }
    private var scrollUpdate: String {
        guard let last = exchanges.last else { return "" }
        return last.id + (last.reply?.rawValue ?? "pending")
    }
    private let prompts = [
        (title: "Make it crispy", question: "How to get crispy fried food?"),
        (title: "Plate it beautifully", question: "How to make food look delicious?"),
        (title: "Find the perfect balance", question: "How to balance sweet and savory taste?")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        KitchenNotebookEntry()
                        introduction
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text("A little inspiration").font(.tati(.headline))
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
                        ForEach(exchanges) { exchange in
                            conversation(exchange)
                        }
                        Color.clear.frame(height: 1).id("expert-bottom")
                    }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 20)
                        .frame(maxWidth: 680).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: scrollUpdate, initial: true) { _, value in
                        if !value.isEmpty { proxy.scrollTo("expert-bottom", anchor: .bottom) }
                    }
            }
            composer
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Color.tatiCream.ignoresSafeArea(.container) }
            .foregroundStyle(Color.tatiInk)
            .onAppear { question = store.account.drafts["food-expert"] ?? "" }
            .onChange(of: question) { _, text in
                if text.count > 1200 { question = String(text.prefix(1200)); return }
                store.scheduleDraft("food-expert", text: text)
            }
            .onDisappear { store.flushDraft("food-expert") }
            .task(id: replyTaskID) { @MainActor in
                guard scenePhase == .active, let pending, store.storageFailure == nil else { return }
                let owner = store.account.profile.id
                let delay = 1050 + min(500, pending.question.count * 7)
                do { try await Task.sleep(for: .milliseconds(delay)) }
                catch { return }
                guard !Task.isCancelled, scenePhase == .active else { return }
                store.finishFoodExpertReply(pending.id, owner: owner)
            }

    }

    private var introduction: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Art(name: "brand-heading", width: 112, height: 38, alignment: .leading)
                Text("What's cooking?").font(.tati(.title2).weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Food & flavour with Yimeng.")
                    .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Cooking notes").font(.tati(.caption).weight(.medium))
                    .foregroundStyle(Color.tatiOlive)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Art(name: "chef", width: 100, height: 142, alignment: .bottom)
        }.padding(16).frame(maxWidth: .infinity, minHeight: 172)
            .background {
                GeometryReader { geometry in
                    Image("page-background").resizable()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(0.55)
                }.accessibilityHidden(true).allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func promptRow(_ index: Int) -> some View {
        let prompt = prompts[index]
        return Button {
            ask(AppLanguage.preference(store.account.preferredLanguage).text(prompt.question))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(prompt.title)).font(.tati(.subheadline).weight(.semibold))
                    Text(LocalizedStringKey(prompt.question)).font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "chevron", width: 8, height: 12)
            }.padding(16).frame(minHeight: 64).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(prompt.question)
            .disabled(pending != nil || store.storageFailure != nil)
            .accessibilityHint("Ask Yimeng")
    }

    private func ask(_ text: String) {
        guard pending == nil, store.askFoodExpert(text) else { return }
        question = ""
        questionFocused = false
    }

    private func conversation(_ exchange: CookingQuestionExchange) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Spacer(minLength: 32)
                Text(exchange.question).font(.tati(.body))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14).background(Color.tatiPink, in: RoundedRectangle(cornerRadius: 18))
                Avatar(file: store.account.profile.avatarFile, size: 32, isCurrent: true)
            }
            HStack(alignment: .top, spacing: 10) {
                Art(name: "chef-avatar", width: 32, height: 38)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yimeng").font(.tati(.caption).weight(.bold)).foregroundStyle(Color.tatiOlive)
                    if let reply = exchange.reply {
                        Text(LocalizedStringKey(reply.answer)).font(.tati(.body))
                            .fixedSize(horizontal: false, vertical: true)
                    } else if store.storageFailure != nil {
                        Text("Your question is saved. Reopen Tati to finish the reply.")
                            .font(.tati(.subheadline)).fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(spacing: 8) {
                            Art(name: "notes-on", width: 20, height: 20)
                                .phaseAnimator(scenePhase == .active && !reduceMotion ? [0.6, 1.0] : [1.0]) { icon, opacity in
                                    icon.opacity(opacity)
                                } animation: { _ in .easeInOut(duration: 0.65) }
                            Text("Preparing a cooking tip…").font(.tati(.subheadline))
                                .fixedSize(horizontal: false, vertical: true)
                        }.accessibilityElement(children: .combine)
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                Spacer(minLength: 12)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about food", text: $question,
                      prompt: Text("What's on your mind?").foregroundColor(.tatiOlive), axis: .vertical)
                .lineLimit(1...4).font(.tati(.body)).tint(.tatiOlive)
                .focused($questionFocused)
                .padding(.leading, 6).padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Your food question")
            Button { ask(question) } label: {
                Art(name: "cooking-question-send", width: 46, height: 46)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                    .opacity(canAsk ? 1 : 0.4)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: canAsk)
            }.buttonStyle(CookingQuestionSendStyle()).disabled(!canAsk)
                .accessibilityLabel(LocalizedStringKey(pending == nil ? "Ask Yimeng" : "Preparing a cooking tip…"))
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

private struct CookingQuestionSendStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
