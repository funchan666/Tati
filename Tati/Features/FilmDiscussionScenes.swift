import SwiftUI

struct FeedVideoCard: View {
    var clip: FoodFilm
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var showComments = false
    @State private var pendingProfile: TableMember?
    @Environment(\.profilePageAction) private var openProfile
    @State private var showOptions = false
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                NavigationLink(destination: ClipDetailView(clip: clip)) {
                    ClipPoster(clip: clip, height: geometry.size.height)
                        .overlay {
                            Art(name: "film-porcelain-play", width: 58, height: 58)
                        }
                        .contentShape(Rectangle())
                }.buttonStyle(FoodFilmPressStyle())
                    .accessibilityLabel("Play full screen: " + clip.dishCaption)
            }.aspectRatio(1.42, contentMode: .fit).clipped()

            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        VideoAuthor(clip: clip, size: 36, showsFollow: false)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 4)
                        FollowControl(userID: clip.authorID, style: .film)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        VideoAuthor(clip: clip, size: 36, showsFollow: false)
                        FollowControl(userID: clip.authorID, style: .film)
                    }
                }
                NavigationLink(destination: ClipDetailView(clip: clip)) {
                    Text(clip.dishCaption).font(.tati(.title3).weight(.semibold))
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain)
                HStack(spacing: 8) {
                    VideoEngagementActions(clip: clip, tint: .tatiInk, onPaper: true) { showComments = true }
                    Spacer()
                    Button { showOptions = true } label: {
                        Art(name: "more", width: 22, height: 22)
                            .frame(width: 44, height: 44)
                            .background(Color.tatiCream, in: Capsule())
                    }.buttonStyle(FoodFilmPressStyle())
                        .accessibilityLabel("Video options: report or block")
                }
            }.padding(16)
        }
        .foregroundStyle(Color.tatiInk)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .sheet(isPresented: $showComments, onDismiss: {
            if let person = pendingProfile {
                pendingProfile = nil
                if !store.isPersonHidden(person.id) { openProfile?(person) }
            }
        }) {
            NavigationStack { CommentDraftView(clip: clip) }.overlay { NoticeLayer() }.presentationDetents([.medium, .large])
                .environment(\.profileSheetAction, { person in
                    pendingProfile = person
                    showComments = false
                })
        }
        .sheet(isPresented: $showOptions) {
            VideoOptionsView(clip: clip)
        }
    }

}

struct VideoEngagementActions: View {
    var clip: FoodFilm
    var tint: Color = .white
    var onPaper = false
    var onComment: () -> Void
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder var body: some View {
        if store.isClipVisible(clip) {
            let layout = onPaper && dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: onPaper ? 8 : 14))
            layout {
                Button { store.toggleLike(clip.id) } label: {
                    HStack(spacing: 4) {
                        Art(name: onPaper || store.account.likes.contains(clip.id) ? "heart" : "like-video", width: 22, height: 22)
                        Text(store.likeCount(for: clip).formatted()).font(.tati(.caption).weight(.medium)).monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                    }.padding(.horizontal, onPaper ? 12 : 0).frame(minWidth: 44, minHeight: 44)
                        .background(onPaper ? (store.account.likes.contains(clip.id) ? Color.tatiPink.opacity(0.28) : Color.tatiCream) : Color.clear, in: Capsule())
                }.buttonStyle(FoodFilmPressStyle())
                    .accessibilityLabel(store.account.likes.contains(clip.id) ? "Unlike video" : "Like video")
                    .accessibilityValue("\(store.likeCount(for: clip)) likes")
                    .accessibilityAddTraits(store.account.likes.contains(clip.id) ? .isSelected : [])
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        if onPaper { Art(name: "discovery-messages", width: 24, height: 24) }
                        else { SupplementIcon(icon: .comment, size: 21, tint: tint) }
                        Text(store.commentCount(for: clip).formatted()).font(.tati(.caption).weight(.medium)).monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                    }.padding(.horizontal, onPaper ? 12 : 0).frame(minWidth: 44, minHeight: 44)
                        .background(onPaper ? Color.tatiCream : Color.clear, in: Capsule())
                }.buttonStyle(FoodFilmPressStyle()).accessibilityLabel("\(store.commentCount(for: clip)) comments")
            }.foregroundStyle(tint)
        }
    }
}

struct VideoAuthor: View {
    var clip: FoodFilm
    var size: CGFloat = 36
    var showsFollow = true
    @EnvironmentObject private var store: MemberKitchenStore
    var body: some View {
        Group {
            if let person = TableCommunity.person(clip.authorID) {
                HStack(spacing: 2) {
                    NavigationLink(destination: PersonProfileView(person: person)) {
                        HStack(spacing: 7) {
                            Avatar(asset: person.portraitArtwork, size: size)
                            Text(person.name).font(.tati(size: 14, weight: .semibold)).lineLimit(showsFollow ? 1 : 2)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("View " + person.name)
                    if showsFollow { FollowControl(userID: person.id) }
                }
            } else {
                HStack(spacing: 7) {
                    Avatar(file: store.account.profile.avatarFile, size: size, isCurrent: true)
                    Text(store.authorName(for: clip)).font(.tati(size: 14, weight: .semibold)).lineLimit(1)
                }
            }
        }
    }
}

struct FoodFilmPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct VideoOptionsView: View {
    var clip: FoodFilm
    var body: some View {
        SafetyActionsView(subjectID: "video:" + clip.id, authorID: clip.authorID)
    }
}

struct SafetyActionsView: View {
    var subjectID: String
    var authorID: String
    var contextID: String? = nil
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var reporting = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Text("Manage content").font(.tati(size: 18, weight: .bold, design: .serif))
                    Spacer()
                    ArtButton(asset: "close-light", label: "Close") { dismiss() }
                }
                HStack(spacing: 28) {
                    if authorID != store.account.profile.id {
                        ImageAction(asset: "block-button", label: "Block user", height: 76) { store.block(authorID) }
                    }
                    ImageAction(asset: "report-button", label: "Report content", height: 76) { reporting = true }
                }.padding(.bottom, 16)
            }.padding(.horizontal, 22).frame(maxWidth: 420).frame(maxWidth: .infinity)
                .foregroundStyle(Color.tatiInk).background(Color.tatiCream).tatiScreen()
                .navigationDestination(isPresented: $reporting) {
                    ReportView(subjectID: subjectID, authorID: authorID, contextID: contextID)
                }
        }
        .presentationBackground(Color.tatiCream).presentationCornerRadius(22)
        .presentationDetents(reporting || store.notice != nil || dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(190), .large])
        .presentationDragIndicator(.hidden)
        .overlay { NoticeLayer() }
        .onChange(of: store.account.blocked) { _, blocked in if blocked.contains(authorID) { dismiss() } }
        .onChange(of: store.account.hiddenSubjects) { _, _ in
            if store.isHidden(subjectID) || store.isPersonHidden(authorID) { dismiss() }
        }
    }
}
