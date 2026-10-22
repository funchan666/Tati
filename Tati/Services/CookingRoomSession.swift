import SwiftUI

@MainActor
final class CookingRoomSession: ObservableObject {
    @Published private(set) var room: CookingRoom?
    @Published private(set) var minimized = false
    let audio = LocalRoomAudio()
    func enter(_ value: CookingRoom) {
        if room?.id != value.id { audio.reset() }
        room = value; minimized = false
    }
    func minimize() { minimized = room?.isVoice == true }
    func leave(_ id: String? = nil) {
        guard id == nil || room?.id == id else { return }
        audio.reset(); room = nil; minimized = false
    }
}
struct MinimizedRoomBar: View {
    @EnvironmentObject private var session: CookingRoomSession
    var body: some View {
        if let room = session.room, session.minimized {
            HStack(spacing: 10) {
                NavigationLink(destination: RoomView(room: room)) {
                    HStack(spacing: 12) {
                        Art(name: "chat-speaker", width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(room.title).font(.tati(.subheadline).bold()).lineLimit(1)
                            Text("Tap to return").font(.tati(.caption2))
                        }
                        Spacer()
                    }.frame(minHeight: 48)
                }.buttonStyle(.plain)
                ArtButton(asset: "close", label: "Close minimized room") { session.leave() }
            }.padding(.horizontal, 16).background(Color.tatiCream).foregroundStyle(Color.tatiInk)
        }
    }
}
