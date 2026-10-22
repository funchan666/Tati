import SwiftUI

/// Always crop the original to the actual container, including wide displays.
struct VoiceRoomBackgroundArtwork: View {
    var background: ConversationBackdrop
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
    var select: (ConversationBackdrop) -> Void
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0, maximum: 180), spacing: 10), count: 3), spacing: 14) {
            ForEach(ConversationBackdrop.allCases) { background in
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
                        Text(background.title).font(.tati(.caption).weight(.semibold))
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
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var title = ""
    @State private var topic = "Home cooking"
    @State private var background: ConversationBackdrop = .blue
    @State private var loaded = false
    @State private var showsBackground = false

    var body: some View {
        TatiEditingForm(title: "Create voice room") {
            TatiEditingField(label: "Room title", placeholder: "What shall we talk about?", text: $title, limit: 80)
            VStack(alignment: .leading, spacing: 10) {
                Text("Food topic").font(.tati(.subheadline).weight(.semibold))
                FilterTagLayout {
                    ForEach(Array(TableCommunity.topics.dropFirst()), id: \.self) { value in
                        BrowseFilterChip(title: value, selected: topic == value) { topic = value }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Room atmosphere").font(.tati(.subheadline).weight(.semibold))
                    Spacer(minLength: 8)
                    Button("View background") { showsBackground = true }
                        .font(.tati(.caption).weight(.semibold)).foregroundStyle(Color.tatiOlive)
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
            topic = TableCommunity.topics.dropFirst().contains(savedTopic) ? savedTopic : "Home cooking"
            background = store.account.drafts["voice-create-background"].flatMap(ConversationBackdrop.init(rawValue:))
                ?? ConversationBackdrop.allCases.randomElement() ?? .blue
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

/// A shared presentation shell; room capabilities and state remain separate.
struct RoomControlSheet<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 360
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(title)).font(.tati(.title3).weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(LocalizedStringKey(subtitle)).font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    ArtButton(asset: "close-light", label: "Close", size: 22) { dismiss() }
                }
                content()
            }.padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: RoomPanelContentHeightKey.self, value: geometry.size.height)
                    }
                }
        }.scrollIndicators(.hidden).foregroundStyle(Color.tatiInk)
            .background { Color.tatiCream.ignoresSafeArea(.container) }
            .presentationBackground(Color.tatiCream).presentationCornerRadius(26)
            .presentationDragIndicator(.hidden)
            .presentationDetents([.height(min(560, contentHeight)), .large])
            .onPreferenceChange(RoomPanelContentHeightKey.self) { height in
                if height > 0, abs(height - contentHeight) > 1 { contentHeight = height }
            }
            .accessibilityAction(.escape) { dismiss() }
    }
}

