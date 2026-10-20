import SwiftUI

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
            Note(text: "Choose a room layout. Seats are available when the live service is connected.")
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
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPanel(title: roomMember ? "Room member" : "Host") {
            VStack(spacing: 10) {
                Avatar(asset: person.portraitArtwork, size: 76)
                Text(person.name).font(.title2.bold())
                Text(person.city).font(.subheadline)
                Note(text: "Sample profile · not connected")
            }.frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                NavigationLink(destination: PersonProfileView(person: person)) { panelLink("Profile") }
                if roomMember {
                    NavigationLink(destination: GiftShopView(recipient: person)) {
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
            Note(text: "Invite people to \(room.title). Sample profiles cannot receive invitations; a connected room link is required.")
            if following.isEmpty { EmptyContent(title: "No followed profiles", detail: "Profiles you choose to follow will appear here. Nobody is added automatically.", artwork: "tool-invite") }
            ForEach(following) { person in
                HStack {
                    NavigationLink(destination: PersonProfileView(person: person)) { HStack { Avatar(asset: person.portraitArtwork); Text(person.name).font(.headline) } }.buttonStyle(.plain)
                    Spacer()
                    TatiButton(title: "Invite", secondary: true) { store.tell("Invitation unavailable", "No invitation was sent. This sample profile and room are not connected to a service.") }.frame(width: 100)
                }
            }
        }
    }
}
struct RoomSoundButton: View {
    @ObservedObject var player: LocalRoomAudio
    var body: some View {
        ArtButton(asset: "chat-speaker", label: player.muted ? "Unmute local music" : "Mute local music", size: 30) { player.toggleMuted() }
            .opacity(player.muted ? 0.45 : 1)
    }
}
