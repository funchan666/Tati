import SwiftUI

struct RoomLayoutPanel: View {
    var current: String
    var choose: (String) -> Void
    @State private var mode = "Voice"
    private let videoLayouts = [("Spotlight + voices", "1 video + 8 voice"), ("Duo video + voices", "2 video + 6 voice"), ("Three video + voices", "3 video + 6 voice")]
    var body: some View {
        TatiPanel(title: "Room Layout") {
            TopicStrip(items: ["Voice", "Video + Voice"], selected: $mode)
            if mode == "Voice" { layout("10-seat voice room", "10 voice seats") }
            else { ForEach(videoLayouts, id: \.0) { layout($0.0, $0.1) } }
            Note(text: "Choose a layout for this local preview. Remote seats remain empty until the live service is connected.")
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
            }.padding(18).background(current == name ? Color.yellow.opacity(0.65) : Color.tatiOlive.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityAddTraits(current == name ? .isSelected : [])
    }
}
struct RoomPersonPanel: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPanel(title: "Host") {
            VStack(spacing: 10) {
                Avatar(size: 76)
                Text(person.name).font(.title2.bold())
                Text(person.city).font(.subheadline)
                Note(text: "Sample profile · not connected")
            }.frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                NavigationLink(destination: PersonProfileView(person: person)) { panelLink("Profile") }
                NavigationLink(destination: ConversationView(person: person)) { panelLink("Message") }
                TatiButton(title: store.account.following.contains(person.id) ? "Following" : "Follow") { store.toggleFollow(person.id) }
            }.buttonStyle(.plain)
            NavigationLink(destination: GiftShopView(recipient: person)) { panelLink("Preview a gift") }.buttonStyle(.plain)
        }
    }
    private func panelLink(_ text: String) -> some View {
        Text(text).font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 48).background(Color.tatiOlive.opacity(0.22)).clipShape(Capsule())
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
                    NavigationLink(destination: PersonProfileView(person: person)) { HStack { Avatar(); Text(person.name).font(.headline) } }.buttonStyle(.plain)
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
