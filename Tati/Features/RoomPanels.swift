import SwiftUI

/// Always crop the original to the actual container, including wide displays.
struct VoiceRoomBackgroundArtwork: View {
    var background: VoiceRoomBackground
    var body: some View {
        GeometryReader { geometry in
            Image(background.rawValue).resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }.accessibilityHidden(true)
    }
}

struct VoiceRoomBackgroundPicker: View {
    var selected: String
    var select: (VoiceRoomBackground) -> Void
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0, maximum: 180), spacing: 10), count: 3), spacing: 14) {
            ForEach(VoiceRoomBackground.allCases) { background in
                Button { select(background) } label: {
                    VStack(spacing: 8) {
                        VoiceRoomBackgroundArtwork(background: background)
                            .aspectRatio(0.58, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(selected == background.rawValue ? Color.tatiPink : .clear, lineWidth: 3)
                            }
                            .overlay(alignment: .topTrailing) {
                                if selected == background.rawValue {
                                    Art(name: "check-pink", width: 24, height: 24).padding(7)
                                }
                            }
                        Text(background.title).font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
                    .accessibilityLabel(background.title)
                    .accessibilityAddTraits(selected == background.rawValue ? .isSelected : [])
            }
        }
    }
}

struct CreateVoiceRoomView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var title = ""
    @State private var topic = "Home cooking"
    @State private var background: VoiceRoomBackground = .blue
    @State private var loaded = false
    @State private var showsBackground = false

    var body: some View {
        TatiEditingForm(title: "Create voice room") {
            TatiEditingField(label: "Room title", placeholder: "What shall we talk about?", text: $title, limit: 80)
            VStack(alignment: .leading, spacing: 10) {
                Text("Food topic").font(.subheadline.weight(.semibold))
                FilterTagLayout {
                    ForEach(Array(FoodCatalog.topics.dropFirst()), id: \.self) { value in
                        BrowseFilterChip(title: value, selected: topic == value) { topic = value }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Room atmosphere").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Button("View background") { showsBackground = true }
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.tatiOlive)
                        .frame(minHeight: 44).buttonStyle(.plain)
                }
                VoiceRoomBackgroundPicker(selected: background.rawValue) { background = $0 }
            }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 20))
        } footer: {
            TatiEditingButton(title: "Create room", enabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                guard saveSetup() else { return }
                // No publishing endpoint/RTC session exists yet; never invent a live room.
                store.tell("Room creation unavailable", "Your room title, topic and background are saved. Voice room creation is currently unavailable.")
            }
        }
        .onAppear {
            guard !loaded else { return }
            title = store.account.drafts["voice-create-title"] ?? ""
            let savedTopic = store.account.drafts["voice-create-topic"] ?? "Home cooking"
            topic = FoodCatalog.topics.dropFirst().contains(savedTopic) ? savedTopic : "Home cooking"
            background = store.account.drafts["voice-create-background"].flatMap(VoiceRoomBackground.init(rawValue:))
                ?? VoiceRoomBackground.allCases.randomElement() ?? .blue
            loaded = true
            _ = saveSetup()
        }
        .onChange(of: title) { _, _ in if loaded { _ = saveSetup() } }
        .onChange(of: topic) { _, _ in if loaded { _ = saveSetup() } }
        .onChange(of: background) { _, _ in if loaded { _ = saveSetup() } }
        .fullScreenCover(isPresented: $showsBackground) {
            ZStack(alignment: .topTrailing) {
                VoiceRoomBackgroundArtwork(background: background).ignoresSafeArea(.container)
                ArtButton(asset: "close-light", label: "Close background", size: 26) { showsBackground = false }
                    .padding(16)
            }
        }
    }

    private func saveSetup() -> Bool {
        guard store.account.drafts["voice-create-title"] != title
                || store.account.drafts["voice-create-topic"] != topic
                || store.account.drafts["voice-create-background"] != background.rawValue else { return true }
        return store.change {
            $0.drafts["voice-create-title"] = title
            $0.drafts["voice-create-topic"] = topic
            $0.drafts["voice-create-background"] = background.rawValue
        }
    }
}

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
                    if isVoice {
                        tool("tool-layout", "Room layout", .layout)
                        tool("tool-mic", "Mic queue", .microphone)
                    } else {
                        tool("tool-layout", "Viewing", .viewing)
                    }
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
struct RoomInvitePanel: View {
    var room: FoodRoom
    @EnvironmentObject private var store: VisitorStore
    private var following: [FoodPerson] { store.visiblePeople.filter { store.isFollowing($0.id) } }
    var body: some View {
        TatiPanel(title: "Invite friends") {
            if following.isEmpty { EmptyContent(title: "No followed profiles", detail: "Follow a profile to find it here.", artwork: "tool-invite") }
            ForEach(following) { person in
                HStack {
                    UserProfileLink(userID: person.id) { HStack { Avatar(asset: person.portraitArtwork); Text(person.name).font(.headline) } }.buttonStyle(.plain)
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

/// Playback preferences affect only this viewer and never create a broadcast session.
struct RoomViewingPanel: View {
    @Binding var fillsVideo: Bool
    @Binding var muted: Bool
    @Binding var showsActivity: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 330

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Viewing options").font(.title3.weight(.bold))
                    Spacer(minLength: 4)
                    ArtButton(asset: "close-light", label: "Close viewing options") { dismiss() }
                }
                option("Video size", detail: fillsVideo ? "Fill the screen; edges may be cropped" : "Show the whole video without cropping",
                       value: fillsVideo ? "Fill" : "Fit", selected: fillsVideo) { fillsVideo.toggle() }
                option("Video sound", detail: muted ? "Video audio is muted" : "Play the video's original sound",
                       value: muted ? "Off" : "On", selected: !muted) { muted.toggle() }
                option("Room activity", detail: "Messages and gift effects over the video",
                       value: showsActivity ? "Show" : "Hide", selected: showsActivity) { showsActivity.toggle() }
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: RoomPanelContentHeightKey.self, value: geometry.size.height)
                    }
                }
        }.foregroundStyle(Color.tatiInk).background(Color.tatiCream)
            .presentationBackground(Color.tatiCream).presentationCornerRadius(24)
            .presentationDragIndicator(.hidden)
            .presentationDetents([.height(contentHeight), .large])
            .onPreferenceChange(RoomPanelContentHeightKey.self) { height in
                if height > 0, abs(contentHeight - height) > 1 { contentHeight = height }
            }
            .accessibilityAction(.escape) { dismiss() }
    }

    private func option(_ title: String, detail: String, value: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(value).font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(selected ? Color.tatiLime : Color.tatiCream, in: Capsule())
            }.padding(14).frame(minHeight: 64)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(value)
            .accessibilityHint("Double tap to change")
    }
}
