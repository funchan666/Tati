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
        FoodCatalog.rooms.filter { room in
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
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Art(name: voice ? "chat-heading" : "brand-heading", width: voice ? 140 : 160, height: 50)
                    Spacer()
                    NavigationLink(destination: SearchView()) { Art(name: "search", width: 31, height: 31).frame(width: 44, height: 44) }.accessibilityLabel("Search")
                    NavigationLink(destination: RankingView()) { Art(name: "rank-entry", width: 47, height: 40).frame(minHeight: 44) }.accessibilityLabel("Rankings")
                }
                HStack {
                    ForEach(sections, id: \.self) { value in
                        Button { selected = value } label: {
                            Text(value).font(.system(size: 16, weight: currentSection == value ? .bold : .medium))
                                .foregroundStyle(currentSection == value ? Color.tatiInk : Color.tatiOlive.opacity(0.6))
                                .padding(.vertical, 8)
                                .background(alignment: .bottom) { if currentSection == value { Color.tatiLime.frame(height: 3) } }
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                    ArtButton(asset: "filter", label: "Filter rooms", size: 30) { showFilter = true }
                }
                if voice {
                    HStack {
                        ImageAction(asset: "topic-banner", label: "Browse food topics", height: 64) { showTopic = true }
                        ArtButton(asset: "publish", label: "Create a room", size: 34) { showPublish = true }
                    }
                }
                HStack {
                    Note(text: "Sample rooms · media and live service to come")
                    Spacer()
                    if !voice { ArtButton(asset: "publish", label: "Publish", size: 30) { showPublish = true } }
                }
                if rooms.isEmpty { EmptyContent(title: "No rooms here yet", detail: selected == "Follow" ? "Rooms from profiles you follow appear here." : "Try another topic or clear your filters.") }
                else if voice {
                    LazyVStack(spacing: 12) { ForEach(rooms) { room in NavigationLink(destination: RoomView(room: room)) { RoomListCard(room: room) }.buttonStyle(.plain) } }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(rooms) { room in NavigationLink(destination: RoomView(room: room)) { LiveRoomCard(room: room) }.buttonStyle(.plain) }
                    }
                }
            }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 22)
        }
        .onChange(of: voice) { _, _ in selected = voice ? "Party" : "Hot" }
        .sheet(isPresented: $showTopic) { NavigationStack { HotTopicView() }.overlay { NoticeLayer() }.presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showFilter) {
            NavigationStack { FilterView(topic: $topic, country: $country, language: $language) }
                .presentationDetents([.large]).presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showPublish) {
            NavigationStack { PublishChooser() }.overlay { NoticeLayer() }.presentationDragIndicator(.hidden)
        }
    }
}
struct LiveRoomCard: View {
    var room: FoodRoom
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                MediaPlaceholder(title: "Cover to come", height: 185)
                VStack(alignment: .leading, spacing: 5) {
                    Text("SAMPLE").font(.system(size: 9, weight: .heavy)).padding(5).background(Color.tatiPink).foregroundStyle(.white).clipShape(Capsule())
                    Spacer()
                    Text(FoodCatalog.person(room.hostID)?.name ?? "Creator").font(.system(size: 14, weight: .bold))
                    Text(room.topic).font(.system(size: 10, weight: .semibold)).padding(.horizontal, 7).padding(.vertical, 4).background(Color.tatiLime).clipShape(Capsule())
                }.padding(10)
            }.frame(height: 185)
            VStack(alignment: .leading, spacing: 5) {
                Text(room.title).font(.system(size: 12, weight: .bold)).lineLimit(2)
                Text("Food tastes better together").font(.system(size: 10)).foregroundStyle(Color.tatiOlive).lineLimit(2)
            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
        }.background(.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 18)).foregroundStyle(Color.tatiInk)
    }
}
struct RoomListCard: View {
    var room: FoodRoom
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        HStack(spacing: 12) {
            Image(room.background).resizable().scaledToFill().frame(width: 76, height: 84).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 7) {
                Text(room.title).font(.system(size: 16, weight: .bold)).lineLimit(2)
                Text("\(FoodCatalog.person(room.hostID)?.name ?? "Host") · \(room.topic)").font(.system(size: 12)).foregroundStyle(Color.tatiOlive)
                Text("Sample room · 0 connected").font(.system(size: 10, weight: .medium))
            }
            Spacer(minLength: 0)
            Art(name: "chevron", width: 14)
        }.padding(12).background(Color.white.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 18)).foregroundStyle(Color.tatiInk)
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
    var body: some View {
        TatiPanel(title: "Find your people") {
            Text("City").font(.headline)
            ChoiceGrid(items: FoodCatalog.cities, selected: $draftCity)
            Text("Language").font(.headline)
            ChoiceGrid(items: FoodCatalog.languages, selected: $draftLanguage)
            Text("Food").font(.headline)
            ChoiceGrid(items: FoodCatalog.topics, selected: $draftTopic)
            HStack {
                TatiButton(title: "Reset", secondary: true) { draftTopic = "All"; draftCity = "All"; draftLanguage = "All" }
                TatiButton(title: "Apply") { topic = draftTopic; country = draftCity; language = draftLanguage; dismiss() }
            }
        }.onAppear { draftTopic = topic; draftCity = country; draftLanguage = language }
    }
}
struct ChoiceGrid: View {
    var items: [String]
    @Binding var selected: String
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
            ForEach(items, id: \.self) { value in Chip(text: value, selected: selected == value) { selected = value } }
        }
    }
}
struct SearchView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var query = ""
    @State private var category = "People"
    var body: some View {
        TatiPage(title: "Search") {
            InputField(title: "People, rooms or food", text: $query)
            Text("Popular searches").font(.system(size: 21, weight: .bold, design: .serif))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(FoodCatalog.popularTopics.indices, id: \.self) { index in
                    let topic = FoodCatalog.popularTopics[index]
                    Button { query = topic.0; category = "People" } label: { Art(name: topic.1, height: 30).frame(minHeight: 44) }
                        .buttonStyle(.plain).accessibilityLabel("Search " + topic.0)
                }
            }
            TopicStrip(items: ["People", "Rooms", "Videos"], selected: $category)
            if category == "People" {
                let matches = FoodCatalog.people.filter { !store.account.blocked.contains($0.id) && (query.isEmpty || ($0.name + $0.interest).localizedCaseInsensitiveContains(query)) }
                if matches.isEmpty { EmptyContent(title: "No people found", detail: "Try a different name or food interest.") }
                ForEach(matches) { PersonRow(person: $0) }
            } else if category == "Rooms" {
                let matches = FoodCatalog.rooms.filter { !store.account.blocked.contains($0.hostID) && (query.isEmpty || ($0.title + $0.topic).localizedCaseInsensitiveContains(query)) }
                if matches.isEmpty { EmptyContent(title: "No rooms found", detail: "Try another food topic.") }
                ForEach(matches) { room in NavigationLink(destination: RoomView(room: room)) { RoomListCard(room: room) }.buttonStyle(.plain) }
            } else {
                let matches = store.visibleClips.filter { query.isEmpty || $0.caption.localizedCaseInsensitiveContains(query) }
                if matches.isEmpty { EmptyContent(title: "No videos found", detail: "Try another phrase.") }
                ForEach(matches) { clip in NavigationLink(destination: ClipDetailView(clip: clip)) { VideoCard(clip: clip) }.buttonStyle(.plain) }
            }
        }
    }
}
struct PersonRow: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: PersonProfileView(person: person)) {
                HStack(spacing: 10) {
                    Avatar()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name).font(.system(size: 15, weight: .bold))
                        Text("\(person.country) · Sample profile").font(.system(size: 11)).foregroundStyle(Color.tatiOlive)
                    }
                }
            }.buttonStyle(.plain)
            Spacer(minLength: 0)
            Button { store.toggleFollow(person.id) } label: {
                Text(store.account.following.contains(person.id) ? "Following" : "Follow").font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12).padding(.vertical, 10).background(Color.tatiLime).clipShape(Capsule())
            }.buttonStyle(.plain)
        }.foregroundStyle(Color.tatiInk).padding(10).background(.white.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
struct RankingView: View {
    @State private var category = "Activity"
    @State private var period = "Daily"
    var body: some View {
        TatiPage(title: "Rankings", background: "rank-background") {
            TopicStrip(items: ["Activity", "Creators", "Rooms"], selected: $category)
            TopicStrip(items: ["Daily", "Weekly"], selected: $period)
            Art(name: "rank-entry", height: 100).frame(maxWidth: .infinity).padding(.top, 45)
            EmptyContent(title: "No ranking data yet", detail: "\(period) \(category.lowercased()) rankings will appear when the community service is connected.", artwork: "trophy")
        }
    }
}

struct HotTopicView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPanel(title: "Hot topic") {
            Art(name: "topic-banner")
            Text("Late-night snack: sweet or savoury?").font(.title3.bold())
            Note(text: "Explore sample food rooms. These are previews, not connected broadcasts.")
            ForEach(FoodCatalog.rooms.filter { $0.isVoice && $0.foodFocused && !store.account.blocked.contains($0.hostID) }) { room in
                NavigationLink(destination: RoomView(room: room)) { RoomListCard(room: room) }.buttonStyle(.plain)
            }
        }
    }
}
