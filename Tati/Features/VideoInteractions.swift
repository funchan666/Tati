import SwiftUI

struct FeedVideoCard: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @State private var showComments = false
    @State private var showOptions = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NavigationLink(destination: ClipDetailView(clip: clip)) {
                    ClipPoster(clip: clip, height: geometry.size.height)
                        .overlay {
                            SupplementIcon(icon: .play, size: 26, tint: .white)
                                .frame(width: 48, height: 48).background(.black.opacity(0.3)).clipShape(Circle())
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.32)
                        }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Play full screen: " + clip.caption)
                VStack(alignment: .leading, spacing: 7) {
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        VideoAuthor(clip: clip, size: 32)
                        Spacer(minLength: 4)
                        Button { store.toggleLike(clip.id) } label: {
                            HStack(spacing: 3) {
                                Art(name: store.account.likes.contains(clip.id) ? "heart" : "like-video", width: 22, height: 22)
                                Text("\(store.likeCount(for: clip))").font(.system(size: 11)).monospacedDigit()
                            }.frame(minWidth: 44, minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("\(store.likeCount(for: clip)) likes")
                            .accessibilityAddTraits(store.account.likes.contains(clip.id) ? .isSelected : [])
                        Button { showComments = true } label: {
                            HStack(spacing: 3) {
                                SupplementIcon(icon: .comment, size: 21, tint: .white)
                                Text("\(store.comments(for: clip).count)").font(.system(size: 11)).monospacedDigit()
                            }.frame(minWidth: 44, minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("\(store.comments(for: clip).count) comments")
                    }
                    NavigationLink(destination: ClipDetailView(clip: clip)) {
                        Text(clip.caption).font(.system(size: 12)).lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 12).padding(.bottom, 14)
                    .background {
                        LinearGradient(colors: [.clear, .clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                            .allowsHitTesting(false)
                    }
                VStack {
                    HStack {
                        Spacer()
                        ArtButton(asset: "more", label: "Video options: report or block", size: 24) { showOptions = true }
                    }
                    Spacer()
                }.padding(5)
            }.frame(width: geometry.size.width, height: geometry.size.height)
                .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 24))
        }.aspectRatio(1.42, contentMode: .fit)
        .sheet(isPresented: $showComments) {
            CommentDraftView(clip: clip).overlay { NoticeLayer() }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showOptions) {
            VideoOptionsView(clip: clip).overlay { NoticeLayer() }
        }
    }
}

struct VideoAuthor: View {
    var clip: FoodClip
    var size: CGFloat = 36
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        Group {
            if let person = FoodCatalog.person(clip.authorID) {
                NavigationLink(destination: PersonProfileView(person: person)) {
                    HStack(spacing: 7) {
                        Avatar(asset: person.portraitArtwork, size: size)
                        Text(person.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("View " + person.name)
            } else {
                HStack(spacing: 7) {
                    Avatar(file: store.account.profile.avatarFile, size: size, isCurrent: true)
                    Text(store.authorName(for: clip)).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                }
            }
        }
    }
}

struct VideoOptionsView: View {
    private enum Destination: Hashable { case report, profile }
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Destination] = []
    var body: some View {
        NavigationStack(path: $path) {
            TatiPanel(title: "Video options") {
                NavigationLink(value: Destination.report) {
                    SettingRow(title: "Report video", asset: "feedback")
                }.buttonStyle(.plain)
                if let person = FoodCatalog.person(clip.authorID) {
                    Button { store.block(person.id) } label: { SettingRow(title: "Block " + person.name, asset: "blacklist") }.buttonStyle(.plain)
                    NavigationLink(value: Destination.profile) { SettingRow(title: "View author profile", asset: "profile-button") }.buttonStyle(.plain)
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .report: ReportView(subjectID: "video:" + clip.id)
                case .profile:
                    if let person = FoodCatalog.person(clip.authorID) { PersonProfileView(person: person) }
                }
            }
        }
        .presentationDetents(path.isEmpty ? [.height(250), .large] : [.large])
        .onChange(of: store.account.blocked) { _, blocked in
            if blocked.contains(clip.authorID) { dismiss() }
        }
    }
}
