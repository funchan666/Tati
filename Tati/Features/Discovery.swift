import SwiftUI

struct DiscoverView: View {
    var voice: Bool
    @EnvironmentObject private var store: VisitorStore
    @State private var selection = RoomBrowseSelection()
    @SceneStorage("tati.discovery.home.filters") private var homeFilters = ""
    @SceneStorage("tati.discovery.voice.filters") private var voiceFilters = ""
    @State private var showFilter = false
    @State private var showSearch = false
    // Food topics share the same filter on both feeds, rather than a competing Food tab.
    private var sections: [String] { voice ? ["Party", "Follow"] : ["Hot", "Discover", "Follow"] }
    private var currentSection: String { sections.contains(selection.section) ? selection.section : sections[0] }
    private var availableRooms: [FoodRoom] {
        store.visibleRooms.filter { $0.isVoice == voice && !store.account.blocked.contains($0.hostID) }
    }
    private var rooms: [FoodRoom] {
        selection.matching(availableRooms, following: store.followingIDs)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    discoveryHeader(logoWidth: voice ? 140 : 168)
                    discoveryHeader(logoWidth: 112)
                }
                if !voice { createLiveEntry.padding(.vertical, 6) }
                browseControls
                if voice {
                    voiceTopicPrompt.padding(.bottom, 4)
                }
                if ContentLibrary.unavailable { Note(text: "Content could not be loaded.") }
                if rooms.isEmpty {
                    EmptyContent(title: selection.activeCount > 0 ? "No matching rooms" : "No rooms here yet",
                                 detail: selection.activeCount > 0 ? "Try a different food topic, city or language." : currentSection == "Follow" ? "Rooms from profiles you follow appear here." : "Check back for more rooms.")
                    if selection.activeCount > 0 {
                        Button("Clear filters") { selection.clearFilters() }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.tatiOlive)
                            .frame(minHeight: 44).frame(maxWidth: .infinity).buttonStyle(.plain)
                    }
                }
                else if voice {
                    LazyVStack(spacing: 14) { ForEach(rooms) { room in RoomListCard(room: room, showsHotBanner: currentSection != "Follow") } }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(rooms) { room in LiveRoomCard(room: room) }
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .onChange(of: voice, initial: true) { _, _ in
            let saved = voice ? voiceFilters : homeFilters
            var restored = saved.data(using: .utf8).flatMap { try? JSONDecoder().decode(RoomBrowseSelection.self, from: $0) }
                ?? RoomBrowseSelection()
            if !sections.contains(restored.section) { restored.section = sections[0] }
            if !FoodCatalog.topics.contains(restored.topic) { restored.topic = "All" }
            if !FoodCatalog.cities.contains(restored.city) { restored.city = "All" }
            if !FoodCatalog.languages.contains(restored.language) { restored.language = "All" }
            selection = restored
        }
        .onChange(of: selection) { _, value in
            guard let data = try? JSONEncoder().encode(value), let saved = String(data: data, encoding: .utf8) else { return }
            if voice { voiceFilters = saved } else { homeFilters = saved }
        }
        .sheet(isPresented: $showFilter) {
            FilterView(selection: $selection, sections: sections, rooms: availableRooms)
        }
        .navigationDestination(isPresented: $showSearch) { SearchView() }
    }

    private var createLiveEntry: some View {
        NavigationLink(destination: GoLiveView()) {
            HStack(spacing: 12) {
                Art(name: "add-video", width: 30, height: 30)
                    .frame(width: 48, height: 48)
                    .background(Color.tatiLime, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create a live room").font(.subheadline.weight(.bold))
                    Text("Set the scene for your next food story.")
                        .font(.caption).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "chevron", width: 10, height: 14)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.tatiInk)
                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
                .contentShape(RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
            .accessibilityHint("Choose a cover, add a title and preview your camera")
    }

    private func discoveryHeader(logoWidth: CGFloat) -> some View {
        HStack(spacing: 4) {
            Art(name: voice ? "chat-heading" : "brand-heading", width: logoWidth, height: voice ? 58 : 48, alignment: .leading)
            Spacer(minLength: 0)
            MessagesToolbarEntry()
            if voice {
                NavigationLink(destination: CreateVoiceRoomView()) {
                    Art(name: "publish", width: 32, height: 32).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Create a voice room")
            } else {
                Button { showSearch = true } label: {
                    Art(name: "search", width: 29, height: 29).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Search")
                NavigationLink(destination: RankingView()) { Art(name: "rank-entry", width: 44, height: 38).frame(minHeight: 44) }.accessibilityLabel("Rankings")
            }
        }
    }

    private var voiceTopicPrompt: some View {
        Button { showFilter = true } label: {
            HStack(spacing: 10) {
                Art(name: "food-flame", width: 26, height: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hot topic").font(.caption.weight(.bold)).foregroundStyle(Color.tatiInk)
                    Text("Late-night snack: sweet or savory?")
                        .font(.footnote).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "chevron", width: 8, height: 13)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
            .accessibilityLabel("Hot topic. Late-night snack: sweet or savory?")
            .accessibilityHint("Opens food, city and language filters")
    }

    private var browseControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 26) {
                    ForEach(sections, id: \.self) { value in
                        Button { selection.section = value } label: {
                            Text(LocalizedStringKey(value))
                                .font(.title3.weight(currentSection == value ? .bold : .medium))
                                .foregroundStyle(currentSection == value ? Color.tatiInk : Color.tatiOlive)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                                .padding(.bottom, 3)
                                .overlay(alignment: .bottomLeading) {
                                    if currentSection == value {
                                        Capsule().fill(Color.tatiPink).frame(width: 24, height: 3)
                                    }
                                }
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(currentSection == value ? .isSelected : [])
                    }
                }
            }
            HStack(spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(FoodCatalog.topics, id: \.self) { value in
                                DiscoveryTopicTab(title: value == "All" ? "All food" : value,
                                                  selected: selection.topic == value) {
                                    selection.topic = value
                                }.id(value)
                            }
                        }
                    }
                    // A selection made in the sheet must remain visible in the feed.
                    .onChange(of: selection.topic) { _, value in proxy.scrollTo(value, anchor: .center) }
                    .onAppear { proxy.scrollTo(selection.topic, anchor: .center) }
                }
                Rectangle().fill(Color.tatiOlive.opacity(0.18)).frame(width: 1, height: 20)
                    .accessibilityHidden(true)
                Button { showFilter = true } label: {
                    Art(name: "filter", width: 23, height: 23)
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            if selection.activeCount > 0 {
                                Text("\(selection.activeCount)")
                                    .font(.caption2.weight(.bold)).monospacedDigit()
                                    .foregroundStyle(Color.tatiInk)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.tatiLime, in: Capsule())
                            }
                        }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel("Filters")
                    .accessibilityValue("\(selection.activeCount) active")
            }
            if selection.city != "All" || selection.language != "All" {
                FilterTagLayout {
                    if selection.city != "All" { appliedCondition(selection.city, kind: "City") { selection.city = "All" } }
                    if selection.language != "All" { appliedCondition(selection.language, kind: "Language") { selection.language = "All" } }
                    Button("Clear all") { selection.clearFilters() }
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.tatiOlive)
                        .padding(.horizontal, 6).frame(minHeight: 44).buttonStyle(.plain)
                }
            }
        }.padding(.top, 4).padding(.bottom, 2)
    }

    private func appliedCondition(_ title: String, kind: String, clear: @escaping () -> Void) -> some View {
        Button(action: clear) {
            HStack(spacing: 6) {
                Text(LocalizedStringKey(title)).font(.caption.weight(.medium))
                Art(name: "close-light", width: 16, height: 16)
            }.padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.white.opacity(0.8), in: Capsule())
                .frame(minHeight: 44)
        }.buttonStyle(.plain).foregroundStyle(Color.tatiInk)
            .accessibilityLabel("Remove \(kind) filter: \(title)")
    }
}

