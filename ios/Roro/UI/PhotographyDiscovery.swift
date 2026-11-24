import SwiftUI

struct PhotographySessionState {
    struct Home {
        var searchOpen = false
        var query = ""
        var scope = "Discover"
        var turn = 0
    }

    struct Topics {
        var searchOpen = false
        var query = ""
        var category = ""
        var access = "All"
        var turn = 0
    }

    var home = Home()
    var topics = Topics()
}

struct PhotographyHome: View {
    @EnvironmentObject private var app: JournalStore
    private var home: PhotographySessionState.Home { app.discovery.home }

    private func matches(_ work: Record) -> Bool {
        let text = [work.str("caption"), work.str("topic"), app.photographyMember(work.str("authorID")).str("name")].joined(separator: " ")
        let term = home.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty || text.localizedCaseInsensitiveContains(term)
    }

    var body: some View {
        let following = app.state.strings("following")
        let photos = app.photos.filter {
            $0.str("surface") != "topics" && matches($0) && (home.scope == "Discover" || following.contains($0.str("authorID")) ||
                (following.contains("roro") && $0["editorial"] as? Bool == true))
        }
        let videos = home.scope == "Following" ? app.shorts.filter { following.contains($0.str("authorID")) && matches($0) } : []
        let topic = PhotographyCatalog.topics[home.turn % PhotographyCatalog.topics.count]
        VStack(spacing: 0) {
            JournalHeader(home.searchOpen ? "" : "Home", root: true) {
                PhotographySearch(visible: $app.discovery.home.searchOpen, query: $app.discovery.home.query, label: "Search photos or people")
                JournalIcon("plus", "Add a moment") { app.open(.compose(nil, nil)) }
            }
            ScrollView {
                VStack(spacing: 8) {
                    HStack(spacing: 24) {
                        ForEach(["Discover", "Following"], id: \.self) { item in
                            Button { app.discovery.home.scope = item } label: {
                                Text(item).font(.custom("Kalam-Regular", size: 20, relativeTo: .headline))
                                    .frame(minHeight: 44).overlay(alignment: .bottom) {
                                        if home.scope == item { Capsule().fill(JournalColor.accent).frame(height: 3).rotationEffect(.degrees(-2)) }
                                    }
                            }.accessibilityAddTraits(home.scope == item ? .isSelected : [])
                        }
                    }
                    Button { app.open(.topic(topic)) } label: {
                        GeometryReader { geometry in
                            ZStack(alignment: .trailing) {
                                JournalImage("assets/backgrounds/journal-banner.png").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                                HStack {
                                    Text(PhotographyCatalog.prompts[topic] ?? topic)
                                        .font(.custom("Courgette-Regular", size: 20, relativeTo: .headline))
                                        .foregroundStyle(JournalColor.petrol).multilineTextAlignment(.leading)
                                        .frame(width: geometry.size.width * 0.43, alignment: .leading)
                                        .shadow(color: JournalColor.paper, radius: 1)
                                    Spacer()
                                }.padding(.horizontal, 12)
                            }
                        }.frame(height: 96).contentShape(Rectangle())
                    }.accessibilityLabel("\(topic). \(PhotographyCatalog.prompts[topic] ?? "")")
                    PhotographyFeed(photos: home.scope == "Discover" ? PhotographyCatalog.rotate(photos, by: home.turn) : photos, shorts: videos)
                    if photos.isEmpty && videos.isEmpty && !home.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        PhotographyTitle(title: "No matching moments")
                        Text("Try another name, topic or detail.")
                    } else if home.scope == "Following" && following.isEmpty {
                        PhotographyTitle(title: "Make this space yours")
                        Text("Follow Roro inspiration to keep its photo collection close.").multilineTextAlignment(.center)
                        JournalIcon("topics", "Explore the collection") { app.open(.collection) }
                    }
                }.padding(.bottom, 12)
            }.refreshable { if await app.photographyRefresh() { app.discovery.home.turn += 1 } }
        }.buttonStyle(.plain)
    }
}

struct PhotographyTopics: View {
    @EnvironmentObject private var app: JournalStore
    @State private var showFilters = false
    private var selection: PhotographySessionState.Topics { app.discovery.topics }

    private func matches(_ topic: String, photos: [Record], shorts: [Record]) -> Bool {
        guard (selection.category.isEmpty || selection.category == topic), selection.access == "All" || !photos.isEmpty || !shorts.isEmpty else { return false }
        let term = selection.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty { return true }
        let words = [topic, PhotographyCatalog.descriptions[topic] ?? ""] + photos.map { $0.str("caption") + " " + $0.str("author") } + shorts.map { $0.str("caption") }
        return words.contains { $0.localizedCaseInsensitiveContains(term) }
    }

