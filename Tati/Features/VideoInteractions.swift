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
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    if active, let player = playback.player, playback.failure == nil {
                        ClipSurface(player: player, fillsContainer: true).background(Color.black).allowsHitTesting(false)
                    } else { ClipPoster(clip: clip, height: geometry.size.height).allowsHitTesting(false) }
                    NavigationLink(destination: ClipDetailView(clip: clip)) { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain).accessibilityLabel("Open video and comments")
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            if let person = FoodCatalog.person(clip.authorID) {
                                NavigationLink(destination: PersonProfileView(person: person)) {
                                    Avatar(asset: person.portraitArtwork, size: 40)
                                }.buttonStyle(.plain).accessibilityLabel("View author")
                            } else if clip.isCollection {
                                Avatar(asset: "brand-icon", size: 40)
                            } else {
                                Avatar(file: store.account.profile.avatarFile, size: 40, isCurrent: true)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.authorName(for: clip)).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                if !clip.isSample { Text(clip.createdAt, style: .date).font(.system(size: 11)) }
                            }
                            Spacer()
                        }
                        HStack(alignment: .bottom, spacing: 8) {
                            NavigationLink(destination: ClipDetailView(clip: clip)) {
                                Text(clip.caption).font(.system(size: 13)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            ArtButton(asset: store.account.likes.contains(clip.id) ? "heart" : "like-video", label: "Like video", size: 21) { store.toggleLike(clip.id) }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 10).foregroundStyle(.white).shadow(color: .black, radius: 3, y: 1)
                }
                .overlay {
                    VStack(spacing: 6) {
                        Button(action: playOrPause) {
                            if active && playback.failure != nil {
                                Text("Retry").font(.system(size: 13, weight: .semibold)).padding(12).background(Color.tatiPink).clipShape(Capsule())
                            } else {
                                SupplementIcon(icon: active && playback.wantsToPlay ? .pause : .play, size: 30)
                                    .frame(width: 44, height: 44).background(.white.opacity(0.45)).clipShape(Circle())
                            }
                        }.buttonStyle(.plain)
                            .accessibilityLabel(active && playback.failure != nil ? "Retry video" : active && playback.wantsToPlay ? "Pause video" : "Play video")
                        if active && playback.loading { Text("Loading…").font(.caption) }
                        if active, let failure = playback.failure { Text(failure).font(.caption).multilineTextAlignment(.center).padding(.horizontal, 24) }
                    }.foregroundStyle(.white).shadow(color: .black, radius: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30))
            }
        }.aspectRatio(1.42, contentMode: .fit)
        .onDisappear { if active { playback.stop() } }
    }

    private func playOrPause() {
        roomSession.audio.stop()
        do {
            if !active || playback.failure != nil {
                guard let url = store.videoURL(for: clip) else { throw CocoaError(.fileNoSuchFile) }
                try playback.load(id: clip.id, url: url, owner: playbackOwner)
            } else {
                playback.toggle()
            }
        } catch { store.tell("Video unavailable", "The video file could not be found. Reimport it if it was added from your library.") }
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
