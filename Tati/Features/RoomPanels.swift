import SwiftUI

struct RoomActivityFeed: View {
    var room: FoodRoom
    var isActive: Bool
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedSamples = 4
    private var samples: [RoomActivity] {
        RoomActivity.samples(for: room).filter { !store.account.blocked.contains($0.authorID) }
    }
    private var advancesSamples: Bool { isActive && scenePhase == .active && !reduceMotion }
    private var entries: [RoomActivity] {
        let sampleEntries = reduceMotion ? samples : Array(samples.prefix(revealedSamples))
        var local: [(Date, RoomActivity)] = (store.account.roomMessages ?? [])
            .filter { $0.roomID == room.id }
            .map { message in
                (message.createdAt, RoomActivity(id: message.id, authorID: store.account.profile.id, text: message.text, isSample: false))
            }
        local += store.account.gifts.filter { $0.roomID == room.id }.map { receipt in
            (receipt.date, RoomActivity(id: receipt.id, authorID: store.account.profile.id, text: "", giftID: receipt.giftID, quantity: receipt.quantity, isSample: false))
        }
        local.sort { $0.0 == $1.0 ? $0.1.id < $1.1.id : $0.0 < $1.0 }
        return sampleEntries + local.suffix(100).map { $0.1 }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Room highlights")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.black.opacity(0.45)).clipShape(Capsule())
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(entries) { entry in
                            activityRow(entry).id(entry.id)
                                .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
                        }
                    }.padding(.vertical, 3)
                }
                .onAppear { if let last = entries.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                .onChange(of: entries.map(\.id)) { _, _ in
                    guard let last = entries.last else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .foregroundStyle(.white).frame(maxWidth: 430, maxHeight: 190, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
        .task(id: room.id + (advancesSamples ? "-active" : "-paused")) {
            guard advancesSamples else { return }
            // Finite sample script; never writes receipts, balances or memberships.
            while revealedSamples < samples.count {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { revealedSamples += 1 }
            }
        }
    }
    @ViewBuilder private func activityRow(_ entry: RoomActivity) -> some View {
        let person = FoodCatalog.person(entry.authorID)
        let current = !entry.isSample && entry.authorID == store.account.profile.id
        let name = current ? "\(store.account.profile.name) · You" : person?.name ?? "Guest"
        if let giftID = entry.giftID, let gift = FoodCatalog.gift(giftID) {
            HStack(spacing: 7) {
                Avatar(file: current ? store.account.profile.avatarFile : nil, asset: person?.portraitArtwork, size: 26, isCurrent: current)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.tatiLime)
                    Text(entry.isSample ? "\(gift.name)" : "Saved \(gift.name)")
                        .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Art(name: gift.artwork, width: 38, height: 38)
                Text("×\(entry.quantity)").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.tatiLime)
            }.padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color.tatiOlive.opacity(0.85)).clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .top, spacing: 6) {
                Avatar(file: current ? store.account.profile.avatarFile : nil, asset: person?.portraitArtwork, size: 22, isCurrent: current)
                (Text(name + ": ").fontWeight(.semibold).foregroundColor(.tatiLime) + Text(entry.text))
                    .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 8).padding(.vertical, 5)
                .background(.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 8))
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
            Note(text: "Choose a room layout. Joining a microphone seat is currently unavailable.")
        }.onAppear { mode = current == "10-seat voice room" ? "Voice" : "Video + Voice" }
    }
    private func layout(_ name: String, _ subtitle: String) -> some View {
        Button { choose(name) } label: {
            HStack(spacing: 14) {
                Art(name: "layout-seat", width: 32, height: 32)
                VStack(alignment: .leading, spacing: 5) { Text(name).font(.headline); Text(subtitle).font(.caption) }
                Spacer()
                if current == name { Text("Current").font(.caption.bold()) }
                else { Art(name: "chevron", width: 14) }
            }.padding(16).foregroundStyle(current == name ? Color.tatiInk : .white)
                .background(current == name ? Color.yellow.opacity(0.65) : Color.tatiOlive).clipShape(RoundedRectangle(cornerRadius: 18))
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
            VStack(spacing: 10) {
                Avatar(asset: person.portraitArtwork, size: 76)
                Text(person.name).font(.title2.bold())
                Text(person.city).font(.subheadline)
                Note(text: person.interest)
            }.frame(maxWidth: .infinity)
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
    private var following: [FoodPerson] { FoodCatalog.people.filter { store.account.following.contains($0.id) && !store.account.blocked.contains($0.id) } }
    var body: some View {
        TatiPanel(title: "Invite friends") {
            Note(text: "Invite friends to \(room.title). Invitations are currently unavailable.")
            if following.isEmpty { EmptyContent(title: "No followed profiles", detail: "Profiles you choose to follow will appear here. Nobody is added automatically.", artwork: "tool-invite") }
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