    var body: some View {
        let photos = app.photos.filter { PhotographyTopic.includes($0, access: selection.access) }
        let shorts = selection.access == "Paid" ? [] : app.shorts
        let topics = PhotographyCatalog.rotate(PhotographyCatalog.topics, by: selection.turn).filter { topic in
            matches(topic, photos: photos.filter { $0.str("topic") == topic }, shorts: shorts.filter { $0.str("topic") == topic })
        }
        VStack(spacing: 0) {
            JournalHeader(selection.searchOpen ? "" : "Topics", root: true) {
                JournalIcon("topics", "Filter topics", selected: !selection.category.isEmpty || selection.access != "All") { showFilters = true }
                PhotographySearch(visible: $app.discovery.topics.searchOpen, query: $app.discovery.topics.query, label: "Search topics")
                JournalIcon("plus", "Create topic work") { app.open(.compose(nil, selection.category)) }
            }
            ScrollView {
                HStack(spacing: 8) {
                    Text("What catches\nyour eye?")
                        .font(.custom("Courgette-Regular", size: 20, relativeTo: .headline))
                        .foregroundStyle(JournalColor.petrol)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                    JournalImage("assets/backgrounds/topics-banner.png")
                        .aspectRatio(2.5, contentMode: .fit)
                        .frame(maxHeight: 96)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 96)
                if topics.isEmpty { Text("No matching topics.").padding() }
                LazyVGrid(columns: PhotographyCatalog.columns, spacing: 14) {
                    ForEach(topics, id: \.self) { topic in
                        Button { app.open(.topic(topic, access: selection.access)) } label: {
                            PhotographyTopicTile(topic: topic, photos: photos.filter { $0.str("topic") == topic },
                                                 shorts: shorts.filter { $0.str("topic") == topic })
                        }
                    }
                }.padding(10)
            }.refreshable { if await app.photographyRefresh() { app.discovery.topics.turn += 1 } }
        }.buttonStyle(.plain)
            .sheet(isPresented: $showFilters) {
                PhotographyFilter(category: selection.category, access: selection.access) { selectedCategory, selectedAccess in
                    var updated = app.discovery.topics
                    updated.category = selectedCategory
                    updated.access = selectedAccess
                    app.discovery.topics = updated
                }
            }
    }
}

private struct PhotographyTopicTile: View {
    @EnvironmentObject private var app: JournalStore
    let topic: String
    let photos: [Record]
    let shorts: [Record]

    private var prices: String {
        var values = photos.map { $0.int("coinPrice") > 0 ? "\($0.int("coinPrice")) Coins" : "Free" }
        if !shorts.isEmpty { values.append("Free") }
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }.joined(separator: " · ")
    }

    var body: some View {
        let works = photos + shorts
        let authors = Set(works.map { $0.str("authorID").isEmpty ? "you" : $0.str("authorID") })
        let cover = (app.catalog["categoryCovers"] as? Record)?.str(topic) ?? ""
        VStack(alignment: .leading, spacing: 0) {
            if photos.isEmpty {
                PhotographyArt(icon: "topics", size: 54).frame(maxWidth: .infinity)
                    .aspectRatio(4 / 3, contentMode: .fit)
            } else { PhotographyCrop(path: cover, ratio: 4 / 3) }
            VStack(alignment: .leading, spacing: 3) {
                PhotographyTitle(title: topic, size: 18)
                Text("\(authors.count) \(authors.count == 1 ? "photographer" : "photographers")").foregroundStyle(JournalColor.petrol)
                if !prices.isEmpty { Text(prices) }
                Text("\(photos.count) \(photos.count == 1 ? "photo" : "photos") · \(shorts.count) \(shorts.count == 1 ? "short" : "shorts")")
                PhotographyTotals(works: works, includeWorks: false)
            }.font(.custom("Kalam-Regular", size: 14, relativeTo: .footnote)).padding(6)
        }.padding(4).background(PhotographyCatalog.cream, in: RoundedRectangle(cornerRadius: 5))
            .shadow(color: .brown.opacity(0.18), radius: 2, y: 2)
            .multilineTextAlignment(.leading)
    }
}

