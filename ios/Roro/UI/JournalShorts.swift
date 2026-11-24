import SwiftUI

private enum ShortPanel: String, Identifiable {
    case comments, options
    var id: String { rawValue }
}

@MainActor
struct JournalShorts: View {
    let id: String?
    let topic: String?
    let root: Bool

    @EnvironmentObject private var app: JournalStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var playback = JournalShortsPlayer()
    @State private var currentID: String?
    @State private var filter: String
    @State private var query = ""
    @State private var searchOpen = false
    @FocusState private var searchFocused: Bool
    @State private var order: [String] = []
    @State private var seen: Set<String> = []
    @State private var paused = false
    @State private var muted = true
    @State private var visible = false
    @State private var panel: ShortPanel?
    @State private var composing = false
    @State private var sharing = false
    @State private var dismissalMessage: String?
    @State private var offset: CGFloat = 0
    @State private var settling = false
    @State private var settleTask: Task<Void, Never>?
    @State private var refreshLabel = ""
    @State private var refreshing = false
    @State private var refreshToken = UUID()
    @State private var retry = 0

    init(id: String?, topic: String?, root: Bool) {
        self.id = id
        self.topic = topic
        self.root = root
        _currentID = State(initialValue: id)
        _filter = State(initialValue: topic ?? "")
    }

    private var normalizedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private func author(_ clip: Record) -> Record {
        app.photographyMember(clip.str("authorID"))
    }

    private func authorName(_ clip: Record) -> String {
        let name = author(clip).str("name")
        return name.isEmpty ? "You" : name
    }

    private var items: [Record] {
        let search = normalizedQuery
        let eligible = app.shorts.filter { clip in
            guard filter.isEmpty || clip.str("topic") == filter else { return false }
            return search.isEmpty || [clip.str("caption"), clip.str("topic"), authorName(clip)]
                .joined(separator: " ").lowercased().contains(search)
        }
        guard !order.isEmpty else { return eligible }
        let byID = Dictionary(eligible.map { ($0.str("id"), $0) }, uniquingKeysWith: { first, _ in first })
        let previous = Set(order)
        return order.compactMap { byID[$0] } + eligible.filter { !previous.contains($0.str("id")) }
    }

