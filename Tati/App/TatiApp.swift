import SwiftUI

@main
struct TatiApp: App {
    @StateObject private var store = VisitorStore()
    @StateObject private var playback = ClipPlayback()
    @StateObject private var purchases = TatiPurchases()
    @StateObject private var roomSession = RoomPreviewSession()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ZStack {
                if store.account.signedIn { CommunityRoot().id(store.account.profile.id) }
                else { WelcomeView() }
                NoticeLayer()
            }
            .background { Color.tatiCream.ignoresSafeArea(.container) }
            .environmentObject(store).environmentObject(playback).environmentObject(purchases).environmentObject(roomSession)
            .tint(.tatiPink).preferredColorScheme(.light)
            .onChange(of: scenePhase) { _, phase in if phase == .background { roomSession.audio.stop(); playback.stop() } }
            .onChange(of: store.account.blocked) { _, _ in hideUnavailableRoom() }
            .onChange(of: store.account.hiddenSubjects) { _, _ in hideUnavailableRoom() }
            .onChange(of: store.account.signedIn) { _, signedIn in if !signedIn { playback.stop(); roomSession.leave() } }
        }
    }
    private func hideUnavailableRoom() {
        if let room = roomSession.room, !store.visibleRooms.contains(where: { $0.id == room.id }) {
            roomSession.leave(); playback.stop()
        }
    }

}
enum CommunityTab: String, CaseIterable {
    case home = "Home", room = "Room", video = "Video", ai = "AI", me = "Me"
    var assetPrefix: String { rawValue.lowercased() }
}
struct CommunityRoot: View {
    @EnvironmentObject private var playback: ClipPlayback
    @State private var selected = CommunityTab.home
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    switch selected {
                    case .home: DiscoverView(voice: false)
                    case .room: DiscoverView(voice: true)
                    case .video: VideoFeedView()
                    case .ai: FoodExpertView()
                    case .me: MyProfileView()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                MinimizedRoomBar()
                HStack(spacing: 0) {
                    ForEach(CommunityTab.allCases, id: \.self) { tab in
                        Button {
                            playback.stop(); selected = tab
                        } label: {
                            Art(name: "\(tab.assetPrefix)-\(tab == selected ? "on" : "off")", width: 27, height: 27)
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }.buttonStyle(.plain).accessibilityLabel(tab.rawValue).accessibilityAddTraits(tab == selected ? .isSelected : [])
                    }
                }.padding(.top, 4).padding(.bottom, 6).background {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .fill(Color.tatiPink).ignoresSafeArea(edges: .bottom)
                }
            }.background(selected == .ai ? Color.white : Color.tatiCream).tatiScreen()
        }
    }
}
struct WelcomeView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var consent = false
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 14) {
                        if let error = store.storageFailure { Text(error).font(.footnote).foregroundStyle(Color.tatiInk) }
                        TatiButton(title: "Enter Tati", enabled: consent && store.storageFailure == nil) { store.signIn() }
                        HStack(alignment: .center, spacing: 8) {
                            Button { consent.toggle() } label: {
                                if consent { Art(name: "check-pink", width: 24, height: 24) }
                                else { SupplementIcon(icon: .toggleOff, size: 28) }
                            }.buttonStyle(.plain).frame(width: 44, height: 44).accessibilityLabel(consent ? "Agreement accepted" : "Accept agreement").accessibilityAddTraits(consent ? .isSelected : [])
                            VStack(alignment: .leading, spacing: 3) {
                                Text("I agree to the").font(.caption)
                                HStack(spacing: 6) {
                                    NavigationLink("Terms", destination: PolicyView(kind: .terms))
                                    Text("and")
                                    NavigationLink("Privacy Policy", destination: PolicyView(kind: .privacy))
                                }.font(.caption).foregroundStyle(Color.tatiOlive)
                            }
                        }.foregroundStyle(Color.tatiInk)
                    }.padding(.horizontal, 26).padding(.bottom, 12)
                }.frame(width: geo.size.width, height: geo.size.height)
                    .background {
                        GeometryReader { backdrop in
                            Image("welcome").resizable().scaledToFill()
                                .frame(width: backdrop.size.width, height: backdrop.size.height).clipped()
                        }.ignoresSafeArea(.container)
                    }
            }.tatiScreen()
        }
    }
}