/// Feed categories stay visually light; the filter sheet retains its larger form controls.
private struct DiscoveryTopicTab: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title)).font(.footnote.weight(selected ? .bold : .medium))
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(selected ? Color.tatiCream : Color.tatiInk)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? Color.tatiInk : Color.clear, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(selected ? Color.clear : Color.tatiOlive.opacity(0.24), lineWidth: 1)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
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
        HStack(spacing: 0) {
            // The cover receives the full row height, including taller wrapped copy.
            GeometryReader { geometry in
                UserProfileLink(userID: room.hostID) {
                    ContentPhoto(asset: room.coverArtwork, height: geometry.size.height)
                }
                .overlay(alignment: .topLeading) {
                    if showsHotBanner {
                        Art(name: "hot-room", width: 88, height: 30)
                            .padding(.leading, 5).padding(.top, 4).allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    RoomKindBadge(isVoice: room.isVoice, compact: true)
                        .padding(8).allowsHitTesting(false)
                }
            }.frame(width: 104)

            VStack(alignment: .leading, spacing: 5) {
                NavigationLink(destination: RoomView(room: room)) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(room.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                        Text(summary).font(.caption).foregroundStyle(Color.tatiOlive).lineLimit(2)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        hostIdentity
                        RoomTopicTag(topic: room.topic).fixedSize()
                    }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 2) {
                        hostIdentity
                        RoomTopicTag(topic: room.topic)
                    }
                }
            }.padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background {
            // Reuse the supplied gradient artwork; one outer edge encloses photo and text.
            Image("outlined-card").resizable(capInsets: EdgeInsets(top: 26, leading: 30, bottom: 26, trailing: 30))
                .padding(-8).accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.tatiOlive.opacity(0.4), lineWidth: 0.6)
                .allowsHitTesting(false)
        }
        .foregroundStyle(Color.tatiInk)
    }

    private var hostIdentity: some View {
        UserProfileLink(userID: room.hostID) {
            HStack(spacing: 5) {
                Avatar(asset: host?.portraitArtwork, size: 20)
                Text(host?.name ?? "").font(.caption).foregroundStyle(Color.tatiOlive).lineLimit(1)
            }.frame(minHeight: 44)
        }
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
        Text(LocalizedStringKey(topic)).font(.system(size: 9, weight: .medium)).lineLimit(1)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .foregroundStyle(.white).background(tint).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct RoomBrowseSelection: Codable, Equatable {
    var section = "Hot"
    var topic = "All"
    var city = "All"
    var language = "All"

    var activeCount: Int { [topic, city, language].filter { $0 != "All" }.count }

    mutating func clearFilters() {
        topic = "All"
        city = "All"
        language = "All"
    }

    func matching(_ rooms: [FoodRoom], following: Set<String>) -> [FoodRoom] {
        rooms.filter { room in
            let host = FoodCatalog.person(room.hostID)
            return (section != "Follow" || following.contains(room.hostID))
                && (topic == "All" || room.topic == topic)
                && (city == "All" || host?.city == city)
                && (language == "All" || host?.language == language)
        }.sorted { section == "Discover" ? $0.title < $1.title : $0.id < $1.id }
    }
}

struct BrowseFilterChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(LocalizedStringKey(title)).font(.subheadline.weight(selected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                if selected { Art(name: "check-pink", width: 16, height: 16) }
            }.padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 44)
                .foregroundStyle(Color.tatiInk)
                .background(selected ? Color.tatiLime : Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct FilterView: View {
    @Binding var selection: RoomBrowseSelection
    var sections: [String]
    var rooms: [FoodRoom]
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RoomBrowseSelection

    init(selection: Binding<RoomBrowseSelection>, sections: [String], rooms: [FoodRoom]) {
        _selection = selection
        self.sections = sections
        self.rooms = rooms
        _draft = State(initialValue: selection.wrappedValue)
    }

    private var matchCount: Int { draft.matching(rooms, following: store.followingIDs).count }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find your table").font(.title2.weight(.bold))
                    Text("Food, places & people you enjoy").font(.subheadline).foregroundStyle(Color.tatiOlive)
                }
                Spacer(minLength: 0)
                ArtButton(asset: "close-light", label: "Close filters") { dismiss() }
            }.padding(.horizontal, 20).padding(.vertical, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    options("Browse", items: sections, selection: $draft.section)
                    options("Food", items: FoodCatalog.topics, selection: $draft.topic)
                    options("City", items: FoodCatalog.cities, selection: $draft.city)
                    options("Language", items: FoodCatalog.languages, selection: $draft.language)
                }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 20)
            }
            VStack(spacing: 10) {
                Text(matchCount == 0 ? "No rooms match. Try fewer filters." : "\(matchCount) \(matchCount == 1 ? "room matches" : "rooms match") your selection")
                    .font(.caption).foregroundStyle(Color.tatiOlive)
                HStack(spacing: 12) {
                    Button("Reset") { draft.clearFilters() }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.tatiInk)
                        .padding(.horizontal, 18).frame(minHeight: 48)
                        .background(Color.white, in: Capsule()).buttonStyle(.plain)
                    TatiButton(title: matchCount == 0 ? "Apply filters" : "Show \(matchCount) \(matchCount == 1 ? "room" : "rooms")") {
                        selection = draft
                        dismiss()
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
                .background(Color.tatiCream)
        }
        .frame(maxWidth: 600).frame(maxWidth: .infinity)
        .foregroundStyle(Color.tatiInk)
        .background(Color.tatiCream)
        .presentationBackground(Color.tatiCream)
        .presentationCornerRadius(28)
        .presentationDragIndicator(.hidden)
        .presentationDetents([.fraction(0.82), .large])
        .accessibilityAction(.escape) { dismiss() }
    }

    private func options(_ title: String, items: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            FilterTagLayout {
                ForEach(items, id: \.self) { value in
                    BrowseFilterChip(title: value == "All" ? (title == "Food" ? "All food" : title == "City" ? "Anywhere" : "Any language") : value, selected: selection.wrappedValue == value) {
                        selection.wrappedValue = value
                    }
                }
            }
        }
    }
}

