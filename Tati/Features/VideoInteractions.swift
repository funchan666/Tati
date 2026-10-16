import SwiftUI

struct FeedVideoCard: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var playback: ClipPlayback
    @EnvironmentObject private var roomSession: RoomPreviewSession
    @State private var playbackOwner = UUID().uuidString
    private var active: Bool { playback.activeID == clip.id && playback.ownerID == playbackOwner }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if active, let player = playback.player { ClipSurface(player: player).background(Color.black).frame(height: 240) }
                else if let file = clip.fileName { LocalVideoPoster(url: store.mediaURL(file), height: 240) }
                else { MediaPlaceholder(title: "Video to come", height: 240) }
                if clip.fileName != nil {
                    Button {
                        roomSession.audio.stop()
                        do {
                            if !active, let file = clip.fileName { try playback.load(id: clip.id, url: store.mediaURL(file), owner: playbackOwner) }
                            playback.toggle()
                        } catch { store.tell("Video unavailable", "The local video could not be opened. Reimport the original file.") }
                    } label: {
                        SupplementIcon(icon: active && playback.playing ? .pause : .play, size: 30).padding(14).background(Color.tatiCream).clipShape(Circle())
                    }.buttonStyle(.plain).accessibilityLabel(active && playback.playing ? "Pause video" : "Play video")
                }
            }.clipShape(RoundedRectangle(cornerRadius: 20))
            HStack {
                if let person = FoodCatalog.person(clip.authorID) {
                    NavigationLink(destination: PersonProfileView(person: person)) { HStack { Avatar(size: 32); Text(person.name).font(.headline) } }.buttonStyle(.plain)
                } else { Text(store.account.profile.name).font(.headline) }
                Spacer()
                ArtButton(asset: store.account.likes.contains(clip.id) ? "heart" : "like-video", label: "Like video") { store.toggleLike(clip.id) }
            }
            NavigationLink(destination: ClipDetailView(clip: clip)) {
                VStack(alignment: .leading, spacing: 6) { Text(clip.caption).font(.subheadline); Text("Open video and comments").font(.caption.bold()) }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.buttonStyle(.plain)
            if active, let failure = playback.failure { Note(text: failure) }
            Note(text: clip.isSample ? "Sample · media pending" : "Local video · " + clip.createdAt.formatted(date: .abbreviated, time: .omitted))
        }.padding(12).background(Color.white.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 24)).foregroundStyle(Color.tatiInk)
        .onDisappear { if active { playback.stop() } }
    }
}
struct VideoOptionsView: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPanel(title: "Video options") {
            NavigationLink(destination: ReportView(subjectID: "video:" + clip.id)) { Art(name: "report-button", height: 90).frame(maxWidth: .infinity) }.accessibilityLabel("Report this video")
            if let person = FoodCatalog.person(clip.authorID) {
                ImageAction(asset: "block-button", label: "Block video author", height: 90) { store.block(person.id) }
                NavigationLink(destination: PersonProfileView(person: person)) { SettingRow(title: "View author profile", asset: "profile-button") }.buttonStyle(.plain)
            }
        }
    }
}
