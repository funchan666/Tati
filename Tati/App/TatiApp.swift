import SwiftUI

@main
struct TatiApp: App {
    @UIApplicationDelegateAdaptor(TableApplicationDelegate.self) private var appDelegate
    @StateObject private var session = TableSessionCoordinator()
    @StateObject private var store = MemberKitchenStore()
    @StateObject private var playback = FoodFilmPlayback()
    @StateObject private var purchases = KitchenCoinPurchases()
    @StateObject private var roomSession = CookingRoomSession()
    @StateObject private var notifications = NotificationPreferences()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if session.route == .showingA {
                        CommunityRoot(content: session.content).id(store.account.profile.id)
                    } else if session.route != .showingB {
                        WelcomeView()
                    }
                }
                TableWebLayer(owner: session.web, visible: session.route == .showingB)
                NoticeLayer(isRoot: true)
            }
            .background { Color.tatiCream.ignoresSafeArea(.container) }
            .environmentObject(store).environmentObject(playback).environmentObject(purchases).environmentObject(roomSession)
            .environmentObject(notifications).environmentObject(session)
            .environment(\.locale, AppLanguage.preference(store.account.preferredLanguage).locale)
            .font(.tati(.body))
            .tint(.tatiPink).preferredColorScheme(.light)
            .task { session.install(store: store, purchases: purchases, playback: playback, roomSession: roomSession); notifications.refresh(store: store) }
            .onOpenURL { session.wake($0) }
            .onChange(of: scenePhase) { _, phase in
                session.becameActive(phase == .active)
                if phase != .active { store.flushDrafts() }
                if phase == .background { roomSession.audio.stop(); playback.stop() }
                if phase == .active { notifications.refresh(store: store) }
            }
            .onChange(of: store.account.notifications) { _, _ in notifications.refresh(store: store) }
            .onChange(of: store.account.preferredLanguage) { _, _ in notifications.refresh(store: store) }
            .onChange(of: store.account.blocked) { _, _ in hideUnavailableRoom() }
            .onChange(of: store.account.tableSyncState?.hiddenFilmIDs) { _, _ in hideUnavailableRoom() }
            .onChange(of: store.account.hiddenSubjects) { _, _ in hideUnavailableRoom() }
            .onChange(of: store.account.signedIn) { _, signedIn in
                if !signedIn { playback.stop(); roomSession.leave(); session.signedOut() }
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
    @ObservedObject var content: KitchenContentRepository
    @EnvironmentObject private var playback: FoodFilmPlayback
    @State private var selected = TatiSection.home
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if !content.loaded && selected != .me { KitchenContentStatus(content: content) }
                    else { switch selected {
                    case .home: DiscoverView(voice: false)
                    case .room: DiscoverView(voice: true)
                    case .video: VideoFeedView()
                    case .notes: CookingNotesView()
                    case .me: MyProfileView()
                    } }
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
    @EnvironmentObject private var session: TableSessionCoordinator
    @State private var consent = false
    @State private var manualConsent = false
    private var entering: Bool { session.entering }
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 14) {
                        if let error = store.storageFailure { Text(error).font(.tati(.footnote)).foregroundStyle(Color.tatiInk) }
                        if let error = session.errorText { Text(error).font(.tati(.footnote)).foregroundStyle(Color.tatiInk).multilineTextAlignment(.center) }
                        if session.route == .webFailure {
                            TatiButton(title: "Try again", enabled: !entering) { session.retryWeb() }
                            Button("Return to welcome") { session.returnToWelcome() }.buttonStyle(.plain).frame(minHeight: 44)
                        } else {
                            WelcomeEntryButton(loading: entering, enabled: store.storageFailure == nil) {
                                guard !entering, store.storageFailure == nil else { return }
                                guard consent else {
                                    store.tell("Agreement required", "Please read and agree to the User Agreement and Privacy Policy before signing in.")
                                    return
                                }
                                session.begin()
                            }
                        }
                        HStack(alignment: .center, spacing: 8) {
                            Button { manualConsent = true; consent.toggle() } label: {
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
                }.frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                }
                    .background {
                        GeometryReader { backdrop in
                            Image("welcome").resizable().scaledToFill()
                                .frame(width: backdrop.size.width, height: backdrop.size.height).clipped()
                        }.ignoresSafeArea(.container)
                    }
            }.tatiScreen()
        }
        .onChange(of: session.route, initial: true) { _, route in
            guard !manualConsent else { return }
            if route == .preparingB || route == .showingB { consent = true }
            else if route == .undecided { consent = false }
        }
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

private struct TableWebLayer: View {
    @ObservedObject var owner: SupperWebOwner
    let visible: Bool
    var body: some View {
        Group {
            if let view = owner.webView {
                SupperWebSurface(view: view).ignoresSafeArea(.container)
                    .opacity(visible ? 1 : 0).allowsHitTesting(visible).accessibilityHidden(!visible)
            }
        }
    }
}
private struct KitchenContentStatus: View {
    @ObservedObject var content: KitchenContentRepository
    var body: some View {
        VStack(spacing: 18) {
                Art(name: "brand-heading", width: 132, height: 62)
                EmptyContent(title: content.failure ? "The kitchen couldn't load" : "Setting your table…", detail: content.failure ? "Check your connection, then try again." : "Bringing food stories and cooking notes to your table.")
                if content.failure { TatiButton(title: "Try again") { content.reload() }.frame(maxWidth: 280) }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
