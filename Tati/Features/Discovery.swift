import SwiftUI

struct DiscoverView: View {
    var voice: Bool
    @EnvironmentObject private var store: VisitorStore
    @State private var selected = "Hot"
    @State private var topic = "All"
    @State private var country = "All"
    @State private var language = "All"
    @State private var showFilter = false
    @State private var showPublish = false
    @State private var showTopic = false
    private var sections: [String] { voice ? ["Party", "Food", "Follow"] : ["Hot", "Discover", "Follow"] }
    private var currentSection: String { sections.contains(selected) ? selected : sections[0] }
    var rooms: [FoodRoom] {
        store.visibleRooms.filter { room in
            let host = FoodCatalog.person(room.hostID)
            return room.isVoice == voice && !store.account.blocked.contains(room.hostID)
                && (currentSection != "Follow" || store.account.following.contains(room.hostID))
                && (currentSection != "Food" || room.foodFocused)
                && (topic == "All" || room.topic == topic)
                && (country == "All" || host?.city == country)
                && (language == "All" || host?.language == language)
        }.sorted { selected == "Discover" ? $0.title < $1.title : $0.id < $1.id }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Art(name: voice ? "chat-heading" : "brand-heading", width: voice ? 140 : 168, height: voice ? 58 : 48, alignment: .leading)
                    Spacer()
                    if voice {
                        ArtButton(asset: "publish", label: "Create a room", size: 32) { showPublish = true }
                    } else {
                        NavigationLink(destination: SearchView()) { Art(name: "search", width: 29, height: 29).frame(width: 44, height: 44) }.accessibilityLabel("Search")
                        NavigationLink(destination: RankingView()) { Art(name: "rank-entry", width: 44, height: 38).frame(minHeight: 44) }.accessibilityLabel("Rankings")
                    }
                }
                HStack(spacing: 22) {
                    ForEach(sections, id: \.self) { value in
                        Button { selected = value } label: {
                            Text(value).font(.system(size: 15, weight: currentSection == value ? .bold : .regular))
                                .foregroundStyle(currentSection == value ? Color.tatiInk : Color.tatiOlive.opacity(0.6))
                                .padding(.vertical, 8)
                                .background(alignment: .bottom) { if currentSection == value { Color.tatiLime.frame(height: 3) } }
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                    ArtButton(asset: "filter", label: "Filter rooms", size: 26) { showFilter = true }
                }
                if voice {
                    ImageAction(asset: "topic-banner", label: "Browse food topics", height: 66) { showTopic = true }
                }
                if ContentLibrary.unavailable { Note(text: "Content could not be loaded.") }
                if rooms.isEmpty { EmptyContent(title: "No rooms here yet", detail: selected == "Follow" ? "Rooms from profiles you follow appear here." : "Try another topic or clear your filters.") }
                else if voice {
                    LazyVStack(spacing: 14) { ForEach(rooms) { room in RoomListCard(room: room, showsHotBanner: currentSection != "Follow") } }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(rooms) { room in LiveRoomCard(room: room) }
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .onChange(of: voice) { _, _ in selected = voice ? "Party" : "Hot" }
        .sheet(isPresented: $showTopic) { NavigationStack { HotTopicView() }.overlay { NoticeLayer() }.presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showFilter) {
            FilterView(topic: $topic, country: $country, language: $language)
        }
        .sheet(isPresented: $showPublish) {
            PublishSheet()
        }
    }
}
struct LiveRoomCard: View {
    var room: FoodRoom
    private var host: FoodPerson? { FoodCatalog.person(room.hostID) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                NavigationLink(destination: RoomView(room: room)) {
                    ContentPhoto(asset: room.coverArtwork, height: geometry.size.height)
                        .overlay(alignment: .bottom) {
                            HStack(spacing: 3) {
                                Text(host?.language ?? "").font(.system(size: 9))
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Color.tatiLime).foregroundStyle(Color.tatiOlive)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                Spacer(minLength: 0)
                                RoomTopicTag(topic: room.topic)
                            }.padding(7)
                        }
                        .overlay(alignment: .topLeading) { RoomKindBadge(isVoice: false).padding(8) }
                }.buttonStyle(.plain).accessibilityLabel("Enter " + room.title)
                    .overlay(alignment: .bottomLeading) {
                        UserProfileLink(userID: room.hostID) {
                            HStack(spacing: 5) {
                                Avatar(asset: host?.portraitArtwork, size: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(host?.name ?? "Creator").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    Text(host?.city ?? "").font(.system(size: 9)).lineLimit(1)
                                }
                            }.frame(minHeight: 44, alignment: .bottom)
                        }.padding(.horizontal, 7).padding(.bottom, 27)
                            .foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }.aspectRatio(0.86, contentMode: .fit)
            NavigationLink(destination: RoomView(room: room)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(room.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(host?.bio ?? "").font(.system(size: 9)).foregroundStyle(Color.tatiOlive.opacity(0.6)).lineLimit(1)
                }.padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
        }.background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.tatiOlive.opacity(0.65), lineWidth: 0.6).allowsHitTesting(false) }
            .foregroundStyle(Color.tatiInk)
    }
}
struct RoomListCard: View {
    var room: FoodRoom
    var showsHotBanner = true
    private var host: FoodPerson? { FoodCatalog.person(room.hostID) }
    private var summary: String {
        switch room.id {
        case "dessert-club": return "Share cakes, bakes and sweet ideas"
        case "dinner-conversation": return "What's on your dinner table?"
        case "market-table": return "Fresh finds and seasonal favourites"
        case "weekend-bbq": return "Talk grills, spices and weekend plans"
        default: return host?.bio ?? ""
        }
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            // Stretch only the middle of the supplied card, keeping its corners intact.
            Image("outlined-card").resizable(capInsets: EdgeInsets(top: 26, leading: 30, bottom: 26, trailing: 30))
                .frame(height: 98).accessibilityHidden(true)
            HStack(alignment: .bottom, spacing: 12) {
                UserProfileLink(userID: room.hostID) { ContentPhoto(asset: room.coverArtwork, height: 90).frame(width: 90) }
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(alignment: .bottomTrailing) {
                        RoomKindBadge(isVoice: room.isVoice, compact: true).offset(x: 3, y: 3)
                    }
                    .overlay(alignment: .topLeading) {
                        if showsHotBanner { Art(name: "hot-room", width: 90, height: 31).offset(y: -16) }
                    }
                VStack(alignment: .leading, spacing: 6) {
                    NavigationLink(destination: RoomView(room: room)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(room.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                            Text(summary).font(.system(size: 11)).foregroundStyle(Color.tatiOlive.opacity(0.75)).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    HStack(spacing: 5) {
                        UserProfileLink(userID: room.hostID) {
                            HStack(spacing: 5) {
                                Avatar(asset: host?.portraitArtwork, size: 18)
                                Text(host?.name ?? "").font(.system(size: 10)).foregroundStyle(Color.tatiOlive).lineLimit(1)
                            }
                        }
                        RoomTopicTag(topic: room.topic)
                        Spacer(minLength: 0)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 66, alignment: .top)
            }.padding(.horizontal, 12).padding(.bottom, 12)
        }.frame(height: showsHotBanner ? 118 : 108, alignment: .bottom)
            .foregroundStyle(Color.tatiInk)
    }
}

private struct RoomTopicTag: View {
    var topic: String
    private var tint: Color {
        switch topic {
        case "Street food": return Color(red: 0.43, green: 0.29, blue: 0.96)
        case "Dessert": return Color.tatiPink
        case "Healthy food": return Color(red: 0.25, green: 0.73, blue: 0.35)
        default: return Color(red: 1, green: 0.68, blue: 0.19)
        }
    }
    var body: some View {
        Text(topic).font(.system(size: 9, weight: .medium)).lineLimit(1)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .foregroundStyle(.white).background(tint).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct FilterView: View {
    @Binding var topic: String
    @Binding var country: String
    @Binding var language: String
    @Environment(\.dismiss) private var dismiss
    @State private var draftTopic = "All"
    @State private var draftCity = "All"
    @State private var draftLanguage = "All"
    @State private var panelHeight: CGFloat = 340
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Find your people").font(.system(size: 19, weight: .bold, design: .serif))
                    Spacer(minLength: 0)
                    ArtButton(asset: "close-light", label: "Close") { dismiss() }
                }
                options("Label", items: FoodCatalog.cities, selection: $draftCity)
                options("Language", items: FoodCatalog.languages, selection: $draftLanguage)
                HStack(spacing: 10) {
                    TatiButton(title: "Reset", secondary: true) { draftTopic = "All"; draftCity = "All"; draftLanguage = "All" }.frame(width: 64)
                    TatiButton(title: "Apply") { topic = draftTopic; country = draftCity; language = draftLanguage; dismiss() }
                }.padding(.top, 10)
            }.padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 12)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: FilterPanelHeightKey.self, value: geometry.size.height)
                    }
                }
        }
        .foregroundStyle(Color.tatiInk)
        .background(Color.tatiLime)
        .presentationBackground(Color.tatiLime)
        .presentationCornerRadius(20)
        .presentationDragIndicator(.hidden)
        .presentationDetents([.height(panelHeight)])
        .onPreferenceChange(FilterPanelHeightKey.self) { height in
            if height > 0, abs(panelHeight - height) > 1 { panelHeight = height }
        }
        .accessibilityAction(.escape) { dismiss() }
        .onAppear { draftTopic = topic; draftCity = country; draftLanguage = language }
    }
    private func options(_ title: String, items: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 12)).padding(.bottom, 2)
            FilterTagLayout {
                ForEach(items, id: \.self) { value in
                    Button { selection.wrappedValue = value } label: {
                        Text(value).font(.system(size: 12)).lineLimit(1)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .foregroundStyle(.white)
                            .background(selection.wrappedValue == value ? Color.tatiPink : Color.tatiOlive.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(selection.wrappedValue == value ? .isSelected : [])
                }
            }
        }
    }
}
private struct FilterPanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Intrinsic-width tags wrap as whole labels, matching the Lanhu filter rows.
private struct FilterTagLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 354, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let available = max(1, width)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []
        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            let size = subview.sizeThatFits(ProposedViewSize(width: min(ideal.width, available), height: nil))
            if x > 0, x + size.width > available {
                x = 0; y += rowHeight; rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + 6
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: available, height: y + rowHeight), frames)
    }
}
struct ChoiceGrid: View {
    var items: [String]
    @Binding var selected: String
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))], spacing: 2) {
            ForEach(items, id: \.self) { value in Chip(text: value, selected: selected == value) { selected = value } }
        }
    }
}
struct SearchView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var query = ""
    @State private var category = "People"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ArtButton(asset: "back", label: "Back") { dismiss() }
                HStack(spacing: 8) {
                Art(name: "search", width: 19, height: 19)
                TextField("Search for food and users", text: $query).font(.system(size: 13)).textFieldStyle(.plain).tint(.white)
            }.padding(10).background(Color.tatiOlive.opacity(0.65)).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 6))
            }.padding(.leading, 4).padding(.trailing, 16)
            ScrollView {
            VStack(alignment: .leading, spacing: 10) {
            Text("Popular searches").font(.system(size: 18, weight: .bold, design: .serif))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(FoodCatalog.popularTopics.indices, id: \.self) { index in
                    let topic = FoodCatalog.popularTopics[index]
                    Button { query = topic.0; category = "People" } label: { Art(name: topic.1, height: 23).frame(minHeight: 32) }
                        .buttonStyle(.plain).accessibilityLabel("Search " + topic.0)
                }
            }
            Text(category == "People" ? "Creators" : category).font(.system(size: 18, weight: .bold, design: .serif))
            if !query.isEmpty { TopicStrip(items: ["People", "Rooms", "Videos"], selected: $category) }
            if category == "People" {
                let matches = store.visiblePeople.filter { !store.account.blocked.contains($0.id) && (query.isEmpty || ($0.name + $0.interest).localizedCaseInsensitiveContains(query)) }
                if matches.isEmpty { EmptyContent(title: "No people found", detail: "Try a different name or food interest.") }
                LazyVStack(spacing: 0) { ForEach(matches) { PersonRow(person: $0) } }
            } else if category == "Rooms" {
                let matches = store.visibleRooms.filter { !store.account.blocked.contains($0.hostID) && (query.isEmpty || ($0.title + $0.topic).localizedCaseInsensitiveContains(query)) }
                if matches.isEmpty { EmptyContent(title: "No rooms found", detail: "Try another food topic.") }
                ForEach(matches) { room in RoomListCard(room: room) }
            } else {
                let matches = store.visibleClips.filter { query.isEmpty || $0.caption.localizedCaseInsensitiveContains(query) }
                if matches.isEmpty { EmptyContent(title: "No videos found", detail: "Try another phrase.") }
                ForEach(matches) { clip in FeedVideoCard(clip: clip) }
            }
            }.padding(.horizontal, 18).padding(.bottom, 16).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
        }.background(Color.tatiCream).foregroundStyle(Color.tatiInk).tatiScreen()
            .onChange(of: query) { _, value in if value.isEmpty { category = "People" } }
    }
}
struct PersonRow: View {
    var person: FoodPerson
    private var hasVideoRoom: Bool { FoodCatalog.rooms.contains { !$0.isVoice && $0.hostID == person.id } }
    var body: some View {
        NavigationLink(destination: PersonProfileView(person: person)) {
            HStack(spacing: 10) {
                Avatar(asset: person.portraitArtwork, size: 46)
                VStack(alignment: .leading, spacing: 5) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 7) {
                            Text(person.name).font(.system(size: 13, weight: .medium))
                            Text(person.city).font(.system(size: 10)).foregroundStyle(Color.tatiPink)
                            if hasVideoRoom { Art(name: "live-pink", width: 34, height: 16) }
                        }.fixedSize()
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(person.city).font(.system(size: 10)).foregroundStyle(Color.tatiPink).lineLimit(1)
                        }
                    }
                    Text(person.interest).font(.system(size: 11)).foregroundStyle(Color.tatiOlive.opacity(0.65)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Art(name: "chevron", width: 10, height: 14).frame(width: 20)
            }.foregroundStyle(Color.tatiInk).padding(.vertical, 10)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) { Color.tatiOlive.opacity(0.15).frame(height: 0.5) }
        }.buttonStyle(.plain).accessibilityLabel("View \(person.name), \(person.city), \(person.interest)")
    }
}
private struct RankingEntry: Identifiable {
    let id: String
    let person: FoodPerson
    let room: FoodRoom?
    let title: String
    let detail: String
    let metric: String
    let contentCount: Int
    let interactions: Int
}