/// Intrinsic-width tags wrap as whole labels, matching the Lanhu filter rows.
struct FilterTagLayout: Layout {
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
                x = 0; y += rowHeight + 8; rowHeight = 0
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
    @FocusState private var isSearching: Bool
    @Environment(\.dismiss) private var dismiss

    private var searchTerms: [String] {
        query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
    private func matches(_ value: String, terms: [String]) -> Bool {
        terms.allSatisfy { value.localizedStandardContains($0) }
    }

    var body: some View {
        // Calculate visibility once per update, rather than scanning rooms from every row.
        let terms = searchTerms
        let rooms = store.visibleRooms
        let liveHosts = Set(rooms.filter { !$0.isVoice }.map(\.hostID))
        let people = store.visiblePeople.filter {
            matches([$0.name, $0.interest, $0.city, $0.country, $0.language].joined(separator: " "), terms: terms)
        }
        let matchingRooms = rooms.filter { matches($0.title + " " + $0.topic, terms: terms) }
        let clips = store.visibleClips.filter { matches($0.caption, terms: terms) }
        let count = category == "People" ? people.count : category == "Rooms" ? matchingRooms.count : clips.count

        VStack(spacing: 0) {
            searchHeader
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if terms.isEmpty { popularSearches.padding(.bottom, 12) }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(LocalizedStringKey(category == "People" ? "Creators" : category))
                            .font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
                        Text(count.formatted()).font(.subheadline).monospacedDigit()
                            .foregroundStyle(Color.tatiOlive)
                        Spacer()
                    }.padding(.top, 8).padding(.bottom, 2)
                    if category == "People" {
                        if people.isEmpty {
                            EmptyContent(title: "No people found", detail: "Try a different name or food interest.")
                        }
                        ForEach(people) { person in
                            PersonRow(person: person, hasVideoRoom: liveHosts.contains(person.id))
                        }
                    } else if category == "Rooms" {
                        if matchingRooms.isEmpty {
                            EmptyContent(title: "No rooms found", detail: "Try another food topic.")
                        }
                        ForEach(matchingRooms) { room in RoomListCard(room: room) }
                    } else {
                        if clips.isEmpty {
                            EmptyContent(title: "No videos found", detail: "Try another phrase.")
                        }
                        ForEach(clips) { clip in FeedVideoCard(clip: clip) }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background { Color.tatiCream.ignoresSafeArea(.container) }
        .foregroundStyle(Color.tatiInk).tatiScreen()
        .profileNavigationHost()
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ArtButton(asset: "back", label: "Back") { dismiss() }
                Text("Search").font(.title2.weight(.bold))
                Spacer()
            }
            HStack(spacing: 10) {
                Art(name: "search", width: 24, height: 26)
                TextField("Search for food and users", text: $query)
                    .font(.subheadline).textFieldStyle(.plain)
                    .tint(Color.tatiPink).focused($isSearching)
                    .submitLabel(.search).autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { isSearching = false }
                    .accessibilityLabel("Search for food and users")
                if !query.isEmpty {
                    ArtButton(asset: "close-light", label: "Clear search", size: 20) {
                        query = ""
                        isSearching = true
                    }
                }
            }
            .padding(.leading, 16).padding(.trailing, 6).frame(minHeight: 54)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            HStack(spacing: 6) {
                ForEach(["People", "Rooms", "Videos"], id: \.self) { value in
                    Button { category = value; isSearching = false } label: {
                        Text(LocalizedStringKey(value))
                            .font(.subheadline.weight(category == value ? .bold : .medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 4)
                            .foregroundStyle(category == value ? Color.tatiInk : Color.tatiOlive)
                            .background(category == value ? Color.tatiLime : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == value ? .isSelected : [])
                }
            }
            .padding(4).background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 12)
        .frame(maxWidth: 640).frame(maxWidth: .infinity)
    }

    private var popularSearches: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Popular searches").font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                ForEach(FoodCatalog.popularTopics.indices, id: \.self) { index in
                    let topic = FoodCatalog.popularTopics[index]
                    Button {
                        query = topic.0
                        isSearching = false
                    } label: {
                        Art(name: topic.1, height: 28)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain).accessibilityLabel("Search " + topic.0)
                }
            }
        }
    }
}

