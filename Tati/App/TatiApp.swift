import SwiftUI

@main
struct TatiApp: App {
    @StateObject private var store = MemberKitchenStore()
    @StateObject private var playback = FoodFilmPlayback()
    @StateObject private var purchases = KitchenCoinPurchases()
    @StateObject private var roomSession = CookingRoomSession()
    @StateObject private var notifications = NotificationPreferences()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ZStack {
                if store.account.signedIn { CommunityRoot().id(store.account.profile.id) }
                else { WelcomeView() }
                if store.account.signedIn && store.account.welcomeGranted == true && store.account.welcomeAcknowledged == false {
                    WelcomeCoinsView()
                }
                NoticeLayer(isRoot: true)
            }
            .background { Color.tatiCream.ignoresSafeArea(.container) }
            .environmentObject(store).environmentObject(playback).environmentObject(purchases).environmentObject(roomSession)
            .environmentObject(notifications)
            .environment(\.locale, AppLanguage.preference(store.account.preferredLanguage).locale)
            .font(.tati(.body))
            .tint(.tatiPink).preferredColorScheme(.light)
            .task { purchases.start(store: store); notifications.refresh(store: store) }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { store.flushDrafts() }
                if phase == .background { roomSession.audio.stop(); playback.stop() }
                if phase == .active { notifications.refresh(store: store) }
            }
            .onChange(of: store.account.notifications) { _, _ in notifications.refresh(store: store) }
            .onChange(of: store.account.preferredLanguage) { _, _ in notifications.refresh(store: store) }
            .onChange(of: store.account.blocked) { _, _ in hideUnavailableRoom() }
            .onChange(of: store.account.hiddenSubjects) { _, _ in hideUnavailableRoom() }
            .onChange(of: store.account.signedIn) { _, signedIn in
                if !signedIn { playback.stop(); roomSession.leave() }
                notifications.refresh(store: store)
            }
        }
    }
    private func hideUnavailableRoom() {
        if let room = roomSession.room, !store.visibleRooms.contains(where: { $0.id == room.id }) {
            roomSession.leave(); playback.stop()
        }
    }

}
enum TatiSection: String, CaseIterable {
    case home = "Home", room = "Room", video = "Video", notes = "Cooking notes", me = "Me"
    var assetPrefix: String { self == .notes ? "notes" : rawValue.lowercased() }
}
struct CommunityRoot: View {
    @EnvironmentObject private var playback: FoodFilmPlayback
    @State private var selected = TatiSection.home
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    switch selected {
                    case .home: DiscoverView(voice: false)
                    case .room: DiscoverView(voice: true)
                    case .video: VideoFeedView()
                    case .notes: CookingNotesView()
                    case .me: MyProfileView()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                MinimizedRoomBar()
                HStack(spacing: 0) {
                    ForEach(TatiSection.allCases, id: \.self) { tab in
                        Button {
                            guard selected != tab else { return }
                            playback.stop(); selected = tab
                        } label: {
                            Art(name: "\(tab.assetPrefix)-\(tab == selected ? "on" : "off")", width: 27, height: 27)
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }.buttonStyle(.plain).accessibilityLabel(LocalizedStringKey(tab.rawValue)).accessibilityAddTraits(tab == selected ? .isSelected : [])
                    }
                }.padding(.top, 4).padding(.bottom, 6).background {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .fill(Color.tatiPink).ignoresSafeArea(edges: .bottom)
                }
            }.background { Color.tatiCream.ignoresSafeArea(.container) }.tatiScreen()
        }
    }
}
struct WelcomeView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var consent = false
    @State private var entering = false
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 14) {
                        if let error = store.storageFailure { Text(error).font(.tati(.footnote)).foregroundStyle(Color.tatiInk) }
                        WelcomeEntryButton(loading: entering, enabled: consent && store.storageFailure == nil) {
                            guard !entering, consent, store.storageFailure == nil else { return }
                            entering = true
                        }
                        HStack(alignment: .center, spacing: 8) {
                            Button { consent.toggle() } label: {
                                if consent { Art(name: "check-pink", width: 24, height: 24) }
                                else { SupplementIcon(icon: .toggleOff, size: 28) }
                            }.buttonStyle(.plain).frame(width: 44, height: 44).accessibilityLabel(consent ? "Agreement accepted" : "Accept agreement").accessibilityAddTraits(consent ? .isSelected : [])
                            VStack(alignment: .leading, spacing: 3) {
                                Text("I agree to the").font(.tati(.caption))
                                HStack(spacing: 6) {
                                    NavigationLink("Terms", destination: PolicyView(kind: .terms))
                                    Text("and")
                                    NavigationLink("Privacy Policy", destination: PolicyView(kind: .privacy))
                                }.font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                            }
                        }.foregroundStyle(Color.tatiInk).disabled(entering)
                    }.frame(maxWidth: 460).padding(.horizontal, 26).padding(.bottom, 12)
                }.frame(width: geo.size.width, height: geo.size.height)
                    .background {
                        GeometryReader { backdrop in
                            Image("welcome").resizable().scaledToFill()
                                .frame(width: backdrop.size.width, height: backdrop.size.height).clipped()
                        }.ignoresSafeArea(.container)
                    }
            }.tatiScreen()
        }
        .task(id: entering) {
            guard entering else { return }
            // A brief acknowledgment lets the loading state render before the existing
            // synchronous local sign-in transaction. This is not a network progress meter.
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard !Task.isCancelled, entering, consent, scenePhase == .active else { return }
            store.signIn()
            entering = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { entering = false }
        }
        .onDisappear { entering = false }
    }
}

private struct WelcomeEntryButton: View {
    let loading: Bool
    let enabled: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if loading {
                    Art(name: "chef-avatar", width: 32, height: 32)
                        .scaleEffect(reduceMotion ? 1 : breathing ? 1.08 : 0.94)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: breathing)
                        .onAppear { breathing = !reduceMotion }
                        .onDisappear { breathing = false }
                }
                Text(LocalizedStringKey(loading ? "Entering Tati…" : "Enter Tati"))
                    .font(.tati(.headline)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Color.tatiInk)
            .background(Color.tatiPink, in: Capsule())
            .opacity(enabled || loading ? 1 : 0.48)
        }
        .buttonStyle(.plain).disabled(!enabled || loading)
        .accessibilityLabel(loading ? Text("Entering Tati…") : Text("Enter Tati"))
        .onChange(of: reduceMotion) { _, reduced in breathing = loading && !reduced }
    }
}