struct RankingView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var category = "Activity"
    @State private var period = "Daily"
    @Environment(\.dismiss) private var dismiss

    // The catalogue supplies real content counts. Only saved interactions enter
    // the selected time window; this is not a server popularity/earnings ranking.
    private var entries: [RankingEntry] {
        let calendar = Calendar.current
        let component: Calendar.Component = period == "Daily" ? .day : .weekOfYear
        let interval = calendar.dateInterval(of: component, for: Date())
        let gifts = store.account.gifts.filter { interval?.contains($0.date) == true }
        let messages = (store.account.roomMessages ?? []).filter { interval?.contains($0.createdAt) == true }
        let rooms = store.visibleRooms.filter { !store.account.blocked.contains($0.hostID) }
        let result: [RankingEntry]
        if category == "Rooms" {
            result = rooms.compactMap { room in
                guard let person = FoodCatalog.person(room.hostID) else { return nil }
                let interactionCount = gifts.filter { $0.roomID == room.id }.reduce(0) { $0 + $1.quantity }
                    + messages.filter { $0.roomID == room.id }.count
                return RankingEntry(id: room.id, person: person, room: room, title: room.title,
                                    detail: person.name, metric: room.isVoice ? "Voice" : "Video",
                                    contentCount: room.videoClip == nil ? 0 : 1, interactions: interactionCount)
            }
        } else {
            result = store.visiblePeople.filter { !store.account.blocked.contains($0.id) }.map { person in
                let hosted = rooms.filter { $0.hostID == person.id }
                let clipCount = store.visibleClips.filter { $0.authorID == person.id }.count
                let contentCount = hosted.count + clipCount + (person.portraitArtwork == nil ? 0 : 1)
                let roomIDs = Set(hosted.map(\.id))
                let interactionCount = gifts.filter { $0.recipientID == person.id }.reduce(0) { $0 + $1.quantity }
                    + messages.filter { roomIDs.contains($0.roomID) }.count
                return RankingEntry(id: person.id, person: person, room: nil, title: person.name,
                                    detail: person.city, metric: "\(contentCount) \(contentCount == 1 ? "item" : "items")",
                                    contentCount: contentCount, interactions: interactionCount)
            }
        }
        return result.sorted {
            if category != "Creators", $0.interactions != $1.interactions { return $0.interactions > $1.interactions }
            if $0.contentCount != $1.contentCount { return $0.contentCount > $1.contentCount }
            if $0.interactions != $1.interactions { return $0.interactions > $1.interactions }
            return $0.id < $1.id
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, 520)
            let scale = width / 390
            let ranked = entries
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ArtButton(asset: "back", label: "Back") { dismiss() }
                        TopicStrip(items: ["Activity", "Creators", "Rooms"], selected: $category)
                    }.padding(.horizontal, 8)
                    HStack(spacing: 0) {
                        ForEach(["Daily", "Weekly"], id: \.self) { value in
                            Button { period = value } label: {
                                Text(value).font(.system(size: 15)).frame(maxWidth: .infinity, minHeight: 36)
                                    .foregroundStyle(period == value ? .white : Color.tatiOlive.opacity(0.5))
                                    .background(period == value ? Color.tatiOlive : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain).accessibilityAddTraits(period == value ? .isSelected : [])
                        }
                    }.padding(4).background(Color.tatiCream.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 44)
                    if ranked.isEmpty {
                        EmptyContent(title: "No profiles available", detail: "Profiles and rooms will appear here when available.")
                    } else {
                        HStack(alignment: .top, spacing: 0) {
                            podium(ranked, index: 1, scale: scale)
                                .padding(.top, max(100, 340 * scale - geometry.safeAreaInsets.top - 112))
                            podium(ranked, index: 0, scale: scale)
                                .padding(.top, max(24, 256 * scale - geometry.safeAreaInsets.top - 112))
                            podium(ranked, index: 2, scale: scale)
                                .padding(.top, max(100, 340 * scale - geometry.safeAreaInsets.top - 112))
                        }.frame(height: max(300, 500 * scale - geometry.safeAreaInsets.top - 112), alignment: .top)
                        LazyVStack(spacing: 0) {
                            ForEach(Array(ranked.dropFirst(3).enumerated()), id: \.element.id) { index, entry in
                                rankingLink(entry) {
                                    HStack(spacing: 10) {
                                        Text("\(index + 4)").font(.system(size: 15, weight: .bold))
                                            .frame(width: 28, height: 28).background(Color.tatiLime)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                        Avatar(asset: entry.person.portraitArtwork, size: 46)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.title).font(.system(size: 15, weight: .medium)).lineLimit(2)
                                            Text(entry.detail).font(.system(size: 10)).foregroundStyle(Color.tatiOlive).lineLimit(1)
                                        }
                                        Spacer(minLength: 4)
                                        Text(entry.metric).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                    }.padding(.vertical, 12).contentShape(Rectangle())
                                        .overlay(alignment: .bottom) { Color.tatiOlive.opacity(0.14).frame(height: 0.5) }
                                }
                            }
                        }.padding(.horizontal, 18)
                    }
                }.padding(.top, geometry.safeAreaInsets.top).padding(.bottom, 20)
                    .frame(width: width).frame(maxWidth: .infinity)
                    .background(alignment: .top) {
                        // Keep artwork and podium scrolling together at the
                        // original width-based scale, independent of screen height.
                        Image("rank-background").resizable()
                            .frame(width: width, height: width * 1688 / 780)
                            .accessibilityHidden(true)
                    }
            }.ignoresSafeArea(.container, edges: .top)
                .background { Color.tatiCream.ignoresSafeArea(.container) }
        }.foregroundStyle(Color.tatiInk).tatiScreen()
    }

    private func podium(_ ranked: [RankingEntry], index: Int, scale: CGFloat) -> some View {
        Group {
            if ranked.indices.contains(index) {
                let entry = ranked[index]
                rankingLink(entry) {
                    VStack(spacing: 5) {
                        Avatar(asset: entry.person.portraitArtwork, size: (index == 0 ? 56 : 48) * scale)
                            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                        Text("\(index + 1)").font(.system(size: 11, weight: .bold))
                            .frame(width: 22, height: 22).background(Color.tatiLime).clipShape(Circle())
                        Text(entry.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                        Text(entry.detail).font(.system(size: 10)).lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3).background(Color.tatiLime)
                        Text(entry.metric).font(.system(size: 14, weight: .semibold))
                    }.multilineTextAlignment(.center).padding(.horizontal, 5)
                }
            } else { Color.clear.frame(height: 1) }
        }.frame(maxWidth: .infinity)
    }

    private func rankingLink<Label: View>(_ entry: RankingEntry, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink {
            PersonProfileView(person: entry.person)
        } label: { label() }.buttonStyle(.plain)
    }
}

struct HotTopicView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPanel(title: "Hot topic") {
            Art(name: "topic-banner")
            Text("Late-night snack: sweet or savoury?").font(.title3.bold())
            ForEach(store.visibleRooms.filter { $0.isVoice && $0.foodFocused && !store.account.blocked.contains($0.hostID) }) { room in
                RoomListCard(room: room)
            }
        }
    }
}
