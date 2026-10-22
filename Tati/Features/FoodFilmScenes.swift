import SwiftUI
import PhotosUI
import AVFoundation

struct VideoFeedView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Art(name: "video-heading", width: 144, height: 62)
                        Spacer(minLength: 0)
                        saveVideoEntry
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Art(name: "video-heading", width: 144, height: 62)
                        saveVideoEntry
                    }
                }
                if KitchenEditorialLibrary.unavailable { Note(text: "Content could not be loaded.") }
                ForEach(store.visibleClips) { clip in FeedVideoCard(clip: clip) }
                if store.visibleClips.isEmpty { EmptyContent(title: "A little taste of your world", detail: "Add a food video to your collection.") }
            }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.profileNavigationHost()
    }

    private var saveVideoEntry: some View {
        NavigationLink(destination: PublishVideoView()) {
            HStack(spacing: 8) {
                Art(name: "discovery-live-camera", width: 34, height: 34)
                Text("Save video").font(.tati(.subheadline).weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 8).padding(.trailing, 14).padding(.vertical, 6)
            .frame(minHeight: 48)
            .foregroundStyle(Color.tatiInk)
            .background(Color.tatiPink, in: Capsule())
        }.buttonStyle(FoodFilmPressStyle())
            .accessibilityLabel("Save video")
    }
}
struct ClipDetailView: View {
    var clip: FoodFilm
    @EnvironmentObject private var store: MemberKitchenStore
    @EnvironmentObject private var playback: FoodFilmPlayback
    @EnvironmentObject private var roomSession: CookingRoomSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var showComments = false
    @State private var pendingProfile: TableMember?
    @State private var profilePage: TableMember?
    @State private var showReport = false
    @State private var failure: String?
    @State private var playbackOwner = UUID().uuidString
    @State private var isVisible = false
    private var showsVideo: Bool {
        playback.activeID == clip.id && playback.ownerID == playbackOwner && playback.failure == nil
    }
    var body: some View {
        MediaViewport {
            GeometryReader { geometry in
                ZStack {
                    VStack {
                        HStack {
                            ArtButton(asset: "back", label: "Back") { dismiss() }
                            Spacer()
                            if clip.authorID == store.account.profile.id {
                                ArtButton(asset: "remove", label: "Delete video") { delete() }
                            } else { ArtButton(asset: "more", label: "Video options: report or block") { showReport = true } }
                        }
                        Spacer()
                        ViewThatFits(in: .vertical) {
                            videoInformation.fixedSize(horizontal: false, vertical: true)
                            ScrollView { videoInformation }
                                .scrollIndicators(.hidden)
                        }
                        .frame(maxHeight: min(230, geometry.size.height * 0.42), alignment: .bottom)
                        .padding(.top, 12).padding(.bottom, 12)

                    }.padding(.horizontal, 14).foregroundStyle(showsVideo ? Color.white : Color.tatiInk)
                }
                .overlay {
                    if playback.activeID == clip.id, playback.ownerID == playbackOwner, playback.failure == nil {
                        VStack(spacing: 8) {
                            Button { playback.toggle() } label: {
                                SupplementIcon(icon: playback.wantsToPlay ? .pause : .play, size: 32, tint: .white)
                                    .frame(width: 54, height: 54).background(.black.opacity(0.3)).clipShape(Circle())
                            }.buttonStyle(.plain).accessibilityLabel(playback.wantsToPlay ? "Pause video" : "Play video")
                            if playback.loading { Text("Loading…").font(.tati(.caption)).foregroundStyle(.white) }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Art(name: "media-placeholder", width: 78)
                            Text(playback.failure ?? failure ?? "The video could not be loaded.").font(.tati(.headline)).multilineTextAlignment(.center)
                            TatiButton(title: "Retry") { preparePlayback() }.frame(width: 150)
                        }.padding(25).foregroundStyle(Color.tatiInk)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .background {
            GeometryReader { geometry in
                if let player = playback.player, playback.activeID == clip.id, playback.ownerID == playbackOwner, playback.failure == nil {
                    ClipSurface(player: player, fillsContainer: true).background(Color.black)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(alignment: .bottom) {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.42), location: 0.4),
                                .init(color: .black.opacity(0.78), location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                            .frame(height: min(320, geometry.size.height * 0.42))
                        }
                        .allowsHitTesting(false)
                } else {
                    Color.tatiCream
                }
            }.ignoresSafeArea(.container)
        }
        .tatiScreen()
        .onAppear { isVisible = true; preparePlayback() }
        .onDisappear { isVisible = false; if playback.ownerID == playbackOwner { playback.stop() } }
        .onChange(of: scenePhase) { _, value in
            if value != .active { if playback.ownerID == playbackOwner { playback.stop() } }
            else if isVisible { preparePlayback() }
        }
        .navigationDestination(item: $profilePage) { PersonProfileView(person: $0) }
        .sheet(isPresented: $showComments, onDismiss: {
            if let person = pendingProfile {
                pendingProfile = nil
                if !store.isPersonHidden(person.id) { profilePage = person }
            }
        }) { NavigationStack { CommentDraftView(clip: clip) }.overlay { NoticeLayer() }.presentationDetents([.medium, .large])
                .environment(\.profileSheetAction, { person in
                    pendingProfile = person
                    showComments = false
                }) }
        .sheet(isPresented: $showReport) { VideoOptionsView(clip: clip) }
        .onChange(of: showReport) { _, presented in
            if !presented && (store.isPersonHidden(clip.authorID) || store.isHidden("video:" + clip.id)) { dismiss() }
        }
        .onChange(of: store.account.hiddenSubjects) { _, _ in closeIfHidden() }
        .onChange(of: store.account.blocked) { _, _ in closeIfHidden() }
    }
    private var videoInformation: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    VideoAuthor(clip: clip, size: 38)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 4)
                    VideoEngagementActions(clip: clip, tint: showsVideo ? .white : .tatiInk) { showComments = true }
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    VideoAuthor(clip: clip, size: 38)
                    VideoEngagementActions(clip: clip, tint: showsVideo ? .white : .tatiInk) { showComments = true }
                }
            }
            Text(clip.dishCaption).font(.tati(.subheadline))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !store.isClipVisible(clip) {
                Text("Private · Not published").font(.tati(.caption))
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func closeIfHidden() {
        if store.isPersonHidden(clip.authorID) || store.isHidden("video:" + clip.id) {
            if playback.ownerID == playbackOwner { playback.stop() }
            dismiss()
        }
    }
    private func preparePlayback() {
        guard !store.isPersonHidden(clip.authorID), !store.isHidden("video:" + clip.id) else { closeIfHidden(); return }
        failure = nil
        roomSession.audio.stop()
        guard let url = store.videoURL(for: clip) else { failure = "The video file could not be found."; return }
        do { try playback.load(id: clip.id, url: url, owner: playbackOwner, loops: true) }
        catch { failure = clip.packagedMovieName != nil ? "This video is unavailable." : "This video file is missing. Reimport it from your library." }
    }
    private func delete() {
        store.confirm("Delete video?", "This removes the imported copy from Tati. The original in Photos is unchanged.", button: "Delete", destructive: true) {
            playback.stop()
            if store.change({ $0.clips.removeAll { $0.id == clip.id }; $0.likes.remove(clip.id); $0.videoComments?.removeAll { $0.clipID == clip.id } }) {
                if let file = clip.recordedMovieFile { store.removeUnusedMedia(file) }
                dismiss()
            }
        }
    }
}
struct CommentDraftView: View {
    var clip: FoodFilm
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedComment: FilmDiscussionReply?
    private var comments: [FilmDiscussionReply] { store.comments(for: clip) }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Comments · \(comments.count)").font(.tati(size: 18, weight: .bold, design: .serif))
                Spacer()
                ArtButton(asset: "close-light", label: "Close comments") { dismiss() }
            }.padding(.horizontal, 18).padding(.top, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if comments.isEmpty {
                            Text("Be the first to comment.").font(.tati(size: 13)).foregroundStyle(Color.tatiOlive)
                                .padding(.vertical, 24)
                        }
                        ForEach(comments) { comment in
                            let current = comment.authorID == store.account.profile.id
                            let person = TableCommunity.person(comment.authorID)
                            HStack(alignment: .top, spacing: 10) {
                                UserProfileLink(userID: comment.authorID) {
                                    Avatar(file: current ? store.account.profile.avatarFile : nil, asset: person?.portraitArtwork, size: 38, isCurrent: current)
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    UserProfileLink(userID: comment.authorID) {
                                        Text(current ? store.account.profile.name : person?.name ?? "Creator").font(.tati(size: 14, weight: .medium))
                                    }
                                    Text(comment.text).font(.tati(size: 13)).fixedSize(horizontal: false, vertical: true)
                                    if comment.isCurated != true {
                                        Text(comment.createdAt, style: .relative).font(.tati(.caption2)).foregroundStyle(Color.tatiOlive)
                                    }
                                    if !current {
                                        Button { selectedComment = comment } label: {
                                            HStack(spacing: 6) {
                                                Art(name: "more", width: 16, height: 16)
                                                Text("Report / block").font(.tati(.caption).weight(.medium))
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .foregroundStyle(Color.tatiOlive)
                                            .frame(minHeight: 44, alignment: .leading)
                                            .contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                            .accessibilityLabel("Report comment or block author")
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if current {
                                    ArtButton(asset: "remove", label: "Delete comment", size: 16) {
                                        store.confirm("Delete comment?", "This comment will be removed.", button: "Delete", destructive: true) { store.removeComment(comment.id) }
                                    }
                                }
                            }.id(comment.id)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                }
                .onChange(of: comments.map(\.id)) { previousIDs, ids in
                    // Removing a reported comment or blocking its author must
                    // keep the reader's position, rather than jumping to the end.
                    if let last = ids.last, !previousIDs.contains(last) {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            HStack(spacing: 6) {
                TextField("Tell me your opinion…", text: $text, axis: .vertical).lineLimit(1...4)
                    .font(.tati(size: 13)).padding(.leading, 14).tint(.white)
                    .onChange(of: text) { _, value in text = String(value.prefix(500)) }
                Button {
                    if store.addComment(to: clip, text: text) { text = "" }
                } label: {
                    Text("Send").font(.tati(size: 13, weight: .semibold)).foregroundStyle(Color.tatiInk)
                        .padding(.horizontal, 16).padding(.vertical, 9).background(Color.tatiLime)
                        .clipShape(Capsule()).frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("Add comment")
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(.horizontal, 5).padding(.vertical, 4).background(Color.tatiPink)
                .clipShape(RoundedRectangle(cornerRadius: 22)).padding(16)
        }.background(Color.tatiCream).foregroundStyle(Color.tatiInk)
            .presentationBackground(Color.tatiCream).presentationCornerRadius(20).presentationDragIndicator(.hidden)
            .tatiScreen()
            .sheet(item: $selectedComment) { comment in
                SafetyActionsView(subjectID: "comment:" + comment.id, authorID: comment.authorID, contextID: clip.id)
            }
            .onAppear {
                text = store.account.drafts["comment:" + clip.id] ?? ""
                if !store.isClipVisible(clip) { dismiss() }
            }
            .onChange(of: store.account.hiddenSubjects) { _, _ in if !store.isClipVisible(clip) { dismiss() } }
            .onChange(of: store.account.blocked) { _, _ in if !store.isClipVisible(clip) { dismiss() } }
            .onDisappear { if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { _ = store.saveDraft("comment:" + clip.id, text: text) } }
    }
}

private enum PublishDestination: Hashable { case live, video }

struct PublishSheet: View {
    @State private var path: [PublishDestination] = []
    var body: some View {
        NavigationStack(path: $path) {
            PublishChooser()
                .navigationDestination(for: PublishDestination.self) { destination in
                    switch destination {
                    case .live: GoLiveView()
                    case .video: PublishVideoView()
                    }
                }
        }
        .overlay { NoticeLayer() }
        // A form must not inherit the 210-point chooser height after navigation.
        .presentationDetents(path.isEmpty ? [.height(210), .large] : [.large])
        .presentationDragIndicator(.hidden)
    }
}

private struct PublishChooser: View {
    var body: some View {
        TatiPanel(title: "Create") {
            HStack(spacing: 14) {
                NavigationLink(value: PublishDestination.live) { Art(name: "go-live", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Go live")
                NavigationLink(value: PublishDestination.video) { Art(name: "post-video", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Save video")
            }
        }
    }
}
struct PublishVideoView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var showLibrary = false
    @State private var selection: PhotosPickerItem?
    @State private var localFile: String?
    @State private var mediaDetails = ""
    @State private var caption = ""
    @State private var importing = false
    @State private var committed = false
    @FocusState private var captionFocused: Bool

    private var canPost: Bool {
        localFile != nil && !importing && !committed && store.account.signedIn &&
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var footerHint: String {
        if importing { return "Adding your video…" }
        if localFile == nil { return "Choose a video to continue." }
        if caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Add a caption to finish your post." }
        return "Videos stay private; publishing is unavailable."
    }

    var body: some View {
        TatiEditingForm(title: "Prepare a video") {
            VStack(alignment: .trailing, spacing: 0) {
                Button {
                    captionFocused = false
                    showLibrary = true
                } label: {
                    PublisherMediaCard(url: localFile.map { store.mediaURL($0) }, details: mediaDetails, importing: importing)
                }
                .buttonStyle(.plain).disabled(importing || committed)
                .accessibilityLabel(Text(LocalizedStringKey(localFile == nil ? "Choose a video" : "Change video")))
                .accessibilityValue(importing ? Text("Adding your video…") : Text(verbatim: mediaDetails))
                if localFile != nil {
                    Button(role: .destructive) { removeVideo() } label: {
                        Text("Remove video").font(.tati(.subheadline).weight(.semibold))
                            .foregroundStyle(Color.tatiInk).underline()
                            .frame(minHeight: 44)
                    }.buttonStyle(.plain).disabled(importing || committed)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tell the story").font(.tati(.title3).weight(.bold)).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 12)
                    Text(verbatim: "\(caption.count)/50")
                        .font(.tati(.caption).weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Color.tatiInk)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(caption.count == 50 ? Color.tatiPink : Color.tatiLime, in: Capsule())
                        .accessibilityLabel("Caption")
                        .accessibilityValue("\(caption.count) / 50")
                }
                TextField("Caption", text: $caption, prompt: Text("What's the story behind this bite?").foregroundStyle(Color.tatiOlive), axis: .vertical)
                    .font(.tati(.body)).lineSpacing(5).lineLimit(3...5)
                    .focused($captionFocused)
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(captionFocused ? Color.tatiOlive : Color.clear, lineWidth: 1.5) }
                    .accessibilityLabel("Caption")
                    .onChange(of: caption) { _, value in
                        if value.count > 50 { caption = String(value.prefix(50)) }
                    }

            }
        } footer: {
            VStack(spacing: 10) {
                Text(LocalizedStringKey(footerHint))
                    .font(.tati(.footnote)).foregroundStyle(Color.tatiOlive)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                TatiEditingButton(title: "Save video", enabled: canPost) { post() }
            }
        }
        .photosPicker(isPresented: $showLibrary, selection: $selection, matching: .videos)
        .task(id: selection) { await importSelection() }
        .onChange(of: store.account.profile.id) { _, _ in dismiss() }
        .onChange(of: store.account.signedIn) { _, signedIn in if !signedIn { dismiss() } }
        .onDisappear { if !committed { removeVideo() } }
    }

    private func post() {
        guard canPost, let localFile else { return }
        captionFocused = false
        let clip = FoodFilm(id: UUID().uuidString, authorID: store.account.profile.id,
                            dishCaption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                            recordedMovieFile: localFile, createdAt: Date(), isEditorial: false)
        if store.submitPost(clip) {
            committed = true
            dismiss()
            store.celebrate("Saved privately", "Your video is private. Publishing is unavailable, so it has not been shared.", artwork: "chef")
        }
    }

    private func removeVideo() {
        if let localFile { store.removeUnusedMedia(localFile) }
        localFile = nil
        mediaDetails = ""
    }

    @MainActor private func importSelection() async {
        guard let selection else { return }
        let owner = store.account.profile.id
        importing = true
        defer {
            importing = false
            // Permit selecting the same library item again after removal or a failed import.
            if self.selection == selection { self.selection = nil }
        }
        do {
            guard let movie = try await selection.loadTransferable(type: ImportedMovie.self) else { throw CocoaError(.fileReadUnknown) }
            defer { try? FileManager.default.removeItem(at: movie.url) }
            try Task.checkCancellation()
            guard owner == store.account.profile.id, store.account.signedIn else { return }
            let values = try movie.url.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size > 0 else { throw CocoaError(.fileReadCorruptFile) }
            guard size <= 250 * 1024 * 1024 else {
                store.tell("Video too large", "Choose a video smaller than 250 MB.")
                return
            }
            let duration = try await AVURLAsset(url: movie.url).load(.duration)
            guard duration.seconds.isFinite && duration.seconds > 0 else { throw CocoaError(.fileReadCorruptFile) }
            try Task.checkCancellation()
            guard owner == store.account.profile.id, store.account.signedIn else { return }
            let name = UUID().uuidString + "." + movie.url.pathExtension
            let destination = store.mediaURL(name)
            // A large file copy must not block typing, navigation, or the picker dismissal.
            try await Task.detached(priority: .userInitiated) { [source = movie.url, destination] in
                do { try FileManager.default.copyItem(at: source, to: destination) }
                catch { try? FileManager.default.removeItem(at: destination); throw error }
            }.value
            guard !Task.isCancelled, owner == store.account.profile.id, store.account.signedIn else {
                store.removeUnusedMedia(name)
                return
            }
            removeVideo()
            localFile = name
            let seconds = Int(min(duration.seconds.rounded(.down), Double(Int.max / 2)))
            let time = "\(seconds / 60):" + String(format: "%02d", seconds % 60)
            mediaDetails = time + " · " + ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        } catch {
            if !Task.isCancelled, owner == store.account.profile.id, store.account.signedIn {
                store.tell("Couldn't import video", "Choose a supported video from your library and try again. Your caption is still here.")
            }
        }
    }
}

/// A poster is enough to confirm the selection; this editor never creates another player.
private struct PublisherMediaCard: View {
    let url: URL?
    let details: String
    let importing: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url {
                LocalVideoPoster(url: url, height: 236)
                    .clipped().accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(LocalizedStringKey(importing ? "Adding your video…" : "Video selected")).font(.tati(.headline))
                        Spacer(minLength: 8)
                        Text(verbatim: details).font(.tati(.caption)).monospacedDigit()
                    }
                    selectionLabel("Choose another video")
                }.padding(18)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your food, in motion.")
                        .font(.tati(.largeTitle, design: .serif, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .center, spacing: 12) {
                        Text("From your kitchen to your favourite table.")
                            .font(.tati(.subheadline)).foregroundStyle(Color.tatiCream)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !typeSize.isAccessibilitySize {
                            Art(name: "discovery-live-camera", width: 112, height: 124)
                        }
                    }
                    selectionLabel("Choose a video")
                }.padding(22)
            }
        }
        .foregroundStyle(Color.tatiCream)
        .background(Color.tatiInk, in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .ignore)
    }

    private func selectionLabel(_ title: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                actionLabel(title)
                Spacer(minLength: 0)
                if url == nil { Text("Up to 250 MB").font(.tati(.caption)).fixedSize() }
            }
            VStack(alignment: .leading, spacing: 10) {
                actionLabel(title)
                if url == nil { Text("Up to 250 MB").font(.tati(.caption)) }
            }
        }
    }

    private func actionLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            Art(name: "add-video", width: 22, height: 22)
                .phaseAnimator(importing && !reduceMotion && scenePhase == .active ? [false, true] : [false]) { content, phase in
                    content.opacity(phase ? 0.45 : 1)
                } animation: { _ in .easeInOut(duration: 0.8) }
            Text(LocalizedStringKey(importing ? "Adding your video…" : title))
                .font(.tati(.subheadline).weight(.bold)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.tatiInk).padding(.horizontal, 16).padding(.vertical, 13)
        .background(Color.tatiLime, in: Capsule())
    }
}

struct GoLiveView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @StateObject private var camera = KitchenCameraController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var title = ""
    @State private var topic = "Home cooking"
    @State private var cover: PhotosPickerItem?
    @State private var coverData: Data?
    @State private var previewTask: Task<Void, Never>?
    var body: some View {
        TatiEditingForm(title: "Go live") {
            PhotosPicker(selection: $cover, matching: .images) {
                HStack(spacing: 16) {
                    GeometryReader { geometry in
                        if let coverData {
                            PreparedDataPhoto(data: coverData, maxPixels: 384)
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        } else {
                            Art(name: "add-photo", width: 40, height: 40)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.tatiLime.opacity(0.45))
                        }
                    }.frame(width: 96, height: 112).clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(coverData == nil ? "Room cover" : "Cover selected").font(.tati(.headline))
                        Text("Pick a photo that hints at what's cooking.").font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                        Text(coverData == nil ? "Choose photo" : "Change photo")
                            .font(.tati(.caption).weight(.semibold)).foregroundStyle(Color.tatiInk)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.tatiLime, in: Capsule())
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain).accessibilityLabel(coverData == nil ? "Add a room cover" : "Change room cover")
            TatiEditingField(label: "Room title", placeholder: "What's cooking in your room?", text: $title, limit: 80)
            VStack(alignment: .leading, spacing: 10) {
                Text("Food topic").font(.tati(.subheadline).weight(.semibold)).accessibilityAddTraits(.isHeader)
                FilterTagLayout {
                    ForEach(Array(TableCommunity.topics.dropFirst()), id: \.self) { value in
                        BrowseFilterChip(title: value, selected: topic == value) { topic = value }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Camera").font(.tati(.subheadline).weight(.semibold))
                        Text(LocalizedStringKey(camera.status)).font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                            .fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        if camera.ready { previewTask?.cancel(); camera.stop() }
                        else {
                            previewTask?.cancel()
                            previewTask = Task {
                                let outcome = await camera.start()
                                guard !Task.isCancelled else { return }
                                store.explainCameraAvailability(outcome)
                            }
                        }
                    } label: {
                        Text(camera.starting ? "Starting…" : camera.ready ? "Turn off" : "Enable")
                            .font(.tati(.subheadline).weight(.semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .background(Color.tatiLime, in: Capsule())
                    }.buttonStyle(.plain).disabled(camera.starting)
                        .accessibilityLabel(camera.ready ? "Turn off camera" : "Turn on camera")
                }
                if camera.ready {
                    CameraSurface(session: camera.session).frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
        } footer: {
            TatiEditingButton(title: "Start live", enabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                store.tell("Broadcast unavailable", "Live streaming is unavailable. Your camera is not being broadcast, and no coins were used.")
            }
        }.task(id: cover) {
            guard let cover else { return }
            do { coverData = try await cover.loadTransferable(type: Data.self) }
            catch { store.tell("Couldn't load cover", "Please choose another image.") }
        }.onDisappear { previewTask?.cancel(); camera.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { previewTask?.cancel(); camera.stop() } }
    }
}
