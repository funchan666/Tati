import SwiftUI

/// The room menu has two rows of tools; its sheet follows the actual content.
struct RoomToolsPanel: View {
    var isVoice: Bool
    var select: (RoomPanel) -> Void
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 40
    @State private var contentHeight: CGFloat = 260

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Room tools").font(.system(size: 18, weight: .bold, design: .serif))
                    Spacer(minLength: 0)
                    ArtButton(asset: "close-light", label: "Close room tools", size: 22) { dismiss() }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                    if isVoice { tool("tool-layout", "Room layout", .layout) }
                    tool("tool-mic", "Mic queue", .microphone)
                    tool("tool-music", "Music", .music)
                    tool("tool-background", "Background", .background)
                    tool("tool-invite", "Invite", .invite)
                    if !isVoice { tool("feedback", "Report / block", .safety) }
                    tool("tool-leave", "Leave", .leave)
                }
                if isVoice {
                    HStack {
                        Spacer(minLength: 0)
                        Button { select(.safety) } label: {
                            HStack(spacing: 6) {
                                Art(name: "feedback", width: 14, height: 16)
                                Text("Report or block").font(.caption)
                            }
                            .padding(.horizontal, 8).frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).foregroundStyle(Color.tatiOlive)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 8)
            .frame(maxWidth: 520).frame(maxWidth: .infinity)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: RoomPanelContentHeightKey.self, value: geometry.size.height)
                }
            }
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Color.tatiInk)
        .background { Color.tatiLime.ignoresSafeArea(.container) }
        .presentationBackground(Color.tatiLime)
        .presentationCornerRadius(22)
        .presentationDragIndicator(.hidden)
        .presentationDetents([.height(contentHeight)])
        .onPreferenceChange(RoomPanelContentHeightKey.self) { height in
            guard height > 0, abs(height - contentHeight) > 1 else { return }
            contentHeight = height
        }
        .accessibilityAction(.escape) { dismiss() }
    }

    private func tool(_ art: String, _ title: String, _ destination: RoomPanel) -> some View {
        Button { select(destination) } label: {
            VStack(spacing: 5) {
                if destination == .safety {
                    Art(name: art, width: iconSize * 0.6, height: iconSize * 0.6)
                        .frame(width: iconSize, height: iconSize)
                        .background(Color.tatiCream, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Art(name: art, width: iconSize, height: iconSize)
                }
                Text(title).font(.caption).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

private struct RoomPanelContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Lanhu's compact exit actions, sized independently of the taller room tools.
struct RoomLeavePanel: View {
    var isVoice: Bool
    var minimize: () -> Void
    var leave: () -> Void
    var stay: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var actionFontSize: CGFloat = 14
    @State private var contentHeight: CGFloat = 220

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("Leave the room?").font(.system(size: 17, weight: .bold, design: .serif))
                    Spacer(minLength: 0)
                    ArtButton(asset: "close-light", label: "Stay in room", size: 20, action: stay)
                }
                VStack(spacing: 8) {
                    if isVoice { action("Keep listening - Minimize", primary: true, perform: minimize) }
                    action("Leave room", primary: !isVoice, perform: leave)
                    action("Stay here", primary: false, perform: stay)
                }
            }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: RoomPanelContentHeightKey.self, value: geometry.size.height)
                    }
                }
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Color.tatiInk)
        .background { Color.tatiLime.ignoresSafeArea(.container) }
        .presentationBackground(Color.tatiLime)
        .presentationDetents([.height(contentHeight)])
        .presentationCornerRadius(20)
        .presentationDragIndicator(.hidden)
        .onPreferenceChange(RoomPanelContentHeightKey.self) { height in
            guard height > 0, abs(height - contentHeight) > 1 else { return }
            contentHeight = height
        }
        .accessibilityAction(.escape) { stay() }
    }

    private func action(_ title: String, primary: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.system(size: actionFontSize, weight: .regular))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.white)
                .background(primary ? Color.tatiPink : Color.tatiOlive.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
}

struct RoomActivityFeed: View {
    var room: FoodRoom
    var isActive: Bool
    var maximumHeight: CGFloat = 160
    var maximumWidth: CGFloat = 320
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var entries: [RoomActivity] {
        var local: [(Date, RoomActivity)] = (store.account.roomMessages ?? [])
            .filter { $0.roomID == room.id }
            .map { message in
                (message.createdAt, RoomActivity(id: message.id, authorID: store.account.profile.id, text: message.text, isSample: false))
            }
        local += store.account.gifts.filter { $0.roomID == room.id }.map { receipt in
            (receipt.date, RoomActivity(id: receipt.id, authorID: store.account.profile.id, text: "", giftID: receipt.giftID, quantity: receipt.quantity, isSample: false))
        }
        local.sort { $0.0 == $1.0 ? $0.1.id < $1.1.id : $0.0 < $1.0 }
        return local.suffix(100).map { $0.1 }.filter { !store.isPersonHidden($0.authorID) && !store.isHidden("roomMessage:" + $0.id) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        ForEach(entries) { entry in
                            UserProfileLink(userID: entry.authorID) { activityRow(entry) }.id(entry.id)
                                .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
                        }
                    }.padding(.vertical, 3)
                }.scrollIndicators(.hidden)
                .onAppear { if let last = entries.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                .onChange(of: entries.map(\.id)) { _, _ in
                    guard let last = entries.last else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .foregroundStyle(.white).frame(maxWidth: maximumWidth, maxHeight: maximumHeight, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)

    }
    @ViewBuilder private func activityRow(_ entry: RoomActivity) -> some View {
        let person = FoodCatalog.person(entry.authorID)
        let current = !entry.isSample && entry.authorID == store.account.profile.id
        let name = current ? "\(store.account.profile.name) · You" : person?.name ?? "Guest"
        if let giftID = entry.giftID, let gift = FoodCatalog.gift(giftID) {
            HStack(spacing: 7) {
                Avatar(file: current ? store.account.profile.avatarFile : nil, asset: person?.portraitArtwork, size: 24, isCurrent: current)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.tatiCream).lineLimit(1)
                    Text(gift.name)
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Art(name: gift.artwork, width: 32, height: 32)
                Text("×\(entry.quantity)").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            }.padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: 260)
                .background(.black.opacity(0.56)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.tatiPink.opacity(0.45), lineWidth: 0.7) }
                .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .center, spacing: 6) {
                Avatar(file: current ? store.account.profile.avatarFile : nil, asset: person?.portraitArtwork, size: 22, isCurrent: current)
                (Text(name + ": ").fontWeight(.medium).foregroundColor(.tatiCream) + Text(entry.text))
                    .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 8).padding(.vertical, 5)
                .background(.black.opacity(0.52)).clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
        }
    }
}

