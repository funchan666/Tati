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
struct VideoCard: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ClipPoster(clip: clip, height: 240)
            Art(name: "play-small", width: 30, height: 30).padding(12).background(.white.opacity(0.4)).clipShape(Circle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 5) {
                Text(store.authorName(for: clip)).font(.system(size: 14, weight: .semibold))
                Text(clip.caption).font(.system(size: 12)).lineLimit(2)
            }.padding(14).foregroundStyle(.white).shadow(color: .black, radius: 3, y: 1)
        }.frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 30))
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
    var body: some View {
        MediaViewport {
            ZStack {
                VStack {
                    HStack {
                        ArtButton(asset: "back", label: "Back") { dismiss() }
                        Spacer()
                        if clip.authorID == store.account.profile.id {
                            ArtButton(asset: "remove", label: "Delete video") { delete() }
                        } else { ArtButton(asset: "more", label: "Report video") { showReport = true } }
                    }
                    Spacer()
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let person = FoodCatalog.person(clip.authorID) {
                                NavigationLink(destination: PersonProfileView(person: person)) {
                                    HStack { Avatar(asset: person.portraitArtwork, size: 36); Text(person.name).font(.headline) }
                                }.buttonStyle(.plain)
                            } else { Text(store.authorName(for: clip)).font(.headline) }
                            Text(clip.caption).font(.subheadline)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(spacing: 12) {
                            ArtButton(asset: store.account.likes.contains(clip.id) ? "heart" : "like-video", label: "Like video", size: 33) { store.toggleLike(clip.id) }
                            Button { showComments = true } label: { SupplementIcon(icon: .comment, size: 30).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Comments")
                        }
                    }.padding(.bottom, 18).shadow(color: .black, radius: 3, y: 1)
                }.padding(.horizontal, 14).foregroundStyle(.white)
            }
            .overlay {
                if playback.activeID == clip.id, playback.ownerID == playbackOwner, playback.failure == nil {
                    VStack(spacing: 8) {
                        Button { playback.toggle() } label: {
                            SupplementIcon(icon: playback.wantsToPlay ? .pause : .play, size: 38)
                                .frame(width: 54, height: 54).background(.white.opacity(0.4)).clipShape(Circle())
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
        }
        .background {
            GeometryReader { geometry in
                if let player = playback.player, playback.activeID == clip.id, playback.ownerID == playbackOwner, playback.failure == nil {
                    ClipSurface(player: player).background(Color.black)
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
        .sheet(isPresented: $showReport) { NavigationStack { VideoOptionsView(clip: clip) }.overlay { NoticeLayer() } }
    }
    private func preparePlayback() {
        failure = nil
        roomSession.audio.stop()
        guard let url = store.videoURL(for: clip) else { failure = "The video file could not be found."; return }
        do { try playback.load(id: clip.id, url: url, owner: playbackOwner) }
        catch { failure = clip.isCollection ? "This video is unavailable." : "This video file is missing. Reimport it from your library." }
    }
    private func delete() {
        store.confirm("Delete video?", "This removes the imported copy from Tati. The original in Photos is unchanged.", button: "Delete", destructive: true) {
            playback.stop()
            if store.change({ $0.clips.removeAll { $0.id == clip.id }; $0.likes.remove(clip.id) }) {
                if let file = clip.fileName { store.removeUnusedMedia(file) }
                dismiss()
            }
        }
    }
}
struct CommentDraftView: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @State private var text = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("DISCUSS").font(.system(size: 18, weight: .bold, design: .serif)); Spacer() }.padding(18)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("No comments yet").font(.system(size: 12)).foregroundStyle(Color.tatiOlive)
                    if let saved = store.account.drafts["comment:" + clip.id], !saved.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Avatar(file: store.account.profile.avatarFile, size: 40, isCurrent: true)
                            VStack(alignment: .leading, spacing: 5) { Text(store.account.profile.name).font(.system(size: 14, weight: .medium)); Text(saved).font(.system(size: 13)); Text("Draft · not posted").font(.system(size: 10)).foregroundStyle(Color.tatiOlive) }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18)
            }
            HStack(spacing: 6) {
                TextField("Tell me your opinion…", text: $text, axis: .vertical).lineLimit(1...4).font(.system(size: 13)).padding(.leading, 14).tint(.white)
                Button {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    if store.saveDraft("comment:" + clip.id, text: text) { store.tell("Draft saved", "Your comment draft has been saved. It has not been posted.") }
                } label: { Text("SAVE").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.tatiInk).padding(.horizontal, 14).padding(.vertical, 9).background(Color.tatiLime).clipShape(Capsule()).frame(minHeight: 44) }.buttonStyle(.plain).accessibilityLabel("Save comment draft")
            }.padding(.horizontal, 5).background(Color.tatiPink).clipShape(Capsule()).padding(16)
        }.background(Color.tatiCream).foregroundStyle(Color.tatiInk).presentationBackground(Color.tatiCream).presentationCornerRadius(20).presentationDragIndicator(.hidden)
            .tatiScreen()
            .onAppear { text = store.account.drafts["comment:" + clip.id] ?? "" }
    }
}
struct PublishChooser: View {
    var body: some View {
        TatiPanel(title: "Create") {
            HStack(spacing: 14) { NavigationLink(destination: GoLiveView()) { Art(name: "go-live", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Go live")
            NavigationLink(destination: PublishVideoView()) { Art(name: "post-video", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Post video") }
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
            InputField(title: "Please input your thoughts…", text: $caption, multiline: true, showsLabel: false)
                .onChange(of: caption) { _, value in if value.count > 50 { caption = String(value.prefix(50)) } }
            Text("\(caption.count)/50").font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
            Note(text: "Save the video to your collection. Publishing is currently unavailable.")
        } footer: {
            TatiButton(title: "Save video", enabled: localFile != nil && !importing && !committed && !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                guard let localFile else { return }
                let clip = FoodClip(id: UUID().uuidString, authorID: store.account.profile.id, caption: caption.trimmingCharacters(in: .whitespacesAndNewlines), fileName: localFile, createdAt: Date(), isSample: false)
                if store.change({ $0.clips.insert(clip, at: 0) }) { committed = true; dismiss(); store.tell("Video saved", "Your video has been added to your collection. It has not been published.") }
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
