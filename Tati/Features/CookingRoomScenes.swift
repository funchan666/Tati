import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

enum RoomPanel: String, Identifiable {
    case gifts, tools, safety, members, background, microphone, dictation, music, report, viewing, leave
    var id: String { rawValue }
    func supports(voice: Bool) -> Bool {
        switch self {
        case .background, .microphone, .dictation, .music: return voice
        case .viewing: return !voice
        default: return true
        }
    }
}
struct RoomView: View {
    let room: CookingRoom
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var panel: RoomPanel?
    @State private var pendingVoiceInput = false
    @State private var pendingProfile: TableMember?
    @State private var profilePage: TableMember?
    @State private var message = ""
    @StateObject private var speech = RoomDictationSession()
    @FocusState private var editingMessage: Bool
    @EnvironmentObject private var roomSession: CookingRoomSession
    @EnvironmentObject private var playback: FoodFilmPlayback
    @State private var playbackOwner = UUID().uuidString
    @State private var isVisible = false
    @State private var videoFailure: String?
    @State private var giftEffect: RoomEffectPurchase?
    @State private var fillsVideo = true
    @State private var videoMuted = false
    @State private var showsActivity = true
    private var music: LocalRoomAudio { roomSession.audio }
    private var host: TableMember? { TableCommunity.person(room.hostID) }
    private var background: String { store.voiceRoomBackground(for: room).rawValue }
    private let voiceSeats = 9
    private var ownsPlayback: Bool { playback.ownerID == playbackOwner }
    var body: some View {
        MediaViewport {
            GeometryReader { geometry in
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        HStack(spacing: 0) {
                            UserProfileLink(userID: room.hostID) {
                                HStack(spacing: 6) {
                                    Avatar(asset: host?.portraitArtwork, size: 38)
                                        .overlay { Circle().strokeBorder(.white.opacity(0.75), lineWidth: 1) }
                                        .overlay(alignment: .bottom) {
                                            if !room.isVoice {
                                                RoomKindBadge(isVoice: false)
                                                    .scaleEffect(0.62).frame(width: 30, height: 14).offset(y: 5)
                                            }
                                        }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(host?.name ?? "").font(.tati(size: 13, weight: .semibold)).lineLimit(1)
                                        HStack(spacing: 5) {
                                            Text(host?.city ?? "").font(.tati(size: 9)).opacity(0.8).lineLimit(1)
                                            if room.isVoice { RoomKindBadge(isVoice: true, compact: true) }
                                        }
                                    }
                                }
                            }.buttonStyle(.plain)
                            FollowControl(userID: room.hostID)
                        }.padding(.leading, 3).background { Capsule().fill(.black.opacity(0.20)) }
                        Spacer(minLength: 6)
                        Button { panel = .members } label: {
                            HStack(spacing: 3) { SupplementIcon(icon: .viewers, size: 12, tint: .white); Text(room.initialAudienceCount.formatted()).font(.tati(size: 10, weight: .medium)).monospacedDigit() }
                                .padding(.horizontal, 6).padding(.vertical, 4).background(.black.opacity(0.35)).clipShape(Capsule()).frame(minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("Room audience: \(room.initialAudienceCount). View member details")
                        ArtButton(asset: "more", label: "Room tools", size: 22) { panel = .tools }
                        ArtButton(asset: "close", label: "Leave room", size: 22) { leave() }
                    }.padding(.horizontal, 12)
                    if room.isVoice {
                        voiceStage(containerWidth: geometry.size.width)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                if let failure = videoFailure ?? (ownsPlayback ? playback.failure : nil) {
                                    VStack(spacing: 8) {
                                        Text(failure).font(.tati(size: 12)).multilineTextAlignment(.center)
                                        TatiButton(title: "Retry video") { startRoomVideo() }.frame(width: 150)
                                    }.padding(16).background(.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 12))
                                } else if ownsPlayback && playback.loading {
                                    Text("Loading…").font(.tati(size: 12))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    if room.isVoice || showsActivity {
                        RoomActivityFeed(room: room, isActive: isVisible && panel == nil, maximumHeight: min(188, geometry.size.height * 0.28), maximumWidth: min(320, geometry.size.width * 0.82))
                    }
                    if speech.isBusy {
                        Button { speech.finish() } label: {
                            HStack(spacing: 7) {
                                Art(name: "chat-mic", width: 18, height: 18)
                                Text(LocalizedStringKey(speech.status)).font(.tati(.caption).weight(.semibold))
                                Spacer(minLength: 0)
                                Text(speech.phase == .authorizing ? "Cancel" : "Stop").font(.tati(.caption).weight(.bold))
                            }.padding(.horizontal, 12).frame(minHeight: 44)
                                .background(Color.tatiPink.opacity(0.9), in: Capsule())
                        }.buttonStyle(.plain).padding(.horizontal, 14)
                    }
                    HStack(spacing: 8) {
                        if room.isVoice {
                            ArtButton(asset: "chat-mic", label: speech.isBusy ? "Stop speech input" : "Speak your message", size: 32) { toggleSpeechInput() }
                                .background(speech.isBusy ? Color.tatiPink : .clear, in: Circle())
                                .accessibilityValue(speech.isBusy ? speech.status : "Not listening")
                        }
                        HStack(spacing: 0) {
                            TextField("Say Hi~", text: $message, prompt: Text(room.isVoice ? "Say Hi~" : "Tell me your opinion…").foregroundStyle(.white.opacity(0.9)))
                                .font(.tati(size: 13)).foregroundStyle(.white).textFieldStyle(.plain).tint(.white).padding(.leading, 14)
                                .focused($editingMessage)
                                .disabled(speech.isBusy)
                                .onChange(of: message) { _, value in
                                    let limited = String(value.prefix(300))
                                    if limited != value { message = limited }
                                    store.scheduleDraft("room-" + room.id, text: limited)
                                }
                            Button {
                                speech.cancel()
                                if store.saveRoomMessage(roomID: room.id, text: message) { message = "" }
                            } label: { SupplementIcon(icon: .send, size: 22, tint: .white).frame(width: 44, height: 44) }
                                .buttonStyle(.plain).accessibilityLabel("Save room message")
                                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .opacity(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                        }.background(.black.opacity(0.58)).clipShape(Capsule())
                            .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
                        if room.isVoice { RoomSoundButton(player: music).disabled(speech.isBusy) }
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
                    if room.isVoice {
                        VoiceRoomBackgroundArtwork(background: store.voiceRoomBackground(for: room))
                    } else {
                        ContentPhoto(asset: room.coverArtwork, height: geo.size.height, alignment: .top)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top).clipped()
                    }
                    if !room.isVoice && !fillsVideo { Color.black }
                    if ownsPlayback, let player = playback.player, playback.failure == nil {
                        ClipSurface(player: player, fillsContainer: fillsVideo)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    if room.isVoice {

                        VStack(spacing: 0) {
                            LinearGradient(colors: [.black.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: min(160, geo.size.height * 0.2))
                            Spacer(minLength: 0)
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.28), location: 0.4),
                                .init(color: .black.opacity(0.40), location: 0.82),
                                .init(color: .black.opacity(0.50), location: 1)
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
            pendingVoiceInput = false
            speech.cancel()
            store.flushDraft("room-" + room.id)
            if ownsPlayback { playback.stop() }
            if !roomSession.minimized { roomSession.leave(room.id) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                if phase == .background || speech.phase != .authorizing { speech.cancel() }
                music.stop()
                if ownsPlayback { playback.stop() }
            } else if isVisible { startRoomVideo() }
        }
        .overlay {
            if (room.isVoice || showsActivity), let receipt = giftEffect, let gift = TableCommunity.gift(receipt.giftID) {
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
        .onChange(of: videoMuted) { _, muted in
            if ownsPlayback { playback.player?.isMuted = muted }
        }
        .onChange(of: panel) { _, selected in
            if selected != nil { speech.cancel() }
        }
        .onChange(of: store.account.blocked) { _, _ in closeIfHidden() }
        .onChange(of: store.account.hiddenSubjects) { _, _ in closeIfHidden() }
        .navigationDestination(item: $profilePage) { PersonProfileView(person: $0) }
        .sheet(item: $panel, onDismiss: {
            if pendingVoiceInput {
                pendingVoiceInput = false
                if room.isVoice, roomSession.room?.id == room.id { toggleSpeechInput() }
            }
            if let person = pendingProfile {
                pendingProfile = nil
                if !store.isPersonHidden(person.id) { profilePage = person }
            }
        }) { selected in
            Group {
            if !selected.supports(voice: room.isVoice) {
                RoomControlSheet(title: "Room tools") { Text("This control is not available in this room.") }
            } else if selected == .leave {
                RoomLeavePanel(isVoice: room.isVoice,
                               minimize: { roomSession.minimize(); panel = nil; dismiss() },
                               leave: { roomSession.leave(room.id); panel = nil; dismiss() },
                               stay: { panel = nil })
            } else if selected == .safety {
                SafetyActionsView(subjectID: "room:" + room.id, authorID: room.hostID)
            } else if selected == .tools {
                RoomToolsPanel(isVoice: room.isVoice) { destination in
                    guard destination.supports(voice: room.isVoice) else { return }
                    panel = destination
                }
            } else if selected == .gifts {
                NavigationStack {
                    if let host { GiftShopView(recipient: host, roomID: room.id, onGiftSaved: { panel = nil }) }
                    else { EmptyContent(title: "Host unavailable", detail: "Return to the room list and try again.") }
                }
                    .overlay { NoticeLayer() }

            } else if selected == .dictation {
                RoomControlSheet(title: "Voice input", subtitle: "Speak to fill the message field. Review your words before sending.") {
                    TatiEditingButton(title: "Speak a message", enabled: true) {
                        pendingVoiceInput = true
                        panel = nil
                    }
                }
            } else if selected == .viewing {
                RoomViewingPanel(fillsVideo: $fillsVideo, muted: $videoMuted, showsActivity: $showsActivity)
            } else {
                NavigationStack {
                    Group {
                        switch selected {
                        case .gifts, .tools, .safety, .viewing, .dictation: EmptyView()
                        case .members: TatiPanel(title: "In this room") { EmptyContent(title: "Member list unavailable", detail: "Member information is currently unavailable."); UserProfileLink(userID: room.hostID) { SettingRow(title: "View host", asset: "profile-heading") } }
                        case .background: backgroundPanel
                        case .microphone:
                            RoomControlSheet(title: "Voice seats", subtitle: "Speaking seats are unavailable.") {
                                Text("Use the microphone below to dictate a message instead.")
                                    .font(.tati(.subheadline))
                                TatiEditingButton(title: "Speak a message", enabled: true) {
                                    pendingVoiceInput = true
                                    panel = nil
                                }
                            }
                        case .music: RoomMusicPanel(player: music, isCurrentRoom: {
                            isVisible && room.isVoice && roomSession.room?.id == room.id && scenePhase == .active
                        })
                        case .report: ReportView(subjectID: "room:" + room.id)
                        case .leave: EmptyView()
                        }
                    }
                }
                .overlay { NoticeLayer() }
                .presentationDetents(panelDetents(for: selected))
                .presentationDragIndicator(.hidden)
            }
            }.environment(\.profileSheetAction, { person in
                pendingProfile = person
                panel = nil
            })
        }
    }
    private func toggleSpeechInput() {
        if speech.isBusy { speech.finish(); return }
        guard room.isVoice, isVisible, roomSession.room?.id == room.id, scenePhase == .active else { return }
        guard message.count < 300 else {
            store.tell("Message is full", "Send or shorten your message before adding more words.")
            return
        }
        editingMessage = false
        music.stop()
        let prefix = message
        let separator = prefix.isEmpty || prefix.last?.isWhitespace == true ? "" : " "
        speech.start(update: { transcription in
            let combined = prefix + separator + transcription
            message = String(combined.prefix(300))
            if combined.count >= 300 { speech.cancel() }
        }, failure: { detail, settings in
            if settings {
                store.confirm("Voice input unavailable", detail, button: "Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            } else { store.tell("Voice input", detail) }
        })
    }
    private func closeIfHidden() {
        guard !store.visibleRooms.contains(where: { $0.id == room.id }) else { return }
        speech.cancel()
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
                UserProfileLink(userID: room.hostID) {
                    Avatar(asset: host?.portraitArtwork, size: 68)
                        .overlay { Art(name: "host-frame", width: 96, height: 96) }
                        .frame(width: 104, height: 104)
                }.buttonStyle(.plain).accessibilityLabel("Host details")
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
                                        Text("\(index + 2)").font(.tati(size: 11, weight: .medium))
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
        do {
            try playback.load(id: clip.id, url: url, owner: playbackOwner, loops: true)
            if ownsPlayback { playback.player?.isMuted = videoMuted }
        }
        catch { videoFailure = "The room video could not be opened." }
    }
    private func leave() { panel = .leave }
    private func panelDetents(for selected: RoomPanel) -> Set<PresentationDetent> {
        switch selected {
        case .report: return [.large]
        case .gifts: return [.height(600), .large]
        case .microphone: return [.height(330), .large]
        default: return [.height(420), .large]
        }
    }
    private var backgroundPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Room atmosphere").font(.tati(.title3).weight(.bold))
                    Spacer(minLength: 8)
                    ArtButton(asset: "close-light", label: "Close backgrounds", size: 22) { panel = nil }
                }
                Text("This background is visible only to you.")
                    .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                VoiceRoomBackgroundPicker(selected: background) { chosen in
                    guard room.isVoice else { return }
                    if store.change({ $0.roomBackgrounds[room.id] = chosen.rawValue }) { panel = nil }
                }
            }.padding(20).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .foregroundStyle(Color.tatiInk)
        .background { Color.tatiCream.ignoresSafeArea(.container) }
        .presentationBackground(Color.tatiCream)
    }

}
struct GiftShopView: View {
    var recipient: TableMember
    var roomID: String? = nil
    var onGiftSaved: (() -> Void)? = nil
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected: TableCelebration? = TableCommunity.gifts.first
    @State private var quantityText = "1"
    @State private var showRecharge = false
    @FocusState private var editingQuantity: Bool

    private var quantity: Int { Int(quantityText) ?? 0 }
    private var total: Int { (selected?.cost ?? 0) * quantity }
    private var canPlay: Bool { selected != nil && (1...99).contains(quantity) && !store.isPersonHidden(recipient.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A little sparkle").font(.tati(.title3).weight(.bold))
                    Text("Gift effects · \(recipient.name)")
                        .font(.tati(.caption)).foregroundStyle(Color.tatiOlive).lineLimit(2)
                }
                Spacer(minLength: 4)
                ArtButton(asset: "close-light", label: "Close gifts") { dismiss() }
            }.padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 14)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 140 : 76), spacing: 8)], spacing: 10) {
                    ForEach(TableCommunity.gifts) { gift in giftCard(gift) }
                }.padding(.horizontal, 16).padding(.bottom, 16)
            }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)

            checkout
        }.frame(maxWidth: 600).frame(maxWidth: .infinity)
            .foregroundStyle(Color.tatiInk)
            .background { Color.tatiCream.ignoresSafeArea(.container) }
            .presentationBackground(Color.tatiCream)
            .presentationCornerRadius(28).presentationDragIndicator(.hidden)
            .presentationDetents([.height(600), .large])
            .tatiScreen()
            .accessibilityAction(.escape) { dismiss() }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editingQuantity = false }
                }
            }
            .sheet(isPresented: $showRecharge) {
                NavigationStack { WalletView() }.overlay { NoticeLayer() }
                    .presentationDetents([.large])
            }
    }

    private func giftCard(_ gift: TableCelebration) -> some View {
        let isSelected = selected?.id == gift.id
        return Button {
            editingQuantity = false
            selected = gift
        } label: {
            VStack(spacing: 5) {
                Art(name: gift.artwork, height: 62).padding(.top, 5)
                Text(LocalizedStringKey(gift.name)).font(.tati(.caption2).weight(.medium))
                    .lineLimit(2, reservesSpace: true).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 3) {
                    Art(name: "coin-small", width: 13, height: 13)
                    Text(gift.cost.formatted()).font(.tati(.caption).weight(.semibold)).monospacedDigit()
                }
            }.padding(.horizontal, 5).padding(.vertical, 9).frame(maxWidth: .infinity)
                .background(isSelected ? Color.tatiLime.opacity(0.55) : .white, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isSelected ? Color.tatiPink : Color.tatiOlive.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected { Art(name: "check-pink", width: 16, height: 16).padding(5) }
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
            .accessibilityLabel("\(gift.name), \(gift.cost) coins")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var checkout: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Art(name: "coin", width: 25, height: 25)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balance").font(.tati(.caption2)).foregroundStyle(Color.tatiOlive)
                    Text(store.coinBalance.formatted()).font(.tati(.subheadline).weight(.bold)).monospacedDigit()
                }
                Spacer(minLength: 0)
                Button { editingQuantity = false; showRecharge = true } label: {
                    HStack(spacing: 7) {
                        Text("Recharge").font(.tati(.caption).weight(.semibold))
                        Art(name: "chevron", width: 7, height: 12)
                    }.padding(.horizontal, 12).frame(minHeight: 44)
                        .background(Color.tatiCream, in: Capsule())
                }.buttonStyle(.plain)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { Text("Quantity").font(.tati(.caption).weight(.semibold)); Spacer(minLength: 0); quantityOptions }
                VStack(alignment: .leading, spacing: 6) { Text("Quantity").font(.tati(.caption).weight(.semibold)); quantityOptions }
            }
            Button(action: playGift) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text("Play \(selected?.name ?? "gift effect")").font(.tati(.subheadline).weight(.semibold))
                        Spacer(minLength: 0)
                        costLabel
                    }
                    VStack(spacing: 5) {
                        Text("Play \(selected?.name ?? "gift effect")").font(.tati(.subheadline).weight(.semibold))
                        costLabel
                    }
                }.padding(.horizontal, 16).padding(.vertical, 13).frame(maxWidth: .infinity, minHeight: 50)
                    .background(canPlay ? Color.tatiPink : Color.tatiPink.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(.plain).disabled(!canPlay)
                .accessibilityLabel("Play \(selected?.name ?? "gift effect"), quantity \(quantity), \(total) coins")
            Text("For your room view only · No coins sent to the host")
                .font(.tati(.caption2)).foregroundStyle(Color.tatiOlive)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 12)
            .background { Color.white.ignoresSafeArea(.container, edges: .bottom) }
    }

    private var costLabel: some View {
        HStack(spacing: 4) {
            Art(name: "coin-small", width: 17, height: 17)
            Text(total.formatted()).font(.tati(.subheadline).weight(.bold)).monospacedDigit()
        }.fixedSize()
    }

    private var quantityOptions: some View {
        HStack(spacing: 6) {
            ForEach([1, 5, 10], id: \.self) { amount in
                Button { quantityText = String(amount); editingQuantity = false } label: {
                    Text("×\(amount)").font(.tati(.caption).weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                        .background(quantity == amount ? Color.tatiLime : Color.tatiCream.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityLabel("\(amount) gifts")
                    .accessibilityAddTraits(quantity == amount ? .isSelected : [])
            }
            TextField("1–99", text: $quantityText)
                .font(.tati(.subheadline).weight(.semibold)).monospacedDigit().multilineTextAlignment(.center)
                .keyboardType(.numberPad).focused($editingQuantity)
                .frame(width: 56, height: 44)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.tatiOlive.opacity(0.2), lineWidth: 1) }
                .accessibilityLabel("Custom gift quantity, 1 to 99")
                .onChange(of: quantityText) { _, value in
                    let digits = String(value.filter { $0.isASCII && $0.isNumber }.prefix(2))
                    if value != digits { quantityText = digits }
                }
        }
    }

    private func playGift() {
        guard let selected else { return }
        editingQuantity = false
        let gift = selected
        store.requestGift(gift, quantity: quantity, recipient: recipient.id, roomID: roomID,
                          recharge: { showRecharge = true }, completed: {
            if let onGiftSaved { onGiftSaved() }
            else { store.celebrate("Effect unlocked", "Your coin balance and gift history have been updated.", artwork: gift.artwork) }
        })
    }
}
@MainActor final class LocalRoomAudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playing = false
    @Published private(set) var muted = false
    @Published private(set) var title = "No audio selected"
    @Published private(set) var revision = UUID()
    private var player: AVAudioPlayer?
    private var audioOwner: UUID?
    @Published private(set) var starting = false
    var hasSelection: Bool { player != nil }
    func load(_ url: URL) throws {
        let limit = 50 * 1024 * 1024
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= limit else { throw CocoaError(.fileReadTooLarge) }
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        guard bytes.count <= limit else { throw CocoaError(.fileReadTooLarge) }
        let replacement = try AVAudioPlayer(data: bytes)

        stop()
        player = replacement
        replacement.delegate = self
        replacement.volume = muted ? 0 : 1
        title = url.deletingPathExtension().lastPathComponent
    }
    func reset() { stop(); player = nil; title = "No audio selected"; muted = false; revision = UUID() }
    func toggleMuted() { muted.toggle(); player?.volume = muted ? 0 : 1 }
    func toggle() async throws {
        guard let player, !starting else { return }
        if playing { stop(); return }
        let token = UUID()
        audioOwner = token
        starting = true
        defer { if audioOwner == token { starting = false } }
        do {
            try await MediaAudioSession.shared.activate(owner: token, recording: false)
            guard audioOwner == token, !Task.isCancelled else {
                MediaAudioSession.shared.release(owner: token)
                if audioOwner == token { stop() }
                return
            }
            if player.currentTime >= player.duration { player.currentTime = 0 }
            guard player.play() else { throw CocoaError(.fileReadCorruptFile) }
            playing = true
        } catch {
            guard audioOwner == token else { return }
            stop()
            throw error
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in guard self?.player === player else { return }; self?.stop() }
    }
    func stop() {
        player?.pause(); playing = false
        starting = false
        if let owner = audioOwner {
            audioOwner = nil
            MediaAudioSession.shared.release(owner: owner)
        }
    }
}
struct RoomMusicPanel: View {
    @ObservedObject var player: LocalRoomAudio
    var isCurrentRoom: () -> Bool
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var importing = false
    @State private var sessionRevision: UUID?
    var body: some View {
        RoomControlSheet(title: "Listening music", subtitle: "Selected music is for your listening only.") {
            HStack(spacing: 14) {
                Art(name: "music-disc", width: 48, height: 48)
                VStack(alignment: .leading, spacing: 5) {
                    if player.hasSelection { Text(player.title).font(.tati(.headline)).lineLimit(3) }
                    else { Text("No audio selected").font(.tati(.headline)) }
                    Text(LocalizedStringKey(player.playing ? "Playing" : "Paused"))
                        .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18))
            Text("Choose an audio file up to 50 MB.").font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
            TatiEditingButton(title: "Choose audio", enabled: !importing) { importing = true }
            HStack(spacing: 12) {
                TatiEditingButton(title: player.playing ? "Pause" : "Play", enabled: player.hasSelection && !player.starting) {
                    Task { @MainActor in
                        guard isCurrentRoom() else { return }
                        do { try await player.toggle() }
                        catch { if isCurrentRoom() { store.tell("Audio unavailable", "The audio couldn't be played. Try another file.") } }
                    }
                }
                TatiEditingButton(title: "Clear", enabled: player.hasSelection) {
                    guard isCurrentRoom() else { return }
                    player.reset(); sessionRevision = player.revision
                }
            }
        }.onAppear { sessionRevision = player.revision }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in

            guard isCurrentRoom(), sessionRevision == player.revision else { return }
            do {
                let url = try result.get()
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                try player.load(url)
            } catch {
                if (error as NSError).code != NSUserCancelledError {
                    store.tell("Audio not selected", "No playable audio was loaded. You can try another file.")
                }
            }
        }
    }
}

private struct RoomGiftEffect: View {
    let gift: TableCelebration
    let quantity: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    var body: some View {
        VStack(spacing: 12) {
            Art(name: gift.artwork, width: 170, height: 170)
            Text("\(gift.name) ×\(quantity)").font(.tati(.headline)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.tatiInk.opacity(0.8)).clipShape(Capsule())
        }.scaleEffect(revealed ? 1 : 0.65).opacity(revealed ? 1 : 0)
            .onAppear {
                if reduceMotion { revealed = true }
                else { withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { revealed = true } }
            }
    }
}
