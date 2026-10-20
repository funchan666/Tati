import SwiftUI

struct FeedVideoCard: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var playback: ClipPlayback
    @EnvironmentObject private var roomSession: RoomPreviewSession
    @State private var playbackOwner = UUID().uuidString
    private var active: Bool { playback.activeID == clip.id && playback.ownerID == playbackOwner }
    var body: some View {
        MediaViewport {
            ZStack {
                if active, let player = playback.player { ClipSurface(player: player, fillsContainer: true).background(Color.black) }
                else { ClipPoster(clip: clip, height: 250) }
                NavigationLink(destination: ClipDetailView(clip: clip)) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("Open video and comments")
                Button {
                    roomSession.audio.stop()
                    do {
                        if !active {
                            guard let url = store.videoURL(for: clip) else { throw CocoaError(.fileNoSuchFile) }
                            try playback.load(id: clip.id, url: url, owner: playbackOwner)
                        }
                        playback.toggle()
                    } catch { store.tell("Video unavailable", "The video could not be opened. Reopen Tati, or reimport the file if it was added from your library.") }
                } label: {
                    SupplementIcon(icon: active && playback.playing ? .pause : .play, size: 32)
                        .frame(width: 48, height: 48).background(.white.opacity(0.45)).clipShape(Circle())
                }.buttonStyle(.plain).accessibilityLabel(active && playback.playing ? "Pause video" : "Play video")
                VStack(alignment: .leading, spacing: 5) {
                    Spacer()
                    HStack(spacing: 8) {
                        if let person = FoodCatalog.person(clip.authorID) {
                            NavigationLink(destination: PersonProfileView(person: person)) {
                                Avatar(asset: person.portraitArtwork, size: 34)
                            }.buttonStyle(.plain).accessibilityLabel("View author")
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.authorName(for: clip)).font(.system(size: 13, weight: .medium))
                            Text(clip.isSample ? "Offline collection" : "On this device").font(.system(size: 10))
                        }
                        Spacer()
                    }
                    HStack(alignment: .bottom, spacing: 8) {
                        NavigationLink(destination: ClipDetailView(clip: clip)) {
                            Text(clip.caption).font(.system(size: 12)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                        ArtButton(asset: store.account.likes.contains(clip.id) ? "heart" : "like-video", label: "Like video", size: 21) { store.toggleLike(clip.id) }
                    }
                    if active, let failure = playback.failure { Text(failure).font(.caption2) }
                }.padding(.horizontal, 14).padding(.bottom, 8).foregroundStyle(.white).shadow(color: .black, radius: 3, y: 1)
            }.clipShape(RoundedRectangle(cornerRadius: 22))
        }.frame(height: 250)
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
