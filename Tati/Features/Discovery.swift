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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Art(name: voice ? "chat-heading" : "brand-heading", width: voice ? 120 : 168, height: 48)
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
                    ImageAction(asset: "topic-banner", label: "Browse food topics", height: 64) { showTopic = true }
                }
                if ContentLibrary.unavailable { Note(text: "The bundled content library could not be loaded.") }
                if rooms.isEmpty { EmptyContent(title: "No rooms here yet", detail: selected == "Follow" ? "Rooms from profiles you follow appear here." : "Try another topic or clear your filters.") }
                else if voice {
                    LazyVStack(spacing: 8) { ForEach(rooms) { room in NavigationLink(destination: RoomView(room: room)) { RoomListCard(room: room) }.buttonStyle(.plain) } }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(rooms) { room in NavigationLink(destination: RoomView(room: room)) { LiveRoomCard(room: room) }.buttonStyle(.plain) }
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .onChange(of: voice) { _, _ in selected = voice ? "Party" : "Hot" }
        .sheet(isPresented: $showTopic) { NavigationStack { HotTopicView() }.overlay { NoticeLayer() }.presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showFilter) {
            NavigationStack { FilterView(topic: $topic, country: $country, language: $language) }
                .presentationDetents([.height(390), .large]).presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showPublish) {
            NavigationStack { PublishChooser() }.overlay { NoticeLayer() }.presentationDetents([.height(210)]).presentationDragIndicator(.hidden)
        }
    }
}
struct LiveRoomCard: View {
    var room: FoodRoom
    private var host: FoodPerson? { FoodCatalog.person(room.hostID) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    ContentPhoto(asset: room.coverArtwork, height: geometry.size.height)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview").font(.system(size: 9, weight: .semibold)).padding(.horizontal, 6).padding(.vertical, 3).background(Color.tatiPink).clipShape(RoundedRectangle(cornerRadius: 4))
                        Spacer()
                        HStack(spacing: 5) {
                            Avatar(asset: host?.portraitArtwork, size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(host?.name ?? "Creator").font(.system(size: 11, weight: .semibold))
                                Text(host?.city ?? "").font(.system(size: 9))
                            }
                        }
                        Text(room.topic).font(.system(size: 9, weight: .medium)).padding(.horizontal, 5).padding(.vertical, 3)
                            .background(Color.tatiOlive).clipShape(RoundedRectangle(cornerRadius: 3))
                    }.padding(8).foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                }.clipped()
            }.aspectRatio(0.86, contentMode: .fit)
            VStack(alignment: .leading, spacing: 3) {
                Text(room.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Text("Food tastes better together").font(.system(size: 9)).foregroundStyle(Color.tatiOlive).lineLimit(1)
            }.padding(.horizontal, 9).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
        }.background(.white.opacity(0.92)).clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.tatiOlive.opacity(0.65), lineWidth: 0.6) }.foregroundStyle(Color.tatiInk)
    }
}
struct RoomListCard: View {
    var room: FoodRoom
    private var host: FoodPerson? { FoodCatalog.person(room.hostID) }
    var body: some View {
        HStack(spacing: 12) {
            ContentPhoto(asset: room.coverArtwork, height: 88).frame(width: 88).clipShape(RoundedRectangle(cornerRadius: 12)).offset(y: -8)
            VStack(alignment: .leading, spacing: 5) {
                Text(room.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Text("Talk about your favorite food").font(.system(size: 11)).foregroundStyle(Color.tatiOlive).lineLimit(1)
                HStack(spacing: 5) {
                    Avatar(asset: host?.portraitArtwork, size: 22)
                    Text(room.topic).font(.system(size: 10)).padding(.horizontal, 5).padding(.vertical, 3).foregroundStyle(.white).background(Color.tatiOlive).clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            Spacer(minLength: 0)
            Text("Preview").font(.system(size: 9)).foregroundStyle(Color.tatiOlive)
        }.padding(.horizontal, 10).padding(.vertical, 4)
            .background { Image("outlined-card").resizable() }.padding(.top, 8).foregroundStyle(Color.tatiInk)
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
            Text("Label").font(.system(size: 12))
            ChoiceGrid(items: FoodCatalog.cities, selected: $draftCity)
            Text("Language").font(.system(size: 12))
            ChoiceGrid(items: FoodCatalog.languages, selected: $draftLanguage)
            HStack {
                TatiButton(title: "Reset", secondary: true) { draftTopic = "All"; draftCity = "All"; draftLanguage = "All" }.frame(width: 58)
                TatiButton(title: "Apply") { topic = draftTopic; country = draftCity; language = draftLanguage; dismiss() }
            }
        }.onAppear { draftTopic = topic; draftCity = country; draftLanguage = language }
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
            Text("Popular searches").font(.system(size: 21, weight: .bold, design: .serif))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(FoodCatalog.popularTopics.indices, id: \.self) { index in
                    let topic = FoodCatalog.popularTopics[index]
                    Button { query = topic.0; category = "People" } label: { Art(name: topic.1, height: 23).frame(minHeight: 32) }
                        .buttonStyle(.plain).accessibilityLabel("Search " + topic.0)
                }
            }
            Text(category == "People" ? "Creators" : category).font(.system(size: 19, weight: .bold, design: .serif))
            TopicStrip(items: ["People", "Rooms", "Videos"], selected: $category)
            if category == "People" {
                let matches = FoodCatalog.people.filter { !store.account.blocked.contains($0.id) && (query.isEmpty || ($0.name + $0.interest).localizedCaseInsensitiveContains(query)) }
                if matches.isEmpty { EmptyContent(title: "No people found", detail: "Try a different name or food interest.") }
                LazyVStack(spacing: 0) { ForEach(matches) { PersonRow(person: $0) } }
            } else if category == "Rooms" {
                let matches = FoodCatalog.rooms.filter { !store.account.blocked.contains($0.hostID) && (query.isEmpty || ($0.title + $0.topic).localizedCaseInsensitiveContains(query)) }
                if matches.isEmpty { EmptyContent(title: "No rooms found", detail: "Try another food topic.") }
                ForEach(matches) { room in NavigationLink(destination: RoomView(room: room)) { RoomListCard(room: room) }.buttonStyle(.plain) }
            } else {
                let matches = store.visibleClips.filter { query.isEmpty || $0.caption.localizedCaseInsensitiveContains(query) }
                if matches.isEmpty { EmptyContent(title: "No videos found", detail: "Try another phrase.") }
                ForEach(matches) { clip in NavigationLink(destination: ClipDetailView(clip: clip)) { VideoCard(clip: clip) }.buttonStyle(.plain) }
            }
            }.padding(.horizontal, 18).padding(.bottom, 16).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
        }.background(Color.tatiCream).foregroundStyle(Color.tatiInk).toolbar(.hidden, for: .navigationBar)
    }
}
struct PersonRow: View {
    var person: FoodPerson
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: PersonProfileView(person: person)) {
                HStack(spacing: 10) {
                    Avatar(asset: person.portraitArtwork)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name).font(.system(size: 15, weight: .bold))
                        Text("\(person.country) · \(person.interest)").font(.system(size: 11)).foregroundStyle(Color.tatiOlive).lineLimit(1)
                    }
                }
            }.buttonStyle(.plain)
            Spacer(minLength: 0)
            NavigationLink(destination: PersonProfileView(person: person)) { Art(name: "chevron", width: 12).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("View \(person.name)")
        }.foregroundStyle(Color.tatiInk).padding(.vertical, 9)
            .overlay(alignment: .bottom) { Color.tatiOlive.opacity(0.15).frame(height: 0.5) }
    }
}
struct RankingView: View {
    @State private var category = "Activity"
    @State private var period = "Daily"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ArtButton(asset: "back", label: "Back") { dismiss() }
                    TopicStrip(items: ["Activity", "Creators", "Rooms"], selected: $category)
                }.padding(.horizontal, 8)
                HStack(spacing: 0) {
                    ForEach(["Daily", "Weekly"], id: \.self) { value in
                        Button { period = value } label: {
                            Text(value).font(.system(size: 15)).frame(maxWidth: .infinity, minHeight: 40)
                                .foregroundStyle(period == value ? .white : Color.tatiOlive.opacity(0.5))
                                .background(period == value ? Color.tatiOlive : .clear).clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).accessibilityAddTraits(period == value ? .isSelected : [])
                    }
                }.padding(5).background(Color.tatiCream.opacity(0.9)).clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 42)
                ScrollView {
                    VStack(spacing: 8) {
                        Text("No ranking data yet").font(.system(size: 16, weight: .medium))
                        Text("\(period) \(category.lowercased()) rankings need a connected community.").font(.system(size: 12)).multilineTextAlignment(.center)
                    }.padding(24).frame(maxWidth: .infinity).padding(.top, geometry.size.height * 0.40)
                }
            }
            .background { Image("rank-background").resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped().ignoresSafeArea() }
        }.foregroundStyle(Color.tatiInk).toolbar(.hidden, for: .navigationBar)
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
