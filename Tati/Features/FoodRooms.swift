import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

enum RoomPanel: String, Identifiable {
    case gifts, tools, members, layout, background, microphone, music, invite, host, report, pk
    var id: String { rawValue }
}
struct RoomView: View {
    let room: FoodRoom
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var panel: RoomPanel?
    @State private var message = ""
    @StateObject private var music = LocalRoomAudio()
    private var host: FoodPerson { FoodCatalog.person(room.hostID) ?? FoodCatalog.people[0] }
    private var background: String { store.account.roomBackgrounds[room.id] ?? room.background }
    private var layout: String { store.account.roomLayouts[room.id] ?? "10-seat voice room" }
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                NavigationLink(destination: PersonProfileView(person: host)) {
                    HStack(spacing: 8) { Avatar(size: 40); VStack(alignment: .leading) { Text(host.name).font(.headline); Text("Sample host").font(.caption2) } }
                }.buttonStyle(.plain)
                ArtButton(asset: store.account.following.contains(host.id) ? "check" : "follow-small", label: "Follow host", size: 22) { store.toggleFollow(host.id) }
                Spacer()
                Button { panel = .members } label: {
                    HStack(spacing: 3) { SupplementIcon(icon: .viewers, size: 18); Text("0").font(.caption) }.padding(7).background(Color.tatiCream.opacity(0.85)).clipShape(Capsule())
                }.buttonStyle(.plain).foregroundStyle(Color.tatiInk).accessibilityLabel("Connected members: zero")
                ArtButton(asset: "more", label: "Room tools") { panel = .tools }
                ArtButton(asset: "close", label: "Leave room") { leave() }
            }.padding(.horizontal, 14)
            Text(room.title).font(.system(size: 18, weight: .bold)).padding(.horizontal)
            Text("ROOM PREVIEW · NOT LIVE").font(.system(size: 10, weight: .heavy)).padding(.horizontal, 12).padding(.vertical, 7).background(Color.tatiOlive.opacity(0.9)).clipShape(Capsule())
            if room.isVoice {
                ScrollView {
                    VStack(spacing: 20) {
                        ZStack { Art(name: "host-frame", width: 114, height: 114); Avatar(size: 76) }.padding(.top, 10)
                        Text(host.name).font(.headline)
                        Text(layout).font(.caption).opacity(0.85)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 22) {
                            ForEach(0..<8) { index in
                                Button { panel = .microphone } label: {
                                    VStack(spacing: 8) { Art(name: "tool-mic", width: 48, height: 48); Text("\(index + 2)").font(.caption) }
                                }.buttonStyle(.plain).accessibilityLabel("Empty microphone seat \(index + 2)")
                            }
                        }.padding(.horizontal, 18)
                    }
                }
            } else {
                Spacer(minLength: 8)
                VStack(spacing: 16) {
                    Art(name: "media-placeholder", width: 76, height: 76)
                    Text("Host video to come").font(.headline)
                    Text("No live stream is connected.").font(.subheadline)
                    Button { panel = .pk } label: { Art(name: "versus", width: 62, height: 70) }.buttonStyle(.plain).accessibilityLabel("PK preview")
                }.frame(maxWidth: .infinity).padding(24).background(Color.black.opacity(0.22)).clipShape(RoundedRectangle(cornerRadius: 24)).padding(.horizontal, 22)
                Spacer(minLength: 8)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to this room preview").font(.system(size: 13, weight: .semibold))
                Text("Explore the layout and gifts. Nobody is connected and no messages are being broadcast.").font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            }.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(Color.black.opacity(0.30)).clipShape(RoundedRectangle(cornerRadius: 15)).padding(.horizontal, 18)
            HStack(spacing: 8) {
                TextField("Tell me your opinion…", text: $message).textFieldStyle(.plain).foregroundStyle(Color.tatiInk).padding(13).background(Color.tatiCream).clipShape(Capsule())
                Button {
                    guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    if store.saveDraft("room-" + room.id, text: message) { store.tell("Not broadcast", "Live chat is not connected. Your room message is saved as a local draft.") }
                } label: { SupplementIcon(icon: .send).frame(width: 44, height: 44).background(Color.tatiCream).clipShape(Circle()) }.buttonStyle(.plain).accessibilityLabel("Send room message")
                ArtButton(asset: "gift-live", label: "Gifts", size: 39) { panel = .gifts }
            }.padding(.horizontal, 16).padding(.bottom, 10)
        }
        .padding(.top, 8).foregroundStyle(.white)
        .background { GeometryReader { geo in Image(background).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped() }.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { message = store.account.drafts["room-" + room.id] ?? "" }
        .onDisappear { music.stop() }
        .sheet(item: $panel) { selected in
            NavigationStack {
                Group {
                    switch selected {
                    case .gifts: GiftShopView(recipient: host)
                    case .tools: toolsPanel
                    case .members: TatiPage(title: "Room members") { EmptyContent(title: "No connected members", detail: "This is a room preview. The host is a sample profile."); NavigationLink(destination: PersonProfileView(person: host)) { SettingRow(title: "View sample host", asset: "profile-heading") } }
                    case .layout: layoutPanel
                    case .background: backgroundPanel
                    case .microphone: MicrophonePanel()
                    case .music: RoomMusicPanel(player: music)
                    case .invite: TatiPage(title: "Invite friends") { EmptyContent(title: "Invitations aren't connected", detail: "A real room link will be available after the live service is configured.", artwork: "tool-invite") }
                    case .host: PersonProfileView(person: host)
                    case .report: ReportView(subjectID: "room:" + room.id)
                    case .pk: TatiPage(title: "PK") { Art(name: "versus", height: 110).frame(maxWidth: .infinity); EmptyContent(title: "No match in progress", detail: "PK requires two connected hosts. The preview doesn't simulate opponents, scores or a winner.") }
                    }
                }
            }.overlay { NoticeLayer() }.presentationDragIndicator(.hidden)
        }
    }
    private func leave() {
        store.confirm("Leave this room?", "Your local room appearance is saved. Any local music playback will stop.", button: "Leave") { music.stop(); dismiss() }
    }
    private var toolsPanel: some View {
        TatiPage(title: "Room tools") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 22) {
                tool("tool-layout", "Room layout", .layout)
                tool("tool-mic", "Mic queue", .microphone)
                tool("tool-music", "Music", .music)
                tool("tool-background", "Background", .background)
                tool("tool-invite", "Invite", .invite)
                Button { panel = nil; leave() } label: { VStack { Art(name: "tool-leave", width: 54, height: 54); Text("Leave").font(.caption) } }.buttonStyle(.plain)
            }
            Note(text: "Changes here affect only your local room preview.")
            NavigationLink(destination: ReportView(subjectID: "room:" + room.id)) { SettingRow(title: "Report room", asset: "feedback") }
        }
    }
    private func tool(_ art: String, _ title: String, _ next: RoomPanel) -> some View {
        Button { panel = next } label: { VStack(spacing: 8) { Art(name: art, width: 54, height: 54); Text(title).font(.caption) } }.buttonStyle(.plain)
    }
    private var layoutPanel: some View {
        TatiPage(title: "Room layout") {
            ForEach(["10-seat voice room", "Spotlight + voices", "Duo video + voices", "Three video + voices"], id: \.self) { name in
                Button {
                    if store.change({ $0.roomLayouts[room.id] = name }) { panel = nil }
                } label: {
                    HStack { Art(name: "layout-seat", width: 30); Text(name).font(.headline); Spacer(); if layout == name { Art(name: "check", width: 24) } }.padding(16).background(Color.tatiLime).clipShape(RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
            }
            Note(text: "Video layouts reserve empty camera slots until a service is connected.")
        }
    }
    private var backgroundPanel: some View {
        TatiPage(title: "Room background") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                ForEach(["stage-blue", "stage-gifts", "stage-purple", "stage-confetti"], id: \.self) { name in
                    Button { if store.change({ $0.roomBackgrounds[room.id] = name }) { panel = nil } } label: {
                        VStack { Image(name).resizable().scaledToFill().frame(height: 230).clipped().clipShape(RoundedRectangle(cornerRadius: 18)); Text(name.replacingOccurrences(of: "stage-", with: "").capitalized).font(.caption); if background == name { Art(name: "check-pink", width: 22) } }
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
struct GiftShopView: View {
    var recipient: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    @State private var selected = FoodCatalog.gifts[0]
    @State private var quantity = 1
    var body: some View {
        TatiPage(title: "Gifts for \(recipient.name)") {
            Note(text: "LOCAL PREVIEW · Uses demo coins only. Nothing is sent to the sample profile.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(FoodCatalog.gifts) { gift in
                    Button { selected = gift } label: {
                        VStack(spacing: 7) {
                            Art(name: gift.artwork, width: 62, height: 62)
                            Text(gift.name).font(.system(size: 10, weight: .medium)).lineLimit(2).frame(height: 28)
                            HStack(spacing: 3) { Art(name: "coin-small", width: 14); Text("\(gift.cost)").font(.system(size: 12, weight: .bold)) }
                        }.padding(.vertical, 10).frame(maxWidth: .infinity).background(selected.id == gift.id ? Color.tatiLime : Color.white.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).accessibilityAddTraits(selected.id == gift.id ? .isSelected : [])
                }
            }
            HStack {
                Art(name: "coin", width: 27)
                VStack(alignment: .leading) { Text("\(store.account.demoCoins)").font(.headline); Text("Demo coins").font(.caption) }
                Spacer()
                Button("−") { quantity = max(1, quantity - 1) }.buttonStyle(.plain).frame(width: 44, height: 44).background(Color.tatiLime).clipShape(Circle()).accessibilityLabel("Decrease quantity")
                Text("\(quantity)").monospacedDigit().frame(minWidth: 28)
                Button("+") { quantity = min(99, quantity + 1) }.buttonStyle(.plain).frame(width: 44, height: 44).background(Color.tatiLime).clipShape(Circle()).accessibilityLabel("Increase quantity")
            }
            TatiButton(title: "Preview gift · \(selected.cost * quantity) demo coins") {
                if store.previewGift(selected, quantity: quantity, recipient: recipient.id) { store.tell("Gift preview saved", "Your local demo balance was updated. This gift has not been delivered to anyone.") }
            }
            NavigationLink(destination: CheckInView()) { SettingRow(title: "Collect demo coins", asset: "coin") }
            NavigationLink(destination: WalletView()) { SettingRow(title: "Wallet", asset: "wallet-entry") }
        }
    }
}
struct MicrophonePanel: View {
    @State private var status = "Microphone access has not been requested."
    var body: some View {
        TatiPage(title: "Join the microphone") {
            Art(name: "tool-mic", height: 80).frame(maxWidth: .infinity)
            Text("No connected voice session").font(.title3.bold())
            Note(text: status)
            TatiButton(title: "Check microphone permission") {
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in status = granted ? "Permission granted. You are not broadcasting; the voice service is not connected." : "Microphone access was denied. You can allow it in iOS Settings." }
                }
            }
            Note(text: "No recording starts when you grant permission.")
        }
    }
}
@MainActor final class LocalRoomAudio: ObservableObject {
    @Published var playing = false
    @Published var title = "No audio selected"
    private var player: AVAudioPlayer?
    func load(_ url: URL) throws {
        stop()
        player = try AVAudioPlayer(contentsOf: url)
        title = url.deletingPathExtension().lastPathComponent
    }
    func toggle() throws {
        guard let player else { return }
        if playing { stop() } else {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            playing = player.play()
        }
    }
    func stop() { player?.pause(); playing = false; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}
struct RoomMusicPanel: View {
    @ObservedObject var player: LocalRoomAudio
    @EnvironmentObject private var store: VisitorStore
    @State private var importing = false
    var body: some View {
        TatiPage(title: "Music") {
            Art(name: "tool-music", height: 80).frame(maxWidth: .infinity)
            Text(player.title).font(.headline)
            Note(text: "Playback is only on this device. It is not broadcast to a room.")
            TatiButton(title: "Choose audio") { importing = true }
            TatiButton(title: player.playing ? "Pause" : "Play", secondary: true, enabled: player.title != "No audio selected") {
                do { try player.toggle() } catch { store.tell("Audio unavailable", "The audio couldn't be played. Try another file.") }
            }
        }.fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            do {
                let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                // AVAudioPlayer consumes the file contents while opening; no access token is retained.
                try player.load(url)
            } catch { store.tell("Audio not selected", "No playable audio was loaded. You can try another file.") }
        }
    }
}
