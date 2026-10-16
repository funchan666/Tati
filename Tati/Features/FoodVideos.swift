import SwiftUI
import PhotosUI
import AVFoundation

struct VideoFeedView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Art(name: "video-heading", width: 150, height: 55)
                    Spacer()
                    NavigationLink(destination: PublishVideoView()) { Art(name: "publish", width: 32).frame(width: 44, height: 44) }.accessibilityLabel("Add a video")
                }
                Note(text: "Sample videos await media. Your imported videos stay on this device.")
                ForEach(store.visibleClips) { clip in NavigationLink(destination: ClipDetailView(clip: clip)) { VideoCard(clip: clip) }.buttonStyle(.plain) }
                if store.visibleClips.isEmpty { EmptyContent(title: "A little taste of your world", detail: "Add a food video to your local collection.") }
            }.padding(20)
        }
    }
}
struct VideoCard: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                MediaPlaceholder(title: clip.fileName == nil ? "Video to come" : "Local video ready", height: 210)
                HStack {
                    Text(clip.isSample ? "Sample" : "On this device").font(.caption.bold()).padding(8).background(Color.tatiLime).clipShape(Capsule())
                    Spacer()
                    Art(name: "play-small", width: 22, height: 22).padding(9).background(Color.tatiCream).clipShape(Circle())
                }.padding(12)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.authorID == store.account.profile.id ? store.account.profile.name : FoodCatalog.person(clip.authorID)?.name ?? "Creator").font(.headline)
                    Text(clip.caption).font(.subheadline).lineLimit(2)
                }
                Spacer()
                if store.account.likes.contains(clip.id) { Art(name: "heart", width: 22) }
            }.padding(.horizontal, 4)
        }.foregroundStyle(Color.tatiInk).padding(10).background(.white.opacity(0.58)).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
