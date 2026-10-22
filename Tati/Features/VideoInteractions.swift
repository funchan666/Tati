import SwiftUI

struct FeedVideoCard: View {
    var clip: FoodClip
    @EnvironmentObject private var store: VisitorStore
    @State private var showComments = false
    @State private var pendingProfile: FoodPerson?
    @Environment(\.profilePageAction) private var openProfile
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
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            VideoAuthor(clip: clip, size: 32).fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 4)
                            VideoEngagementActions(clip: clip) { showComments = true }.fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            VideoAuthor(clip: clip, size: 32)
                            VideoEngagementActions(clip: clip) { showComments = true }
                        }
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
    var clip: FoodClip
    var tint: Color = .white
    var onComment: () -> Void
    @EnvironmentObject private var store: VisitorStore

    @ViewBuilder var body: some View {
        if store.isClipVisible(clip) {
            HStack(spacing: 14) {
                Button { store.toggleLike(clip.id) } label: {
                    HStack(spacing: 4) {
                        Art(name: store.account.likes.contains(clip.id) ? "heart" : "like-video", width: 22, height: 22)
                        Text(store.likeCount(for: clip).formatted()).font(.caption.weight(.medium)).monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                    }.frame(minWidth: 44, minHeight: 44)
                }.buttonStyle(.plain)
                    .accessibilityLabel(store.account.likes.contains(clip.id) ? "Unlike video" : "Like video")
                    .accessibilityValue("\(store.likeCount(for: clip)) likes")
                    .accessibilityAddTraits(store.account.likes.contains(clip.id) ? .isSelected : [])
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        SupplementIcon(icon: .comment, size: 21, tint: tint)
                        Text(store.commentCount(for: clip).formatted()).font(.caption.weight(.medium)).monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                    }.frame(minWidth: 44, minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("\(store.commentCount(for: clip)) comments")
            }.foregroundStyle(tint)
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
                HStack(spacing: 2) {
                    NavigationLink(destination: PersonProfileView(person: person)) {
                        HStack(spacing: 7) {
                            Avatar(asset: person.portraitArtwork, size: size)
                            Text(person.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("View " + person.name)
                    FollowControl(userID: person.id)
                }
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
    var clip: FoodClip
    var body: some View {
        SafetyActionsView(subjectID: "video:" + clip.id, authorID: clip.authorID)
    }
}

/// Shared report/block surface for profiles, posts, comments, messages and rooms.
struct SafetyActionsView: View {
    var subjectID: String
    var authorID: String
    var contextID: String? = nil
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var reporting = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Text("Manage content").font(.system(size: 18, weight: .bold, design: .serif))
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
