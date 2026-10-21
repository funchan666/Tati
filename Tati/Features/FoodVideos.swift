import SwiftUI
import PhotosUI
import AVFoundation

struct VideoFeedView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                HStack {
                    Art(name: "video-heading", width: 156, height: 62)
                    Spacer()
                    NavigationLink(destination: PublishVideoView()) { Art(name: "publish", width: 32).frame(width: 44, height: 44) }.accessibilityLabel("Add a video")
                }
                if ContentLibrary.unavailable { Note(text: "Content could not be loaded.") }
                ForEach(store.visibleClips) { clip in FeedVideoCard(clip: clip) }
                if store.visibleClips.isEmpty { EmptyContent(title: "A little taste of your world", detail: "Add a food video to your collection.") }
            }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
    }
}
struct ClipDetailView: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var playback: ClipPlayback
    @EnvironmentObject private var roomSession: RoomPreviewSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var showComments = false
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
                        HStack(alignment: .bottom, spacing: 16) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    VideoAuthor(clip: clip)
                                    Text(clip.caption).font(.subheadline)
                                    if !store.isClipVisible(clip) {
                                        Text("Awaiting review · Only you can see this").font(.caption)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.frame(maxHeight: min(150, geometry.size.height * 0.28))
                            if store.isClipVisible(clip) {
                            VStack(spacing: 12) {
                                VStack(spacing: 2) {
                                    ArtButton(asset: store.account.likes.contains(clip.id) ? "heart" : "like-video", label: store.account.likes.contains(clip.id) ? "Unlike video" : "Like video", size: 33) { store.toggleLike(clip.id) }
                                    Text("\(store.likeCount(for: clip))").font(.system(size: 12)).monospacedDigit()
                                }
                                Button { showComments = true } label: {
                                    VStack(spacing: 2) {
                                        SupplementIcon(icon: .comment, size: 30, tint: showsVideo ? .white : .tatiInk).frame(width: 44, height: 44)
                                        Text("\(store.comments(for: clip).count)").font(.system(size: 12)).monospacedDigit()
                                    }
                                }.buttonStyle(.plain).accessibilityLabel("\(store.comments(for: clip).count) comments")
                            }
                            }
                        }.padding(.bottom, 18).shadow(color: .black, radius: 3, y: 1)
                    }.padding(.horizontal, 14).foregroundStyle(showsVideo ? Color.white : Color.tatiInk)
                }
                .overlay {
                    if playback.activeID == clip.id, playback.ownerID == playbackOwner, playback.failure == nil {
                        VStack(spacing: 8) {
                            Button { playback.toggle() } label: {
                                SupplementIcon(icon: playback.wantsToPlay ? .pause : .play, size: 32, tint: .white)
                                    .frame(width: 54, height: 54).background(.black.opacity(0.3)).clipShape(Circle())
                            }.buttonStyle(.plain).accessibilityLabel(playback.wantsToPlay ? "Pause video" : "Play video")
                            if playback.loading { Text("Loading…").font(.caption).foregroundStyle(.white) }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Art(name: "media-placeholder", width: 78)
                            Text(playback.failure ?? failure ?? "The video could not be loaded.").font(.headline).multilineTextAlignment(.center)
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
        .sheet(isPresented: $showComments) { NavigationStack { CommentDraftView(clip: clip) }.overlay { NoticeLayer() }.presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showReport) { VideoOptionsView(clip: clip) }
        .onChange(of: showReport) { _, presented in
            if !presented && (store.isPersonHidden(clip.authorID) || store.isHidden("video:" + clip.id)) { dismiss() }
        }
        .onChange(of: store.account.hiddenSubjects) { _, _ in closeIfHidden() }
        .onChange(of: store.account.blocked) { _, _ in closeIfHidden() }
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
        catch { failure = clip.bundledFile != nil ? "This video is unavailable." : "This video file is missing. Reimport it from your library." }
    }
    private func delete() {
        store.confirm("Delete video?", "This removes the imported copy from Tati. The original in Photos is unchanged.", button: "Delete", destructive: true) {
            playback.stop()
            if store.change({ $0.clips.removeAll { $0.id == clip.id }; $0.likes.remove(clip.id); $0.videoComments?.removeAll { $0.clipID == clip.id } }) {
                if let file = clip.fileName { store.removeUnusedMedia(file) }
                dismiss()
            }
        }
    }
}
struct CommentDraftView: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedComment: VideoComment?
    private var comments: [VideoComment] { store.comments(for: clip) }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Comments · \(comments.count)").font(.system(size: 18, weight: .bold, design: .serif))
                Spacer()
                ArtButton(asset: "close-light", label: "Close comments") { dismiss() }
            }.padding(.horizontal, 18).padding(.top, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if comments.isEmpty {
                            Text("Be the first to comment.").font(.system(size: 13)).foregroundStyle(Color.tatiOlive)
                                .padding(.vertical, 24)
                        }
                        ForEach(comments) { comment in
                            let current = comment.authorID == store.account.profile.id
                            let person = FoodCatalog.person(comment.authorID)
                            HStack(alignment: .top, spacing: 10) {
                                UserProfileLink(userID: comment.authorID) {
                                    Avatar(file: current ? store.account.profile.avatarFile : nil, asset: person?.portraitArtwork, size: 38, isCurrent: current)
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    UserProfileLink(userID: comment.authorID) {
                                        Text(current ? store.account.profile.name : person?.name ?? "Creator").font(.system(size: 14, weight: .medium))
                                    }
                                    Text(comment.text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                                    Text(comment.createdAt, style: .relative).font(.system(size: 10)).foregroundStyle(Color.tatiOlive)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if current {
                                    ArtButton(asset: "remove", label: "Delete comment", size: 16) {
                                        store.confirm("Delete comment?", "This comment will be removed.", button: "Delete", destructive: true) { store.removeComment(comment.id) }
                                    }
                                }
                                ArtButton(asset: "more", label: "Report comment", size: 16) { selectedComment = comment }
                            }.id(comment.id)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                }
                .onChange(of: comments.map(\.id)) { _, ids in
                    if let last = ids.last { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                }
            }
            HStack(spacing: 6) {
                TextField("Tell me your opinion…", text: $text, axis: .vertical).lineLimit(1...4)
                    .font(.system(size: 13)).padding(.leading, 14).tint(.white)
                    .onChange(of: text) { _, value in text = String(value.prefix(500)) }
                Button {
                    if store.addComment(to: clip, text: text) { text = "" }
                } label: {
                    Text("Send").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.tatiInk)
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
                NavigationLink(value: PublishDestination.video) { Art(name: "post-video", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Post video")
            }
        }
    }
}
struct PublishVideoView: View {
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?
    @State private var localFile: String?
    @State private var caption = ""
    @State private var importing = false
    @State private var committed = false
    var body: some View {
        TatiForm(title: "Post") {
            PhotosPicker(selection: $selection, matching: .videos) {
                ZStack(alignment: .bottom) {
                    if let localFile {
                        LocalVideoPoster(url: store.mediaURL(localFile), height: 280)
                        Art(name: "change-video", height: 30).padding(.bottom, 20)
                    } else {
                        VStack(spacing: 22) {
                            Art(name: "add-video", height: 64)
                            Text(importing ? "Importing your video…" : "Select your food video").font(.system(size: 12)).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(20)
                    }
                }.frame(maxWidth: 250).frame(height: 280).background(Color.tatiLime.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 20)).frame(maxWidth: .infinity)
            }.buttonStyle(.plain).disabled(importing)
            InputField(title: "Please input your thoughts…", text: $caption, multiline: true, showsLabel: false, minimumHeight: 80, characterLimit: 50)
                .onChange(of: caption) { _, value in if value.count > 50 { caption = String(value.prefix(50)) } }
        } footer: {
            TatiButton(title: "Post", enabled: localFile != nil && !importing && !committed && !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                guard let localFile else { return }
                let clip = FoodClip(id: UUID().uuidString, authorID: store.account.profile.id, caption: caption.trimmingCharacters(in: .whitespacesAndNewlines), fileName: localFile, createdAt: Date(), isSample: false)
                if store.submitPost(clip) { committed = true; dismiss(); store.celebrate("Saved for review", "Your post stays private until review is complete and it is approved.", artwork: "chef") }
            }
        }
        .task(id: selection) {
            guard let selection else { return }
            let owner = store.account.profile.id
            importing = true; defer { importing = false }
            do {
                guard let movie = try await selection.loadTransferable(type: ImportedMovie.self) else { throw CocoaError(.fileReadUnknown) }
                defer { try? FileManager.default.removeItem(at: movie.url) }
                let values = try movie.url.resourceValues(forKeys: [.fileSizeKey])
                guard (values.fileSize ?? 0) <= 250 * 1024 * 1024 else { store.tell("Video too large", "Choose a video smaller than 250 MB."); return }
                let duration = try await AVURLAsset(url: movie.url).load(.duration)
                guard duration.seconds.isFinite && duration.seconds > 0 else { throw CocoaError(.fileReadCorruptFile) }
                guard !Task.isCancelled, owner == store.account.profile.id else { return }
                let name = UUID().uuidString + "." + movie.url.pathExtension
                try FileManager.default.copyItem(at: movie.url, to: store.mediaURL(name))
                if let old = localFile { store.removeUnusedMedia(old) }
                localFile = name
            } catch { if !Task.isCancelled { store.tell("Couldn't import video", "Choose a supported video from your library and try again. Your caption is still here.") } }
        }
        .onDisappear { if !committed, let localFile { store.removeUnusedMedia(localFile) } }
    }
}
struct GoLiveView: View {
    @EnvironmentObject private var store: VisitorStore
    @StateObject private var camera = CameraPreviewController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var title = ""
    @State private var topic = "Home cooking"
    @State private var cover: PhotosPickerItem?
    @State private var coverData: Data?
    @State private var previewTask: Task<Void, Never>?
    var body: some View {
        TatiForm(title: "Go Live") {
            PhotosPicker(selection: $cover, matching: .images) {
                Group {
                    if let coverData, let ui = UIImage(data: coverData) { Image(uiImage: ui).resizable().scaledToFill().frame(height: 200).clipped() }
                    else { VStack { Art(name: "add-photo", height: 60); Text("Add a cover").font(.caption) }.frame(maxWidth: .infinity).frame(height: 200).background(Color.tatiLime.opacity(0.4)) }
                }.clipShape(RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain)
            Text("Title").font(.system(size: 14))
            InputField(title: "What's your room about?", text: $title, showsLabel: false).onChange(of: title) { _, value in title = String(value.prefix(80)) }
            Text("Label").font(.system(size: 14))
            ChoiceGrid(items: Array(FoodCatalog.topics.dropFirst()), selected: $topic)
            if camera.ready { CameraSurface(session: camera.session).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 20)) }
            Note(text: camera.status)
            TatiButton(title: camera.starting ? "Starting camera…" : camera.ready ? "Turn off camera" : "Turn on camera", secondary: true, enabled: !camera.starting) {
                if camera.ready { previewTask?.cancel(); camera.stop() }
                else { previewTask?.cancel(); previewTask = Task { await camera.start() } }
            }
        } footer: {
            TatiButton(title: "Start live", enabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                store.tell("Broadcast unavailable", "Broadcasting is currently unavailable. No broadcast has started and no coins were charged.")
            }
        }.task(id: cover) {
            guard let cover else { return }
            do { coverData = try await cover.loadTransferable(type: Data.self) }
            catch { store.tell("Couldn't load cover", "Please choose another image.") }
        }.onDisappear { previewTask?.cancel(); camera.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { previewTask?.cancel(); camera.stop() } }
    }
}