struct RoomToolsPanel: View {
    var isVoice: Bool
    var select: (RoomPanel) -> Void
    var body: some View {
        RoomControlSheet(title: isVoice ? "Voice room tools" : "Live viewing",
                         subtitle: "Preferences for your room view") {
            VStack(spacing: 10) {
                if isVoice {
                    tool("tool-mic", "Voice input", "Turn your words into a message", .dictation)
                    tool("tool-background", "Background", "Choose your room atmosphere", .background)
                    tool("tool-music", "Listening music", "Play an audio file just for you", .music)
                } else {
                    tool("tool-layout", "Viewing options", "Picture size, original sound and activity", .viewing)
                }
            }
            VStack(spacing: 0) {
                secondary("feedback", "Report or block", .safety)
                Rectangle().fill(Color.tatiOlive.opacity(0.12)).frame(height: 0.5).padding(.horizontal, 14)
                secondary("tool-leave", "Leave room", .leave)
            }.background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
        }
    }
    private func tool(_ art: String, _ title: String, _ detail: String, _ destination: RoomPanel) -> some View {
        Button { select(destination) } label: {
            HStack(spacing: 14) {
                Art(name: art, width: 42, height: 42)
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(title)).font(.tati(.subheadline).weight(.semibold))
                    Text(LocalizedStringKey(detail)).font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "chevron", width: 9, height: 13)
            }.padding(14).frame(minHeight: 76)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
    private func secondary(_ art: String, _ title: String, _ destination: RoomPanel) -> some View {
        Button { select(destination) } label: {
            HStack(spacing: 12) {
                Art(name: art, width: 24, height: 24)
                Text(LocalizedStringKey(title)).font(.tati(.subheadline).weight(.medium))
                Spacer(minLength: 0)
                Art(name: "chevron", width: 9, height: 13)
            }.padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 52)
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

struct RoomLeavePanel: View {
    var isVoice: Bool
    var minimize: () -> Void
    var leave: () -> Void
    var stay: () -> Void
    var body: some View {
        RoomControlSheet(title: isVoice ? "Leave this voice room?" : "Leave this live room?",
                         subtitle: isVoice ? "You can minimize the room and return later." : "Video playback stops when you leave.") {
            VStack(spacing: 10) {
                if isVoice { action("Minimize room", primary: false, perform: minimize) }
                action("Leave room", primary: true, perform: leave)
                action("Stay here", primary: false, perform: stay)
            }
        }
    }
    private func action(_ title: String, primary: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(LocalizedStringKey(title)).font(.tati(.subheadline).weight(.semibold))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(primary ? Color.tatiPink : .white, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct RoomActivityFeed: View {
    var room: CookingRoom
    var isActive: Bool
    var maximumHeight: CGFloat = 160
    var maximumWidth: CGFloat = 320
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var timeline: [RoomConversationCue] = []
    @State private var timelineRoomID = ""
    @State private var nextScriptIndex = 0
    @State private var knownLocalIDs: Set<String> = []
    @State private var readingHistory = false

    // Authored room presentation never enters account messages, receipts or balances.
    private var script: [RoomConversationCue] {
        KitchenEditorialLibrary.shared.curatedRoomActivity?[room.id] ?? []
    }
    private var localEntries: [RoomConversationCue] {
        var local: [(Date, RoomConversationCue)] = (store.account.roomMessages ?? [])
            .filter { $0.roomID == room.id }
            .map { message in
                (message.createdAt, RoomConversationCue(id: message.id, authorID: store.account.profile.id, text: message.text, isEditorial: false))
            }
        local += store.account.gifts.filter { $0.roomID == room.id }.map { receipt in
            (receipt.date, RoomConversationCue(id: receipt.id, authorID: store.account.profile.id, text: "", giftID: receipt.giftID, quantity: receipt.quantity, isEditorial: false))
        }
        local.sort { $0.0 == $1.0 ? $0.1.id < $1.1.id : $0.0 < $1.0 }
        return local.suffix(100).map { $0.1 }.filter(isAllowed)
    }
    private var entries: [RoomConversationCue] {
        let available = Set((script + localEntries).map(\.id))
        return timeline.filter { available.contains($0.id) && isAllowed($0) }
    }
    private var playbackKey: String { "\(room.id)|\(isActive && scenePhase == .active && !readingHistory)" }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 5) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(entries) { entry in
                            UserProfileLink(userID: entry.authorID) { activityRow(entry) }
                                .buttonStyle(.plain).id(entry.id)
                                .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
                        }
                    }.padding(.vertical, 3).frame(maxWidth: .infinity, alignment: .leading)
                }.scrollIndicators(.hidden)
                    .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in readingHistory = true })
                if readingHistory {
                    Button {
                        readingHistory = false
                        scrollToLatest(proxy)
                    } label: {
                        Text("Latest activity").font(.tati(.caption).weight(.semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .background(.black.opacity(0.65), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }
            .onChange(of: entries.map(\.id)) { _, _ in
                if !readingHistory { scrollToLatest(proxy) }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: maximumWidth).frame(height: maximumHeight, alignment: .bottomLeading)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)
        .task(id: playbackKey) {
            prepareTimeline()
            guard isActive, scenePhase == .active, !readingHistory, !script.isEmpty else { return }
            // The view owns this task: leaving, opening a panel or backgrounding cancels it.
            while !Task.isCancelled {
                let entry = script[nextScriptIndex % script.count]
                do { try await Task.sleep(for: .seconds(min(8, max(2, entry.delaySeconds ?? 4)))) }
                catch { return }
                guard !Task.isCancelled, isActive, scenePhase == .active else { return }
                guard !readingHistory else { continue }
                nextScriptIndex = (nextScriptIndex + 1) % script.count
                if isAllowed(entry) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { append(entry) }
                }
            }
        }
        .onChange(of: localEntries.map(\.id)) { _, _ in
            let incoming = localEntries.filter { !knownLocalIDs.contains($0.id) }
            knownLocalIDs = Set(localEntries.map(\.id))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                for entry in incoming { append(entry) }
            }
        }
    }
    private func prepareTimeline() {
        guard timelineRoomID != room.id else { return }
        timelineRoomID = room.id
        readingHistory = false
        let opening = Array(script.filter(isAllowed).prefix(4))
        timeline = opening + localEntries.suffix(3)
        knownLocalIDs = Set(localEntries.map(\.id))
        nextScriptIndex = opening.last.flatMap { last in script.firstIndex(where: { $0.id == last.id }) }.map { $0 + 1 } ?? 0
    }
    private func append(_ entry: RoomConversationCue) {
        // Replaying a script moves its stable event; it never duplicates receipt IDs.
        timeline.removeAll { $0.id == entry.id }
        timeline.append(entry)
        timeline = Array(timeline.suffix(30))
    }
    private func isAllowed(_ entry: RoomConversationCue) -> Bool {
        !store.isPersonHidden(entry.authorID) && !store.isHidden("roomMessage:" + entry.id)
    }
    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let last = entries.last else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
    @ViewBuilder private func activityRow(_ entry: RoomConversationCue) -> some View {
        let person = TableCommunity.person(entry.authorID)
        let current = !entry.isEditorial && entry.authorID == store.account.profile.id
        let name = current ? "\(store.account.profile.name) · You" : person?.name ?? "Guest"
        if let giftID = entry.giftID, let gift = TableCommunity.gift(giftID) {
            HStack(spacing: 7) {
                Avatar(file: current ? store.account.profile.avatarFile : nil, asset: person?.portraitArtwork, size: 30, isCurrent: current)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.tati(size: 12, weight: .semibold)).foregroundStyle(Color.tatiCream).lineLimit(1)
                    Text(LocalizedStringKey(gift.name))
                        .font(.tati(size: 10)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Art(name: gift.artwork, width: 42, height: 42)
                Text("×\(entry.quantity)").font(.tati(size: 15, weight: .bold)).foregroundStyle(.white)
            }.padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: 280)
                .background(.black.opacity(0.56)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.tatiPink.opacity(0.45), lineWidth: 0.7) }
                .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .center, spacing: 6) {
                Avatar(file: current ? store.account.profile.avatarFile : nil, asset: person?.portraitArtwork, size: 22, isCurrent: current)
                (Text(name + ": ").fontWeight(.medium).foregroundColor(.tatiCream) + Text(entry.text))
                    .font(.tati(size: 12)).fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 9).padding(.vertical, 7)
                .background(.black.opacity(0.52)).clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
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
                    Text("Viewing options").font(.tati(.title3).weight(.bold))
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
                    Text(LocalizedStringKey(title)).font(.tati(.subheadline).weight(.semibold))
                    Text(LocalizedStringKey(detail)).font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(LocalizedStringKey(value)).font(.tati(.caption).weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(selected ? Color.tatiLime : Color.tatiCream, in: Capsule())
            }.padding(14).frame(minHeight: 64)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(Text(LocalizedStringKey(title))).accessibilityValue(Text(LocalizedStringKey(value)))
            .accessibilityHint("Double tap to change")
    }
}