    private var clip: Record? {
        let records = items
        return records.first { $0.str("id") == currentID } ?? records.first
    }
    private var clipID: String { clip?.str("id") ?? "" }
    private var loadKey: String { "\(clipID):\(retry):\(visible)" }
    private var shouldPlay: Bool { visible && scenePhase == .active && app.confirmation == nil && !paused && panel == nil && !composing && !sharing && !searchFocused && !settling }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                surface
                if let clip {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        if !searchFocused {
                            HStack(alignment: .bottom, spacing: 16) {
                                caption(clip).frame(maxWidth: .infinity, alignment: .leading)
                                rail(clip, height: geometry.size.height)
                            }
                            .padding(.leading, 18).padding(.trailing, 12)
                            .offset(y: offset)
                            JournalShortTransport(playback: playback, timeline: playback.timeline, muted: $muted,
                                                  estimate: (clip["duration"] as? NSNumber)?.doubleValue ?? 0)
                                .id(clip.str("id"))
                        }
                    }
                    .padding(.bottom, 76)
                } else {
                    emptyState
                }
                VStack(spacing: 4) {
                    header
                    if !refreshLabel.isEmpty {
                        Text(refreshLabel)
                            .font(.custom("Kalam-Regular", size: 14))
                            .padding(.horizontal, 14).padding(.vertical, 4)
                            .background(.black.opacity(0.66), in: Capsule())
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    Spacer()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .simultaneousGesture(pagingGesture(height: geometry.size.height))
        }
        .background {
            GeometryReader { canvas in
                ZStack {
                    Color(red: 0.106, green: 0.094, blue: 0.086)
                    if let clip { film(clip, size: canvas.size) }
                    LinearGradient(stops: [
                        .init(color: .black.opacity(0.54), location: 0),
                        .init(color: .clear, location: 0.25),
                        .init(color: .clear, location: 0.42),
                        .init(color: .black.opacity(0.68), location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
                .frame(width: canvas.size.width, height: canvas.size.height).clipped()
            }.ignoresSafeArea()
        }
        .font(.custom("Kalam-Regular", size: 16))
        .foregroundStyle(Color(red: 1, green: 0.969, blue: 0.922))
        .onAppear {
            if let id, let saved = app.shorts.first(where: { $0.str("id") == id }),
               currentID == id, !filter.isEmpty, saved.str("topic") != filter { filter = "" }
            visible = true
            if !clipID.isEmpty { seen.insert(clipID) }
        }
        .onDisappear {
            visible = false
            searchFocused = false
            cancelTransition()
            refreshToken = UUID()
            refreshing = false
            refreshLabel = ""
            playback.setPlaying(false)
            playback.clear()
        }
        .task(id: loadKey) { await loadClip() }
        .onChange(of: shouldPlay) { playback.setPlaying($0) }
        .onChange(of: app.state.strings("blocked")) { _ in panel = nil }
        .onChange(of: muted) { playback.player.isMuted = $0 }
        .onChange(of: clipID) { value in
            paused = false
            if !value.isEmpty { seen.insert(value) }
        }
        .onChange(of: normalizedQuery) { _ in resetOrder() }
        .onChange(of: filter) { _ in resetOrder() }
        .fullScreenCover(isPresented: $composing, onDismiss: announceDismissal) {
            JournalShortComposer(initialTopic: filter) { saved in
                if let saved {
                    query = ""
                    searchOpen = false
                    if let clip = app.shorts.first(where: { $0.str("id") == saved }), clip.str("topic") != filter { filter = "" }
                    currentID = saved
                    dismissalMessage = "Short saved to your library."
                }
                composing = false
            }
        }
        .sheet(item: $panel, onDismiss: announceDismissal) { kind in
            switch kind {
            case .comments:
                if let clip {
                    JournalShortComments(workID: clip.str("id"), close: { panel = nil }) { author in
                        panel = nil
                        visitProfile(author)
                    }
                    .presentationDetents([.medium, .large])
                }
            case .options:
                if let clip {
                    JournalShortOptions(clip: clip, close: { panel = nil }, notifyOnDismiss: { dismissalMessage = $0 })
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    @ViewBuilder private func film(_ clip: Record, size: CGSize) -> some View {
        ZStack {
            ZStack {
                JournalImage(clip.str("poster")).frame(width: size.width, height: size.height)
                JournalShortsVideo(player: playback.player).opacity(playback.ready ? 1 : 0)
            }
            .frame(width: size.width, height: size.height)
            if offset < 0, let next = adjacent(1) {
                JournalImage(next.str("poster")).frame(width: size.width, height: size.height)
                    .offset(y: size.height)
            }
        }
        .offset(y: offset).accessibilityHidden(true)
    }

    private var surface: some View {
        ZStack {
            Color.clear
            if let failure = playback.failure {
                VStack {
                    Text(failure)
                    Text("Pull down to try again.")
                }
                .multilineTextAlignment(.center).padding()
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            } else if !clipID.isEmpty {
                if paused {
                    JournalImage("assets/icons/shorts.png").frame(width: 52, height: 52)
                } else if !playback.ready {
                    Text("Opening video…").padding(8).background(.black.opacity(0.6), in: Capsule())
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            guard !clipID.isEmpty, !app.state.strings("likes").contains(clipID) else { return }
            _ = app.change("toggleLike", ["id": clipID])
        }.exclusively(before: TapGesture().onEnded { if !clipID.isEmpty { paused.toggle() } }))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(paused ? "Play video" : "Pause video")
        .accessibilityHint("Swipe up for the next video. Pull down to refresh. Double tap the video with VoiceOver off to like.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { paused.toggle() }
        .accessibilityAction(named: Text("Next video")) { if let next = adjacent(1) { currentID = next.str("id") } }
        .accessibilityAction(named: Text("Previous video")) { if let previous = adjacent(-1) { currentID = previous.str("id") } }
        .accessibilityAction(named: Text("Refresh shorts")) { refresh() }
    }

    private func pagingGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { drag in
                guard !settling, !refreshing, panel == nil, !searchFocused, abs(drag.translation.height) > abs(drag.translation.width) else { return }
                let distance = drag.translation.height
                if distance > 0 {
                    offset = 0
                    refreshLabel = distance >= 64 ? "Release to refresh" : "Pull to refresh"
                } else {
                    refreshLabel = ""
                    offset = max(-height, distance) * (items.count > 1 ? 1 : 0.18)
                }
            }
            .onEnded { drag in
                guard !settling, !refreshing, panel == nil, !searchFocused else { return }
                let distance = drag.translation.height
                refreshLabel = ""
                guard abs(distance) > abs(drag.translation.width) else { offset = 0; return }
                if distance >= 64 { offset = 0; refresh() }
                else if distance < -45, items.count > 1 { advance(height: height) }
                else { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.17)) { offset = 0 } }
            }
    }

    private var header: some View {
        VStack(spacing: 3) {
            ZStack {
                Text("Shorts").font(.custom("Courgette-Regular", size: root ? 34 : 28))
                    .shadow(color: .black, radius: 3)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 4) {
                    if root {
                        JournalImage("assets/icons/roro-logo.png").frame(width: 57, height: 45).accessibilityLabel("Roro")
                    } else { JournalIcon("back", "Back") { app.back() } }
                    Spacer()
                    JournalIcon(searchOpen ? "close" : "search", searchOpen ? "Close search" : "Search shorts or people") {
                        if searchOpen { searchFocused = false; query = ""; searchOpen = false }
                        else {
                            searchOpen = true
                            DispatchQueue.main.async { searchFocused = true }
                        }
                    }
                    JournalIcon("plus", "Add a short") { searchFocused = false; composing = true }
                }
            }
            if searchOpen {
                TextField("", text: $query, prompt: Text("Search shorts or people").foregroundColor(.white.opacity(0.79)))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.search).focused($searchFocused)
                    .onSubmit { searchFocused = false }
                    .accessibilityLabel("Search shorts or people")
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16).padding(.top, 5)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            JournalImage("assets/icons/shorts.png").frame(width: 42, height: 42)
            Text(!normalizedQuery.isEmpty ? "No matching shorts" : filter.isEmpty ? "A little life, in motion" : "No shorts in this topic yet")
                .font(.custom("Courgette-Regular", size: 24))
            Text(!filter.isEmpty ? "Explore another topic or add your own clip." : !normalizedQuery.isEmpty ? "Try another name, topic or detail." : "Add a favorite video from your camera roll to start watching.")
            HStack {
                JournalIcon("plus", "Add a video") { searchFocused = false; composing = true }
                if !filter.isEmpty { JournalIcon("shorts", "See all shorts") { filter = "" } }
            }
        }
        .multilineTextAlignment(.center).padding(.horizontal, 30)
    }

    private func caption(_ clip: Record) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Button(authorName(clip)) { visitProfile(clip.str("authorID")) }
                .font(.custom("Kalam-Bold", size: 18))
                .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.6))
                .frame(minHeight: 44, alignment: .bottomLeading)
            Text(clip.str("caption").isEmpty ? "A little moment, kept." : clip.str("caption")).lineLimit(3)
            if !clip.str("topic").isEmpty {
                Button(clip.str("topic")) { currentID = clip.str("id"); app.open(.topic(clip.str("topic"))) }
                    .font(.custom("Kalam-Regular", size: 14)).frame(minHeight: 44, alignment: .leading)
            }
        }
        .buttonStyle(.plain).shadow(color: .black, radius: 3)
    }

    private func rail(_ clip: Record, height: CGFloat) -> some View {
        let workID = clip.str("id")
        let liked = app.state.strings("likes").contains(workID)
        let saved = app.state.strings("saves").contains(workID)
        let avatar = author(clip).str("avatar")
        let commentCount = app.comments(workID).count
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 5) {
                Button { visitProfile(clip.str("authorID")) } label: {
                    JournalImage(avatar.isEmpty ? "assets/icons/profile.png" : avatar, mode: .fill)
                        .frame(width: 42, height: 42).clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(width: 52, height: 46)
                }
                .accessibilityLabel("Open \(authorName(clip))'s profile")
                railButton(liked ? "heart" : "heart-outline", "Like short", clip.int("likes") + (liked ? 1 : 0), liked) {
                    _ = app.change("toggleLike", ["id": workID])
                }
                railButton("comment", "Open \(commentCount) comments", commentCount) { panel = .comments }
                railButton(saved ? "bookmark" : "bookmark-outline", "Save short", clip.int("saves") + (saved ? 1 : 0), saved) {
                    _ = app.change("toggleSave", ["id": workID])
                }
                railButton("share", "Share") { run("sharePhoto", ["image": clip.str("video")]) }
                railButton("more", "More video options") { panel = .options }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 54, height: min(328, max(100, height - 225)))
    }

    private func railButton(_ icon: String, _ label: String, _ count: Int? = nil, _ selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                JournalImage("assets/icons/\(icon).png").frame(width: 32, height: 32)
                    .shadow(color: .white.opacity(0.85), radius: 1)
                if let count { Text(String(count)).font(.custom("Kalam-Bold", size: 12)) }
            }
            .frame(width: 52, height: 48).contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityValue(count.map { String($0) } ?? "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func visitProfile(_ id: String) {
        searchFocused = false
        currentID = clipID
        app.openPhotographyProfile(id)
    }

    private func adjacent(_ step: Int) -> Record? {
        let records = items
        guard records.count > 1 else { return nil }
        let index = records.firstIndex(where: { $0.str("id") == currentID }) ?? 0
        return records[(index + step + records.count) % records.count]
    }

    private func cancelTransition() {
        settleTask?.cancel()
        settleTask = nil
        settling = false
        offset = 0
    }

    private func advance(height: CGFloat) {
        guard !settling, let next = adjacent(1) else { return }
        if reduceMotion { offset = 0; currentID = next.str("id"); return }
        settling = true
        withAnimation(.easeOut(duration: 0.22)) { offset = -height }
        settleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            currentID = next.str("id")
            settling = false
            offset = 0
        }
    }

    private func resetOrder() {
        cancelTransition()
        order = []
        seen = clipID.isEmpty ? [] : [clipID]
    }

    private func refresh() {
        guard !refreshing else { return }
        refreshing = true
        let token = UUID()
        refreshToken = token
        let startID = clipID, startFilter = filter, startQuery = normalizedQuery
        refreshLabel = "Refreshing…"
        Task { @MainActor in
            do {
                _ = try await app.perform("snapshot", ["reload": true])
                guard refreshToken == token else { return }
                if filter == startFilter, normalizedQuery == startQuery, clipID == startID || !items.contains(where: { $0.str("id") == startID }) {
                    let ids = items.map { $0.str("id") }
                    let start = (ids.firstIndex(of: startID) ?? -1) + 1
                    let rotated = Array(ids.dropFirst(start)) + Array(ids.prefix(start))
                    if ids.allSatisfy(seen.contains) { seen.removeAll() }
                    order = rotated.filter { !seen.contains($0) } + rotated.filter { seen.contains($0) }
                    currentID = order.first
                    if let currentID { seen.insert(currentID) }
                    if playback.failure != nil { retry += 1 }
                    paused = false
                }
                refreshLabel = "Updated"
            } catch {
                guard refreshToken == token else { return }
                refreshLabel = error.localizedDescription
            }
            refreshing = false
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if refreshToken == token { refreshLabel = "" }
        }
    }

    private func loadClip() async {
        playback.clear()
        guard visible, let clip else { return }
        let requested = clip.str("id")
        do {
            let result = try await app.perform("videoSource", ["id": requested])
            guard !Task.isCancelled, visible, clipID == requested else { return }
            guard let url = result as? URL, url.isFileURL else {
                playback.fail("This video could not be opened. Try again.")
                return
            }
            playback.load(url, duration: (clip["duration"] as? NSNumber)?.doubleValue ?? 0)
            playback.player.isMuted = muted
            playback.setPlaying(shouldPlay)
        } catch {
            if !Task.isCancelled, visible, clipID == requested { playback.fail(error.localizedDescription) }
        }
    }

    private func announceDismissal() {
        if let dismissalMessage {
            if dismissalMessage == "Report saved for this account." { app.confirmation = dismissalMessage }
            else { app.message = dismissalMessage }
            self.dismissalMessage = nil
        }
    }

    private func run(_ command: String, _ payload: Record) {
        guard !sharing else { return }
        sharing = true
        Task {
            defer { sharing = false }
            do { _ = try await app.perform(command, payload) } catch { app.showError(error) }
        }
    }
}
