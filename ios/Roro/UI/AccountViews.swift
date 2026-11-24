import SwiftUI

extension Dictionary where Key == String, Value == Any {
    var accountID: String { str("id") }
}

extension JournalStore {
    func accountPerform(_ command: String, _ payload: Record = [:]) async {
        do { _ = try await perform(command, payload) }
        catch { showError(error) }
    }

    func accountRefresh() async { await accountPerform("snapshot", ["reload": true]) }

    var hiddenAccountWorks: [Record] {
        let works = state.rows("moments") + state.rows("shorts") + catalog.rows("photos") + catalog.rows("shorts")
        let hidden = Set(state.strings("hidden"))
        let blocked = Set(state.strings("blocked"))
        return works.filter { hidden.contains($0.accountID) && !blocked.contains($0.str("authorID")) }
    }
}

struct AccountGlyph: View {
    let name: String
    var size: CGFloat = 30
    var body: some View {
        JournalImage("assets/icons/" + name + ".png").frame(width: size, height: size)
    }
}

struct AccountPortrait: View {
    let name: String
    let path: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(JournalColor.accent.opacity(0.13))
            if path.isEmpty {
                Text(String(name.prefix(1)).isEmpty ? "R" : String(name.prefix(1)))
                    .font(.custom("Courgette-Regular", size: size * 0.45)).foregroundColor(JournalColor.accent)
            } else {
                JournalImage(path, mode: .fill).frame(width: size, height: size).clipped()
            }
        }.frame(width: size, height: size).clipShape(Circle())
    }
}

struct AccountHeading: View {
    let text: String
    var body: some View {
        Text(text).font(.custom("Courgette-Regular", size: 22, relativeTo: .title2))
            .foregroundColor(JournalColor.petrol).accessibilityAddTraits(.isHeader)
    }
}