struct PersonRow: View {
    var person: FoodPerson
    var hasVideoRoom: Bool
    var body: some View {
        NavigationLink(destination: PersonProfileView(person: person)) {
            HStack(spacing: 14) {
                Avatar(asset: person.portraitArtwork, size: 58)
                VStack(alignment: .leading, spacing: 5) {
                    Text(person.name).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(person.city).font(.caption).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(person.interest).font(.caption.weight(.medium))
                        .foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 12) {
                    if hasVideoRoom { RoomKindBadge(isVoice: false, compact: true) }
                    Art(name: "chevron", width: 8, height: 12)
                }.frame(minWidth: 34)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.tatiInk)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(person.name), \(person.city), \(person.interest)")
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
            let ranked = entries
            ScrollView {
                VStack(spacing: 12) {
                    rankingControls
                    if ranked.isEmpty {
                        EmptyContent(title: "No profiles available", detail: "Profiles and rooms will appear here when available.")
                    } else {
                        podiumStage(ranked, width: width)
                        podiumDetails(ranked)
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
                }.padding(.top, 4).padding(.bottom, 20)
                    .frame(width: width).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
                .background { Color.tatiCream.ignoresSafeArea(.container) }
        }.foregroundStyle(Color.tatiInk).tatiScreen()
    }

    private var rankingControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ArtButton(asset: "back", label: "Back") { dismiss() }
                HStack(spacing: 3) {
                    ForEach(["Activity", "Creators", "Rooms"], id: \.self) { value in
                        Button { category = value } label: {
                            Text(LocalizedStringKey(value))
                                .font(.subheadline.weight(category == value ? .bold : .medium))
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.horizontal, 3)
                                .foregroundStyle(category == value ? Color.tatiInk : Color.tatiOlive)
                                .background(category == value ? Color.tatiLime : .clear, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(category == value ? .isSelected : [])
                    }
                }.padding(4)
                    .background(Color.tatiCream.opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
            }
            HStack(spacing: 4) {
                ForEach(["Daily", "Weekly"], id: \.self) { value in
                    Button { period = value } label: {
                        Text(LocalizedStringKey(value)).font(.subheadline.weight(period == value ? .semibold : .regular))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(period == value ? Color.tatiInk : Color.tatiOlive)
                            .background(period == value ? Color.tatiPink : .clear, in: Capsule())
                            .frame(minHeight: 44)
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(period == value ? .isSelected : [])
                }
            }.padding(.horizontal, 4)
                .frame(maxWidth: 216)
                .background(Color.tatiCream.opacity(0.94), in: Capsule())
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Ranking period")
        }.padding(.horizontal, 16).padding(.top, 4)
    }

    private func podiumStage(_ ranked: [RankingEntry], width: CGFloat) -> some View {
        // Coordinates belong to the original 780 × 1688 artwork, not the
        // screen or three equal columns. Crop and portraits use one transform.
        let scale = width / 780
        let cropTop: CGFloat = 420
        let stageHeight: CGFloat = 400
        return ZStack(alignment: .topLeading) {
            Image("rank-background").resizable()
                .frame(width: width, height: 1688 * scale)
                .offset(y: -cropTop * scale)
                .accessibilityHidden(true)
            ForEach(0..<min(3, ranked.count), id: \.self) { index in
                let entry = ranked[index]
                let anchor = podiumAnchor(index)
                rankingLink(entry) {
                    Avatar(asset: entry.person.portraitArtwork, size: anchor.diameter * scale)
                        .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                        .overlay(alignment: .bottom) {
                            Text("\(index + 1)").font(.caption.weight(.bold))
                                .foregroundStyle(Color.tatiInk)
                                .frame(minWidth: 24, minHeight: 24)
                                .background(Color.tatiLime, in: Circle())
                                .offset(y: 12)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("\(index + 1), \(entry.title), \(entry.metric)")
                .position(x: anchor.x * scale, y: (anchor.y - cropTop) * scale)
            }
        }
        .frame(width: width, height: stageHeight * scale, alignment: .topLeading)
        .clipped()
    }

    private func podiumAnchor(_ index: Int) -> (x: CGFloat, y: CGFloat, diameter: CGFloat) {
        switch index {
        case 0: return (372, 566, 104)
        case 1: return (104, 720, 84)
        default: return (675, 720, 84)
        }
    }

    private func podiumDetails(_ ranked: [RankingEntry]) -> some View {
        // Text takes its natural height below the artwork; large type and long
        // room titles must never move the portraits out of their heart frames.
        HStack(alignment: .top, spacing: 8) {
            ForEach([1, 0, 2], id: \.self) { index in
                if ranked.indices.contains(index) {
                    let entry = ranked[index]
                    rankingLink(entry) {
                        VStack(spacing: 7) {
                            Text("\(index + 1)").font(.caption.weight(.bold))
                                .foregroundStyle(Color.tatiOlive)
                            Text(entry.title).font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(entry.detail).font(.caption)
                                .foregroundStyle(Color.tatiOlive)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(entry.metric).font(.subheadline.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 14).padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                } else {
                    Color.clear.frame(maxWidth: .infinity).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 8)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    private func rankingLink<Label: View>(_ entry: RankingEntry, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink {
            PersonProfileView(person: entry.person)
        } label: { label() }.buttonStyle(.plain)
    }
}