struct ClipDetailView: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var playback: ClipPlayback
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var showComments = false
    @State private var showReport = false
    @State private var failure: String?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ArtButton(asset: "back", label: "Back") { dismiss() }
                Spacer()
                if clip.authorID == store.account.profile.id {
                    ArtButton(asset: "remove", label: "Delete local video") { delete() }
                } else { ArtButton(asset: "more", label: "Report video") { showReport = true } }
            }.padding(.horizontal, 12)
            ZStack(alignment: .bottomTrailing) {
                if let player = playback.player, playback.activeID == clip.id, playback.failure == nil {
                    ClipSurface(player: player).background(Color.black)
                    Button { playback.toggle() } label: { SupplementIcon(icon: playback.playing ? .pause : .play, size: 38).padding(14).background(Color.tatiCream).clipShape(Circle()) }.buttonStyle(.plain).accessibilityLabel(playback.playing ? "Pause video" : "Play video").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Art(name: "media-placeholder", width: 78)
                        Text(playback.failure ?? failure ?? "Video media hasn't been added yet.").font(.headline).multilineTextAlignment(.center)
                        Text(clip.isSample ? "This is a sample preview, not a playing video." : "Your imported video is unavailable.").font(.caption).multilineTextAlignment(.center)
                    }.padding(25).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.tatiCream)
                }
                VStack(spacing: 14) {
                    ArtButton(asset: store.account.likes.contains(clip.id) ? "heart" : "like-video", label: "Like video", size: 33) { store.toggleLike(clip.id) }
                    Button { showComments = true } label: { SupplementIcon(icon: .comment, size: 30).frame(width: 44, height: 44).background(Color.tatiCream).clipShape(Circle()) }.buttonStyle(.plain).accessibilityLabel("Comments")
                }.padding(18)
            }.frame(maxHeight: .infinity).clipShape(RoundedRectangle(cornerRadius: 22)).padding(.horizontal, 12)
            VStack(alignment: .leading, spacing: 9) {
                if let person = FoodCatalog.person(clip.authorID) {
                    NavigationLink(destination: PersonProfileView(person: person)) { HStack { Avatar(size: 36); Text(person.name).font(.headline); Text("Sample profile").font(.caption) } }.buttonStyle(.plain)
                } else { Text(store.account.profile.name).font(.headline) }
                Text(clip.caption).font(.subheadline)
                Note(text: clip.isSample ? "Sample content · video pending" : "Saved on this device · not uploaded")
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).toolbar(.hidden, for: .navigationBar)
        .task {
            if let file = clip.fileName { do { try playback.load(id: clip.id, url: store.mediaURL(file)) } catch { failure = "This video file is missing. Reimport it from your library." } }
        }
        .onDisappear { playback.stop() }
        .onChange(of: scenePhase) { _, value in if value != .active { playback.stop() } else if let file = clip.fileName { try? playback.load(id: clip.id, url: store.mediaURL(file)) } }
        .sheet(isPresented: $showComments) { NavigationStack { CommentDraftView(clip: clip) }.overlay { NoticeLayer() } }
        .sheet(isPresented: $showReport) { NavigationStack { ReportView(subjectID: "video:" + clip.id) }.overlay { NoticeLayer() } }
    }
    private func delete() {
        store.confirm("Delete local video?", "This removes the imported copy from Tati. The original in Photos is unchanged.", button: "Delete", destructive: true) {
            playback.stop()
            if store.change({ $0.clips.removeAll { $0.id == clip.id }; $0.likes.remove(clip.id) }) {
                if let file = clip.fileName { try? FileManager.default.removeItem(at: store.mediaURL(file)) }
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
        TatiPage(title: "Discuss") {
            EmptyContent(title: "No connected comments", detail: "Comments will appear when the community service is connected.", artwork: "chat-heading")
            InputField(title: "Tell me your opinion…", text: $text, multiline: true)
            TatiButton(title: "Save comment draft", enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                if store.saveDraft("comment:" + clip.id, text: text) { store.tell("Draft saved", "This comment is saved only on this device. It has not been posted.") }
            }
        }.onAppear { text = store.account.drafts["comment:" + clip.id] ?? "" }
    }
}
struct PublishChooser: View {
    var body: some View {
        TatiPage(title: "Share something delicious") {
            NavigationLink(destination: GoLiveView()) { Art(name: "go-live", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Go live")
            NavigationLink(destination: PublishVideoView()) { Art(name: "post-video", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Post video")
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
        TatiPage(title: "Post") {
            PhotosPicker(selection: $selection, matching: .videos) {
                VStack(spacing: 16) {
                    Art(name: localFile == nil ? "add-video" : "media-placeholder", height: 80)
                    Text(importing ? "Importing your video…" : localFile == nil ? "Select your food video" : "Video selected · Tap to change").font(.subheadline)
                }.frame(maxWidth: .infinity).frame(height: 250).background(Color.tatiLime.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 24))
            }.buttonStyle(.plain).disabled(importing)
            InputField(title: "Capture a tasty moment", text: $caption, multiline: true)
                .onChange(of: caption) { _, value in if value.count > 300 { caption = String(value.prefix(300)) } }
            Text("\(caption.count)/300").font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
            Note(text: "Saved as a local video. Upload and moderation are not connected. No coins will be charged.")
            TatiButton(title: "Save local video", enabled: localFile != nil && !importing && !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                guard let localFile else { return }
                let clip = FoodClip(id: UUID().uuidString, authorID: store.account.profile.id, caption: caption.trimmingCharacters(in: .whitespacesAndNewlines), fileName: localFile, createdAt: Date(), isSample: false)
                if store.change({ $0.clips.insert(clip, at: 0) }) { committed = true; dismiss() }
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
                if let old = localFile { try? FileManager.default.removeItem(at: store.mediaURL(old)) }
                localFile = name
            } catch { if !Task.isCancelled { store.tell("Couldn't import video", "Choose a supported video from your library and try again. Your caption is still here.") } }
        }
        .onDisappear { if !committed, let localFile { try? FileManager.default.removeItem(at: store.mediaURL(localFile)) } }
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
        TatiPage(title: "Go live") {
            PhotosPicker(selection: $cover, matching: .images) {
                Group {
                    if let coverData, let ui = UIImage(data: coverData) { Image(uiImage: ui).resizable().scaledToFill().frame(height: 200).clipped() }
                    else { VStack { Art(name: "add-photo", height: 60); Text("Add a cover").font(.caption) }.frame(maxWidth: .infinity).frame(height: 200).background(Color.tatiLime.opacity(0.4)) }
                }.clipShape(RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain)
            InputField(title: "What's your room about?", text: $title)
            ChoiceGrid(items: Array(FoodCatalog.topics.dropFirst()), selected: $topic)
            if camera.ready { CameraSurface(session: camera.session).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 20)) }
            Note(text: camera.status)
            TatiButton(title: camera.starting ? "Starting camera…" : camera.ready ? "Stop camera preview" : "Preview my camera", secondary: true, enabled: !camera.starting) {
                if camera.ready { previewTask?.cancel(); camera.stop() }
                else { previewTask?.cancel(); previewTask = Task { await camera.start() } }
            }
            TatiButton(title: "Start live", enabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                store.tell("Live service not connected", "Your camera preview stays on this device. A connected streaming service is required to start a broadcast. No coins have been charged.")
            }
        }.task(id: cover) {
            guard let cover else { return }
            do { coverData = try await cover.loadTransferable(type: Data.self) }
            catch { store.tell("Couldn't load cover", "Please choose another image.") }
        }.onDisappear { previewTask?.cancel(); camera.stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { previewTask?.cancel(); camera.stop() } }
    }
}