struct AccountEmpty: View {
    let title: String
    var detail: String = ""
    var body: some View {
        VStack(spacing: 6) {
            AccountHeading(text: title)
            if !detail.isEmpty { Text(detail).foregroundColor(.secondary) }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
    }
}

struct AccountDate: View {
    let iso: String
    var history = false
    var body: some View {
        Group {
            if let date = ISO8601DateFormatter().date(from: iso) {
                if Calendar.current.isDateInToday(date) && !history {
                    Text(date.formatted(date: .omitted, time: .shortened))
                } else {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                }
            } else { Text(iso) }
        }.font(.caption).foregroundColor(.secondary)
    }
}

struct AccountCategories: View {
    let items: [String]
    @Binding var selected: String
    @Environment(\.dynamicTypeSize) private var dynamicSize
    var body: some View {
        if dynamicSize.isAccessibilitySize { ScrollView(.horizontal) { categories }.scrollIndicators(.hidden) }
        else { categories }
    }
    private var categories: some View {
        HStack(spacing: 5) {
            ForEach(items, id: \.self) { item in
                Button {
                    selected = item
                } label: {
                    VStack(spacing: 2) {
                        Text(item).font(.custom("Kalam-Bold", size: 16, relativeTo: .body))
                            .fixedSize(horizontal: true, vertical: false)
                        Capsule().fill(selected == item ? JournalColor.accent : .clear).frame(height: 3)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(selected == item ? .isSelected : [])
            }
        }.padding(.horizontal, 5)
    }
}

struct AccountPage: View {
    let route: JournalRoute
    var body: some View {
        switch route {
        case .chats: AccountChats()
        case .me: AccountMe()
        case .friends: AccountFriends()
        case .chat(let id): AccountConversation(peerID: id).id(id)
        case .settings: AccountSettings()
        case .editProfile: AccountEditProfile()
        case .wallet: AccountWallet()
        case .credits: AccountCredits()
        case .blocked: AccountSafety(kind: .blocked)
        case .reports: AccountSafety(kind: .video)
        case .reportedPosts: AccountSafety(kind: .post)
        case .reportedComments: AccountSafety(kind: .comment)
        case .reportedAuthors: AccountSafety(kind: .author)
        case .hidden: AccountHidden()
        default: EmptyView()
        }
    }
}

struct AccountMe: View {
    @EnvironmentObject var app: JournalStore
    @State private var draftForRemoval: String?
    private var profile: Record { app.state["profile"] as? Record ?? [:] }
    private var moments: [Record] { app.state.rows("moments").filter { $0["draft"] as? Bool == false } }
    private var drafts: [Record] { app.state.rows("moments").filter { $0["draft"] as? Bool == true } }
    private var saved: [Record] { reactions("saves") }

    private func reactions(_ key: String) -> [Record] {
        let ids = Set(app.state.strings(key))
        return (app.photos + app.shorts).filter { ids.contains($0.accountID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            JournalHeader("Me", root: app.isRoot) {
                JournalIcon("settings", "Settings") { app.open(.settings) }
            }
            ScrollView {
                VStack(spacing: 10) {
                    AccountPortrait(name: profile.str("name"), path: profile.str("avatar"), size: 76)
                    AccountHeading(text: profile.str("name").isEmpty ? "Your little moments" : profile.str("name"))
                    Text(profile.str("bio").isEmpty ? "The everyday, through your eyes." : profile.str("bio"))
                        .multilineTextAlignment(.center).foregroundColor(.secondary)
                    HStack(spacing: 30) {
                        stat("Moments", moments.count)
                        stat("Saved", saved.count)
                        stat("Following", app.state.strings("following").count)
                    }
                    Button { app.open(.wallet) } label: {
                        HStack {
                            AccountGlyph(name: "wallet").accessibilityHidden(true)
                            Text("Wallet").font(.custom("Kalam-Bold", size: 19))
                            Spacer()
                            Text(accountCoinBalance(app.wallet))
                        }
                        .padding(.horizontal, 14).frame(maxWidth: 328, minHeight: 50)
                        .background(JournalColor.paper.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(JournalColor.petrol.opacity(0.6)))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                    AccountCategories(items: ["Moments", "Shorts", "Liked", "Saved", "Drafts"], selected: $app.meCollection)
                    collection.padding(.horizontal, 12)
                }.padding(.vertical, 12)
            }.refreshable { await app.accountRefresh(); app.refreshWallet() }
        }
        .onAppear { app.refreshWallet() }
        .alert("Delete this draft?", isPresented: Binding(get: { draftForRemoval != nil }, set: { if !$0 { draftForRemoval = nil } }), presenting: draftForRemoval) { id in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { _ = app.change("deleteMoment", ["id": id]) }
        }
    }

    private func stat(_ label: String, _ count: Int) -> some View {
        VStack(spacing: 0) {
            Text(count.formatted()).font(.custom("Kalam-Bold", size: 21))
            Text(label).font(.custom("Kalam-Regular", size: 15))
        }.accessibilityElement(children: .combine)
    }

    @ViewBuilder private var collection: some View {
        switch app.meCollection {
        case "Drafts":
            if drafts.isEmpty { AccountEmpty(title: "Room for an idea", detail: "Your unfinished moments will be kept here.") }
            ForEach(drafts, id: \.accountID) { draft in
                HStack {
                    Button { app.open(.compose(draft.accountID, nil)) } label: {
                        HStack {
                            cover(draft)
                            Text(draft.str("caption").isEmpty ? "An unfinished moment" : draft.str("caption"))
                            Spacer()
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    JournalIcon("trash", "Delete draft") { draftForRemoval = draft.accountID }
                }
                Divider()
            }
        case "Liked", "Saved":
            let liked = app.meCollection == "Liked"
            let works = liked ? reactions("likes") : saved
            if works.isEmpty {
                AccountEmpty(title: liked ? "No likes yet" : "Keep what catches your eye",
                             detail: liked ? "Photos, topic posts and shorts you like appear here." : "Save a photo or short to find it here.")
                JournalIcon("plus", "Find inspiration") { app.root(.home) }
            } else { PhotographyGrid(works: works, collection: true) }
        default:
            let photos = app.meCollection == "Moments"
            let works = photos ? moments : app.state.rows("shorts")
            if works.isEmpty {
                AccountEmpty(title: "No posts yet", detail: photos ? "Your photos will appear here." : "Your videos will appear here.")
            } else if photos {
                PhotographyMomentsGrid(works: works)
            } else { PhotographyGrid(works: works) }
        }
    }
}

private func cover(_ work: Record) -> some View {
    JournalImage(work.strings("images").first ?? work.str("poster"), mode: .fill)
        .frame(width: 58, height: 58).clipped().cornerRadius(8)
}

private struct AccountSettings: View {
    @EnvironmentObject var app: JournalStore
    @State private var deleting = false

    var body: some View {
        VStack(spacing: 0) {
            JournalHeader("Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    row("Edit profile", "edit") { app.open(.editProfile) }
                    row("Hidden works · " + String(app.hiddenAccountWorks.count), "eye") { app.open(.hidden) }
                    row("Blocked people · " + String(app.state.strings("blocked").count), "block") { app.open(.blocked) }
                    row("Reported videos · " + String(app.state.strings("reports").count), "info") { app.open(.reports) }
                    row("Reported posts · " + String(app.state.strings("reportedPosts").count), "info") { app.open(.reportedPosts) }
                    row("Reported comments · " + String(app.state.strings("reportedComments").count), "info") { app.open(.reportedComments) }
                    row("Reported authors · " + String(app.state.strings("reportedAuthors").count), "info") { app.open(.reportedAuthors) }
                    row("Terms of Service") { agreement("terms") }.accessibilityAddTraits(.isLink)
                    row("Privacy Policy") { agreement("privacy") }.accessibilityAddTraits(.isLink)
                    row("Artwork & credits", "info") { app.open(.credits) }
                    Text("Roro keeps your moments on this iPhone. Sharing opens your iPhone’s share sheet.")
                        .foregroundColor(.secondary).padding(.vertical)
                    row("Log out", "close") { app.logout() }
                    row("Clear local journal", "trash") { deleting = true }.foregroundColor(JournalColor.accent)
                    Text("Roro " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"))
                        .font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity).padding()
                }.padding(.horizontal, 20)
            }.refreshable { await app.accountRefresh() }
        }
        .alert("Clear local journal?", isPresented: $deleting) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { _ = app.change("clearLibrary") }
        } message: {
            Text("Delete your Roro photos, shorts, drafts, comments, notes, relationships and profile from this iPhone? Original photos, videos and purchase records are kept.")
        }
    }

    private func agreement(_ kind: String) { Task { await app.accountPerform("openAgreement", ["kind": kind]) } }

    private func row(_ label: String, _ icon: String = "", action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(label)
                    Spacer()
                    if !icon.isEmpty { AccountGlyph(name: icon, size: 28).accessibilityHidden(true) }
                }.frame(minHeight: 53).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Divider()
        }
    }
}

private struct AccountEditProfile: View {
    @EnvironmentObject var app: JournalStore
    @State private var name = ""
    @State private var bio = ""
    @State private var avatar = ""
    @State private var initialized = false
    @State private var picking = false

    var body: some View {
        let profile = app.state["profile"] as? Record ?? [:]
        VStack(spacing: 0) {
            JournalHeader("Edit profile")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        Task {
                            picking = true
                            defer { picking = false }
                            do {
                                if let selected = try await app.perform("pickPhotos", ["purpose": "avatar"]) as? [String],
                                   let first = selected.first { avatar = first }
                            } catch { app.showError(error) }
                        }
                    } label: {
                        AccountPortrait(name: name, path: avatar, size: 80)
                            .overlay(alignment: .bottomTrailing) {
                                AccountGlyph(name: "camera", size: 25).background(JournalColor.paper, in: Circle())
                            }
                    }.buttonStyle(.plain).frame(maxWidth: .infinity).accessibilityLabel("Change profile photo")
                    Text("Name")
                    TextField("Your name", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("Name")
                        .onChange(of: name) { if $0.count > 40 { name = String($0.prefix(40)) } }
                    Text("About you")
                    TextField("A little about your everyday", text: $bio, axis: .vertical)
                        .lineLimit(2...5).textFieldStyle(.roundedBorder).accessibilityLabel("About you")
                        .onChange(of: bio) { if $0.count > 160 { bio = String($0.prefix(160)) } }
                    JournalIcon("check", "Save profile") {
                        var payload: Record = ["name": name, "bio": bio]
                        if !avatar.isEmpty { payload["avatar"] = avatar }
                        if app.change("profile", payload) { app.back() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (!profile.str("name").isEmpty || avatar.isEmpty))
                    .frame(maxWidth: .infinity)
                }.padding(20)
            }
            .disabled(picking)
        }
        .onAppear {
            if !initialized {
                name = profile.str("name")
                bio = profile.str("bio")
                avatar = profile.str("avatar")
                initialized = true
            }
        }
    }
}

private struct AccountHidden: View {
    @EnvironmentObject var app: JournalStore
    var body: some View {
        VStack(spacing: 0) {
            JournalHeader("Hidden works")
            ScrollView {
                VStack(spacing: 8) {
                    if app.hiddenAccountWorks.isEmpty {
                        AccountEmpty(title: "Nothing hidden", detail: "Photos and shorts you hide can be shown again here.")
                    }
                    ForEach(app.hiddenAccountWorks, id: \.accountID) { work in
                        HStack {
                            if app.locked(work) {
                                JournalImage(work.str("preview"), mode: .fill).frame(width: 58, height: 58).clipped().cornerRadius(8)
                            } else { cover(work) }
                            Text(work.str("caption"))
                            Spacer()
                            JournalIcon("eye", "Show " + work.str("caption")) { _ = app.change("hide", ["id": work.accountID]) }
                        }
                        Divider()
                    }
                }.padding(20)
            }.refreshable { await app.accountRefresh() }
        }
    }
}
