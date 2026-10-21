import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

enum RoomPanel: String, Identifiable {
    case gifts, tools, safety, members, layout, background, microphone, music, invite, host, report, pk, leave
    var id: String { rawValue }
}
struct RoomView: View {
    let room: FoodRoom
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var panel: RoomPanel?
    @State private var message = ""
    @EnvironmentObject private var roomSession: RoomPreviewSession
    @EnvironmentObject private var playback: ClipPlayback
    @State private var playbackOwner = UUID().uuidString
    @State private var isVisible = false
    @State private var videoFailure: String?
    @State private var giftEffect: GiftReceipt?
    @State private var showPK = false
    private var music: LocalRoomAudio { roomSession.audio }
    private var host: FoodPerson { FoodCatalog.person(room.hostID) ?? FoodCatalog.people[0] }
    private var background: String { store.account.roomBackgrounds[room.id] ?? room.background }
    private var videoSlots: Int { layout == "Spotlight + voices" ? 1 : layout == "Duo video + voices" ? 2 : layout == "Three video + voices" ? 3 : 0 }
    private var voiceSeats: Int { videoSlots == 0 ? 9 : videoSlots == 1 ? 8 : 6 }
    private var layout: String { store.account.roomLayouts[room.id] ?? "10-seat voice room" }
    private var ownsPlayback: Bool { playback.ownerID == playbackOwner }
    var body: some View {
        MediaViewport {
            GeometryReader { geometry in
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        HStack(spacing: 0) {
                            NavigationLink(destination: PersonProfileView(person: host)) {
                                HStack(spacing: 6) {
                                    Avatar(asset: host.portraitArtwork, size: 38)
                                        .overlay { Circle().strokeBorder(.white.opacity(0.75), lineWidth: 1) }
                                        .overlay(alignment: .bottom) {
                                            if !room.isVoice {
                                                RoomKindBadge(isVoice: false, animates: ownsPlayback && playback.playing)
                                                    .scaleEffect(0.62).frame(width: 30, height: 14).offset(y: 5)
                                            }
                                        }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(host.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                        HStack(spacing: 5) {
                                            Text(host.city).font(.system(size: 9)).opacity(0.8).lineLimit(1)
                                            if room.isVoice { RoomKindBadge(isVoice: true, compact: true) }
                                        }
                                    }
                                }
                            }.buttonStyle(.plain)
                            ArtButton(asset: store.account.following.contains(host.id) ? "check" : "follow-small", label: store.account.following.contains(host.id) ? "Unfollow host" : "Follow host", size: 18) { store.toggleFollow(host.id) }
                        }.padding(.leading, 3).background { Capsule().fill(.black.opacity(0.20)) }
                        Spacer(minLength: 6)
                        Button { panel = .members } label: {
                            HStack(spacing: 3) { SupplementIcon(icon: .viewers, size: 12, tint: .white); Text("0").font(.system(size: 10)) }
                                .padding(.horizontal, 6).padding(.vertical, 4).background(.black.opacity(0.35)).clipShape(Capsule()).frame(minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("Room members: zero")
                        ArtButton(asset: "more", label: "Room tools", size: 22) { panel = .tools }
                        ArtButton(asset: "close", label: "Leave room", size: 22) { leave() }
                    }.padding(.horizontal, 12)
                    if room.isVoice {
                        voiceStage(containerWidth: geometry.size.width)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                HStack {
                                    Spacer()
                                    Button { panel = .pk } label: { Art(name: "versus", width: 52, height: 52).frame(width: 60, height: 60) }.buttonStyle(.plain).accessibilityLabel("PK layout")
                                }.padding(.horizontal, 18)
                                if showPK {
                                    HStack(spacing: 8) { MediaPlaceholder(title: "Host camera", height: 200); MediaPlaceholder(title: "Guest camera", height: 200) }.padding(.horizontal, 12)
                                }
                                if let failure = videoFailure ?? (ownsPlayback ? playback.failure : nil) {
                                    VStack(spacing: 8) {
                                        Text(failure).font(.system(size: 12)).multilineTextAlignment(.center)
                                        TatiButton(title: "Retry video") { startRoomVideo() }.frame(width: 150)
                                    }.padding(16).background(.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 12))
                                } else if ownsPlayback && playback.loading {
                                    Text("Loading…").font(.system(size: 12))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    RoomActivityFeed(room: room, isActive: isVisible && panel == nil, maximumHeight: min(188, geometry.size.height * 0.28), maximumWidth: min(320, geometry.size.width * 0.82))
                    HStack(spacing: 8) {
                        if room.isVoice { ArtButton(asset: "chat-mic", label: "Join microphone", size: 32) { panel = .microphone } }
                        HStack(spacing: 0) {
                            TextField("Say Hi~", text: $message, prompt: Text(room.isVoice ? "Say Hi~" : "Tell me your opinion…").foregroundStyle(.white.opacity(0.9)))
                                .font(.system(size: 13)).foregroundStyle(.white).textFieldStyle(.plain).tint(.white).padding(.leading, 14)
                                .onChange(of: message) { _, value in message = String(value.prefix(300)) }
                            Button {
                                if store.saveRoomMessage(roomID: room.id, text: message) { message = "" }
                            } label: { SupplementIcon(icon: .send, size: 22, tint: .white).frame(width: 44, height: 44) }
                                .buttonStyle(.plain).accessibilityLabel("Save room message")
                                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .opacity(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                        }.background(.black.opacity(0.58)).clipShape(Capsule())
                            .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
                        if room.isVoice { RoomSoundButton(player: music) }
                        ArtButton(asset: "gift-live", label: "Gifts", size: 36) { panel = .gifts }
                    }.padding(.horizontal, 14).padding(.vertical, 8)
                }
                .padding(.top, 4).foregroundStyle(.white)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .background {
            GeometryReader { geo in
                ZStack {
                    Image(room.isVoice ? background : (store.account.roomBackgrounds[room.id] ?? room.coverArtwork ?? "media-placeholder")).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height, alignment: room.isVoice ? .center : .top).clipped()
                    if ownsPlayback, let player = playback.player, playback.failure == nil {
                        ClipSurface(player: player, fillsContainer: true)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    if room.isVoice {
                        // The supplied stage includes a white floor. The design's
                        // full-bleed scrim keeps that floor behind readable controls.
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.black.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: min(160, geo.size.height * 0.2))
                            Spacer(minLength: 0)
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.28), location: 0.4),
                                .init(color: .black.opacity(0.86), location: 0.82),
                                .init(color: .black.opacity(0.98), location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                            .frame(height: geo.size.height * 0.34)
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }.allowsHitTesting(false)
            }.ignoresSafeArea()
        }
        .tatiScreen()
        .onAppear {
            guard store.visibleRooms.contains(where: { $0.id == room.id }) else { dismiss(); return }
            isVisible = true
            roomSession.enter(room); message = store.account.drafts["room-" + room.id] ?? ""
            startRoomVideo()
        }
        .onDisappear {
            isVisible = false
            if ownsPlayback { playback.stop() }
            if !roomSession.minimized { roomSession.leave(room.id) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                music.stop()
                if ownsPlayback { playback.stop() }
            } else if isVisible { startRoomVideo() }
        }
        .overlay {
            if let receipt = giftEffect, let gift = FoodCatalog.gift(receipt.giftID) {
                RoomGiftEffect(gift: gift, quantity: receipt.quantity).id(receipt.id).allowsHitTesting(false)
            }
        }
        .onChange(of: store.account.gifts.count) { _, _ in
            if let receipt = store.account.gifts.last, receipt.roomID == room.id { giftEffect = receipt }
        }
        .task(id: giftEffect?.id) {
            guard giftEffect != nil else { return }
            do { try await Task.sleep(for: .seconds(2.5)); giftEffect = nil } catch { }
        }
        .onChange(of: store.account.blocked) { _, _ in closeIfHidden() }
        .onChange(of: store.account.hiddenSubjects) { _, _ in closeIfHidden() }
        .sheet(item: $panel) { selected in
            if selected == .leave {
                RoomLeavePanel(isVoice: room.isVoice,
                               minimize: { roomSession.minimize(); panel = nil; dismiss() },
                               leave: { roomSession.leave(room.id); panel = nil; dismiss() },
                               stay: { panel = nil })
            } else if selected == .safety {
                SafetyActionsView(subjectID: "room:" + room.id, authorID: room.hostID)
            } else if selected == .tools {
                RoomToolsPanel(isVoice: room.isVoice) { panel = $0 }
            } else {
                NavigationStack {
                    Group {
                        switch selected {
                        case .gifts: GiftShopView(recipient: host, roomID: room.id, onGiftSaved: { panel = nil })
                        case .tools, .safety: EmptyView() // Uses its own content-sized presentation.
                        case .members: TatiPanel(title: "In this room") { EmptyContent(title: "No members yet", detail: "Member information is currently unavailable."); NavigationLink(destination: PersonProfileView(person: host)) { SettingRow(title: "View host", asset: "profile-heading") } }
                        case .layout: layoutPanel
                        case .background: backgroundPanel
                        case .microphone: MicrophonePanel()
                        case .music: RoomMusicPanel(player: music)
                        case .invite: RoomInvitePanel(room: room)
                        case .host: RoomPersonPanel(person: host, roomMember: room.isVoice, roomID: room.id)
                        case .report: ReportView(subjectID: "room:" + room.id)
                        case .pk: TatiPanel(title: "PK") {
                            Art(name: "versus", height: 85).frame(maxWidth: .infinity)
                            Note(text: "Choose a camera layout. PK matches are currently unavailable.")
                            TatiButton(title: showPK ? "Return to single camera" : "Split camera layout") { showPK.toggle(); panel = nil }
                        }
                        case .leave: EmptyView() // Presented separately at its content height.
                        }
                    }
                }
                .overlay { NoticeLayer() }
                .presentationDetents(panelDetents(for: selected))
                .presentationDragIndicator(.hidden)
            }
        }
    }
    private func closeIfHidden() {
        guard !store.visibleRooms.contains(where: { $0.id == room.id }) else { return }
        if ownsPlayback { playback.stop() }
        roomSession.leave(room.id)
        dismiss()
    }
    private func voiceStage(containerWidth: CGFloat) -> some View {
        let stageWidth = max(0, min(440, containerWidth - 32))
        let maximumColumns = max(1, min(5, Int(stageWidth / 62)))
        let rowCount = (voiceSeats + maximumColumns - 1) / maximumColumns
        let columns = (voiceSeats + rowCount - 1) / rowCount
        let cellWidth = min(76, stageWidth / CGFloat(columns))
        return ScrollView {
            VStack(spacing: 20) {
                NavigationLink(destination: PersonProfileView(person: host)) {
                    Avatar(asset: host.portraitArtwork, size: 68)
                        .overlay { Art(name: "host-frame", width: 96, height: 96) }
                        .frame(width: 104, height: 104)
                }.buttonStyle(.plain).accessibilityLabel("Host details")
                if videoSlots > 0 {
                    HStack(spacing: 8) {
                        ForEach(0..<videoSlots, id: \.self) { slot in
                            MediaPlaceholder(title: "Camera \(slot + 1)", height: videoSlots == 1 ? 150 : 112)
                        }
                    }
                }
                VStack(spacing: 18) {
                    ForEach(0..<rowCount, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach((row * columns)..<min((row + 1) * columns, voiceSeats), id: \.self) { index in
                                Button { panel = .microphone } label: {
                                    VStack(spacing: 7) {
                                        Art(name: "mic-small", width: 14, height: 20)
                                            .frame(width: 44, height: 44)
                                            .background(.white.opacity(0.12), in: Circle())
                                            .overlay { Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1) }
                                        Text("\(index + 2)").font(.system(size: 11, weight: .medium))
                                    }
                                    .frame(width: cellWidth).frame(minHeight: 68)
                                    .contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("Empty microphone seat \(index + 2)")
                            }
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(width: stageWidth).padding(.top, 16).padding(.bottom, 12)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    private func startRoomVideo() {
        videoFailure = nil
        guard let clip = room.videoClip else { return }
        guard !ownsPlayback || playback.failure != nil else { return }
        music.stop()
        guard let url = store.videoURL(for: clip) else {
            videoFailure = "The room video could not be found."
            return
        }
        do { try playback.load(id: clip.id, url: url, owner: playbackOwner, loops: true) }
        catch { videoFailure = "The room video could not be opened." }
    }
    private func leave() { panel = .leave }
    private func panelDetents(for selected: RoomPanel) -> Set<PresentationDetent> {
        switch selected {
        case .report: return [.large]
        case .gifts: return [.height(390), .large]
        case .microphone: return [.height(220), .large]
        case .host: return [.height(320), .large]
        default: return [.height(420), .large]
        }
    }
    private var layoutPanel: some View {
        RoomLayoutPanel(current: layout) { chosen in
            if store.change({ $0.roomLayouts[room.id] = chosen }) { panel = nil }
        }
    }
    private var backgroundPanel: some View {
        TatiPanel(title: "Room atmosphere") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(["stage-blue", "stage-gifts", "stage-purple", "stage-confetti"], id: \.self) { name in
                    Button { if store.change({ $0.roomBackgrounds[room.id] = name }) { panel = nil } } label: {
                        VStack(spacing: 6) {
                            GeometryReader { geometry in
                                Image(name).resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            }.aspectRatio(110.0 / 130.0, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(alignment: .topTrailing) { if background == name { Art(name: "check-pink", width: 22, height: 22).padding(4) } }
                        }
                        .accessibilityLabel(name.replacingOccurrences(of: "stage-", with: "").capitalized)
                        .accessibilityAddTraits(background == name ? .isSelected : [])
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
struct GiftShopView: View {
    var recipient: FoodPerson
    var roomID: String? = nil
    var onGiftSaved: (() -> Void)? = nil
    @EnvironmentObject private var store: VisitorStore
    @State private var selected = FoodCatalog.gifts[0]
    @State private var quantity = 1
    @State private var showRecharge = false
    var body: some View {
        TatiPanel(title: "Gifts", showsHeader: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(FoodCatalog.gifts) { gift in
                    Button { selected = gift } label: {
                        VStack(spacing: 8) {
                            Art(name: gift.artwork, height: 56)
                                .frame(maxWidth: .infinity).background(selected.id == gift.id ? Color.tatiOlive.opacity(0.35) : .clear).clipShape(RoundedRectangle(cornerRadius: 8))
                            HStack(spacing: 3) { Art(name: "coin-small", width: 15); Text("\(gift.cost)").font(.system(size: 13)) }
                        }
                    }.buttonStyle(.plain).accessibilityLabel("\(gift.name), \(gift.cost) coins").accessibilityAddTraits(selected.id == gift.id ? .isSelected : [])
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { balance; Spacer(minLength: 0); giftActions }
                VStack(alignment: .leading, spacing: 8) {
                    balance
                    HStack { Spacer(minLength: 0); giftActions }
                }
            }.padding(.top, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text("Room effects · Plays on your screen").font(.system(size: 10))
                HStack(spacing: 18) {
                    NavigationLink("Check-in", destination: CheckInView()).font(.system(size: 11, weight: .semibold)).frame(minHeight: 32)
                    NavigationLink("Wallet", destination: WalletView()).font(.system(size: 11, weight: .semibold)).frame(minHeight: 32)
                }
            }
        }.sheet(isPresented: $showRecharge) { NavigationStack { WalletView() }.overlay { NoticeLayer() } }
    }
    private var balance: some View {
        NavigationLink(destination: RechargePanel()) {
            HStack(spacing: 4) {
                Art(name: "coin", width: 24)
                Text("\(store.coinBalance.formatted())").font(.system(size: 15)).lineLimit(1).fixedSize()
            }.frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityLabel("Coin balance and recharge")
    }
    private var giftActions: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ArtButton(asset: "remove", label: "Decrease quantity", size: 22) { quantity = max(1, quantity - 1) }
                Text("\(quantity)").font(.system(size: 13)).monospacedDigit().frame(minWidth: 22)
                ArtButton(asset: "add", label: "Increase quantity", size: 22) { quantity = min(99, quantity + 1) }
            }.background(Color.tatiOlive.opacity(0.35)).clipShape(Capsule())
            TatiButton(title: "Play effect", enabled: !store.isPersonHidden(recipient.id)) {
                store.requestGift(selected, quantity: quantity, recipient: recipient.id, roomID: roomID,
                                  recharge: { showRecharge = true }, completed: {
                    if let onGiftSaved { onGiftSaved() }
                    else { store.celebrate("Effect unlocked", "Your coin balance and gift history have been updated.", artwork: selected.artwork) }
                })
            }.frame(width: 100)
        }.fixedSize(horizontal: true, vertical: false)
    }
}
struct MicrophonePanel: View {
    @State private var status = "Microphone access has not been requested."
    @State private var requesting = false
    var body: some View {
        TatiPanel(title: "Join the conversation") {
            Text("Allow microphone access to use voice features.").font(.system(size: 12)).padding(.vertical, 8)
            Note(text: status)
            TatiButton(title: requesting ? "Waiting for permission…" : "Check microphone permission", enabled: !requesting) {
                requesting = true
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in requesting = false; status = granted ? "Microphone access granted. Voice chat is currently unavailable; recording has not started." : "Microphone access was denied. You can allow it in iOS Settings." }
                }
            }
        }
    }
}
@MainActor final class LocalRoomAudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playing = false
    @Published private(set) var muted = false
    @Published var title = "No audio selected"
    private var player: AVAudioPlayer?
    func load(_ url: URL) throws {
        stop()
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        guard bytes.count <= 50 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        player = try AVAudioPlayer(data: bytes)
        player?.delegate = self
        player?.volume = muted ? 0 : 1
        title = url.deletingPathExtension().lastPathComponent
    }
    func reset() { stop(); player = nil; title = "No audio selected"; muted = false }
    func toggleMuted() { muted.toggle(); player?.volume = muted ? 0 : 1 }
    func toggle() throws {
        guard let player else { return }
        if playing { stop() } else {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            playing = player.play()
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in guard self?.player === player else { return }; self?.stop() }
    }
    func stop() { player?.pause(); playing = false; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}
struct RoomMusicPanel: View {
    @ObservedObject var player: LocalRoomAudio
    @EnvironmentObject private var store: VisitorStore
    @State private var importing = false
    var body: some View {
        TatiPanel(title: "Room music") {
            ForEach(["Midnight mood", "Warm conversations", "Slow afternoon"], id: \.self) { title in
                HStack { Art(name: "music-disc", width: 26); Text(title).font(.subheadline); Spacer(); Text("Audio pending").font(.caption2) }
                    .padding(14).background(Color.tatiOlive.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Text(player.title).font(.headline)
            Note(text: "Selected music is for your listening only.")
            TatiButton(title: "Choose audio") { importing = true }
            TatiButton(title: player.playing ? "Pause" : "Play", secondary: true, enabled: player.title != "No audio selected") {
                do { try player.toggle() } catch { store.tell("Audio unavailable", "The audio couldn't be played. Try another file.") }
            }
        }.fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            do {
                let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                // Copy audio bytes while the security-scoped file is accessible.
                try player.load(url)
            } catch { store.tell("Audio not selected", "No playable audio was loaded. You can try another file.") }
        }
    }
}

private struct RoomGiftEffect: View {
    let gift: FoodGift
    let quantity: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    var body: some View {
        VStack(spacing: 12) {
            Art(name: gift.artwork, width: 170, height: 170)
            Text("\(gift.name) ×\(quantity)").font(.headline).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.tatiInk.opacity(0.8)).clipShape(Capsule())
        }.scaleEffect(revealed ? 1 : 0.65).opacity(revealed ? 1 : 0)
            .onAppear {
                if reduceMotion { revealed = true }
                else { withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { revealed = true } }
            }
    }
}