struct RoomLayoutPanel: View {
    var current: String
    var choose: (String) -> Void
    @State private var mode = "Voice"
    private let videoLayouts = [("Spotlight + voices", "1 video + 8 voice"), ("Duo video + voices", "2 video + 6 voice"), ("Three video + voices", "3 video + 6 voice")]
    var body: some View {
        TatiPanel(title: "Room Layout") {
            HStack(spacing: 12) {
                TatiButton(title: "Voice", secondary: mode != "Voice") { mode = "Voice" }
                TatiButton(title: "Video + Voice", secondary: mode != "Video + Voice") { mode = "Video + Voice" }
            }
            if mode == "Voice" { layout("10-seat voice room", "10 voice seats") }
            else { ForEach(videoLayouts.indices, id: \.self) { index in layout(videoLayouts[index].0, videoLayouts[index].1) } }
        }.onAppear { mode = current == "10-seat voice room" ? "Voice" : "Video + Voice" }
    }
    private func layout(_ name: String, _ subtitle: String) -> some View {
        Button { choose(name) } label: {
            HStack(spacing: 14) {
                Art(name: "layout-seat", width: 32, height: 32)
                VStack(alignment: .leading, spacing: 5) { Text(name).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true); Text(subtitle).font(.system(size: 11)) }
                Spacer()
                if current == name { Text("Current").font(.system(size: 10)).fixedSize() }
                else { Art(name: "chevron", width: 14) }
            }.padding(12).foregroundStyle(current == name ? Color.tatiInk : .white)
                .background(current == name ? Color.yellow.opacity(0.65) : Color.tatiOlive).clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).accessibilityAddTraits(current == name ? .isSelected : [])
    }
}
struct RoomPersonPanel: View {
    var person: FoodPerson
    var roomMember = false
    var roomID: String? = nil
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPanel(title: roomMember ? "Room member" : "Host") {
            UserProfileLink(userID: person.id) {
                VStack(spacing: 10) {
                    Avatar(asset: person.portraitArtwork, size: 60)
                    Text(person.name).font(.system(size: 17, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
                    Text(person.city).font(.system(size: 11))
                }.frame(maxWidth: .infinity)
            }
            HStack(spacing: 10) {
                NavigationLink(destination: PersonProfileView(person: person)) { panelLink("Profile") }
                if roomMember {
                    NavigationLink(destination: GiftShopView(recipient: person, roomID: roomID)) {
                        Text("Gifts").font(.system(size: 14)).frame(maxWidth: .infinity, minHeight: 42).background(Color.tatiPink).foregroundStyle(.white).clipShape(Capsule())
                    }
                } else {
                    NavigationLink(destination: ConversationView(person: person)) { panelLink("Message") }
                    TatiButton(title: store.account.following.contains(person.id) ? "Following" : "Follow") { store.toggleFollow(person.id) }
                }
            }.buttonStyle(.plain).padding(.top, 8)
        }
    }
    private func panelLink(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).frame(maxWidth: .infinity, minHeight: 42).background(Color.tatiOlive.opacity(0.65)).foregroundStyle(.white).clipShape(Capsule())
    }
}
struct RoomInvitePanel: View {
    var room: FoodRoom
    @EnvironmentObject private var store: VisitorStore
    private var following: [FoodPerson] { store.visiblePeople.filter { store.account.following.contains($0.id) && !store.account.blocked.contains($0.id) } }
    var body: some View {
        TatiPanel(title: "Invite friends") {
            if following.isEmpty { EmptyContent(title: "No followed profiles", detail: "Follow a profile to find it here.", artwork: "tool-invite") }
            ForEach(following) { person in
                HStack {
                    NavigationLink(destination: PersonProfileView(person: person)) { HStack { Avatar(asset: person.portraitArtwork); Text(person.name).font(.headline) } }.buttonStyle(.plain)
                    Spacer()
                    TatiButton(title: "Invite", secondary: true) { store.tell("Invitation unavailable", "Invitations are currently unavailable. No invitation was sent.") }.frame(width: 100)
                }
            }
        }
    }
}
struct RoomSoundButton: View {
    @ObservedObject var player: LocalRoomAudio
    var body: some View {
        ArtButton(asset: "chat-speaker", label: player.muted ? "Unmute music" : "Mute music", size: 30) { player.toggleMuted() }
            .opacity(player.muted ? 0.45 : 1)
    }
}