private struct PhotographyFilter: View {
    @Environment(\.dismiss) private var dismiss
    @State var category: String
    @State var access: String
    let apply: (String, String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack { PhotographyTitle(title: "Filter topics"); Spacer(); JournalIcon("close", "Cancel filters") { dismiss() } }
                choices("Topic category", [""] + PhotographyCatalog.topics, $category)
                choices("Access", ["All", "Free", "Paid"], $access)
                HStack { Spacer(); JournalIcon("check", "Apply filters") { apply(category, access); dismiss() } }
            }.padding(20)
        }.background { JournalPaper() }
            .presentationDetents([.medium, .large])
    }

    private func choices(_ title: String, _ values: [String], _ selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 8) {
                ForEach(values, id: \.self) { item in
                    Button { selection.wrappedValue = item } label: {
                        Text(item.isEmpty ? "All topics" : item).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selection.wrappedValue == item ? Color.white : JournalColor.ink)
                            .background(selection.wrappedValue == item ? JournalColor.petrol : PhotographyCatalog.cream, in: Capsule())
                    }.accessibilityAddTraits(selection.wrappedValue == item ? .isSelected : [])
                }
            }
        }.buttonStyle(.plain)
    }
}

private struct PhotographyTotals: View {
    @EnvironmentObject private var app: JournalStore
    let works: [Record]
    var includeWorks = true

    var body: some View {
        let likes = works.reduce(0) { $0 + app.photoCount("likes", $1) }
        let saves = works.reduce(0) { $0 + app.photoCount("saves", $1) }
        let comments = works.reduce(0) { $0 + app.comments($1.str("id")).count }
        Text("\(includeWorks ? "\(works.count) works · " : "")\(likes) likes · \(saves) saves · \(comments) comments")
    }
}

struct PhotographyTopic: View {
    @EnvironmentObject private var app: JournalStore
    let topic: String
    var access = "All"

    static func includes(_ photo: Record, access: String) -> Bool {
        photo.str("surface") == "topics" && (access == "All" || (photo.int("coinPrice") > 0) == (access == "Paid"))
    }

    var body: some View {
        let photos = app.photos.filter { Self.includes($0, access: access) && $0.str("topic") == topic }
        let clips = access == "Paid" ? [] : app.shorts.filter { $0.str("topic") == topic }
        VStack(spacing: 0) {
            JournalHeader(topic) {}
            ScrollView {
                VStack(spacing: 9) {
                    Text("Little things worth keeping.")
                    PhotographyTitle(title: topic)
                    PhotographyTotals(works: photos + clips).multilineTextAlignment(.center)
                    if let offer = photos.first(where: { $0["editorial"] as? Bool == true && $0.int("coinPrice") > 0 }) {
                        if app.wallet.strings("unlockedCategories").contains(topic) { Text("Category unlocked") }
                        else { PhotographyUnlock(work: offer, category: true, redirectIfNeeded: true) }
                        Text("Includes current and future paid works in this category.").font(.footnote)
                    }
                    HStack(spacing: 20) {
                        JournalIcon("camera", "Add a photo") { app.open(.compose(nil, topic)) }
                        if !clips.isEmpty { JournalIcon("shorts", "Explore shorts · \(clips.count)") { app.open(.shorts(nil, topic)) } }
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(PhotographyCatalog.cream.opacity(0.65))
                    .overlay(alignment: .top) { Rectangle().fill(JournalColor.petrol).frame(height: 3) }
                PhotographyFeed(photos: photos, shorts: clips)
                if photos.isEmpty && clips.isEmpty {
                    PhotographyTitle(title: "Your moment belongs here")
                    Text("Save a photo with this topic to start your collection.")
                }
            }.refreshable { _ = await app.photographyRefresh() }
        }
    }
}

struct PhotographyCollection: View {
    @EnvironmentObject private var app: JournalStore

    var body: some View {
        VStack(spacing: 0) {
            JournalHeader("Roro inspiration") {}
            ScrollView {
                VStack(spacing: 10) {
                    PhotographyCrop(path: (app.catalog["editorialCovers"] as? Record)?.str("collection") ?? "", ratio: 1.9)
                    PhotographyTitle(title: "Small things. A fresh perspective.")
                    Text("A curated collection of everyday inspiration.")
                    let following = app.state.strings("following").contains("roro")
                    JournalIcon(following ? "check" : "plus", following ? "Following" : "Follow collection", selected: following) {
                        _ = app.change("toggleFollow", ["id": "roro"])
                    }
                    PhotographyMomentsGrid(works: app.photos.filter { $0.str("surface") != "topics" && $0["editorial"] as? Bool == true })
                }.padding(12)
            }.refreshable { _ = await app.photographyRefresh() }
        }
    }
}
