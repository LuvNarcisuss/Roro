import SwiftUI

private func chatMembership(_ state: Record, _ key: String, _ id: String) -> Bool {
    state.strings(key).contains(id)
}

private func relationship(_ person: Record, state: Record) -> String {
    let id = person.str("id")
    for (key, label) in [("incomingRequests", "Friend request"), ("verifiedFriends", "Friends"), ("messagingPeers", "Mutual follow"), ("contacts", "Request pending"), ("followers", "Follows you")] {
        if chatMembership(state, key, id) { return label }
    }
    return "@" + person.str("handle")
}

private struct ChatSearch: View {
    let placeholder: String
    @Binding var query: String
    @Binding var expanded: Bool
    @FocusState private var focused: Bool

    var body: some View {
        if expanded {
            HStack(spacing: 2) {
                TextField(placeholder, text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit { focused = false }
                    .frame(maxWidth: 160)
                    .padding(.leading, 6)
                JournalIcon("close", "Close search") {
                    focused = false
                    query = ""
                    expanded = false
                }
            }
            .background(JournalColor.paper)
            .onAppear { focused = true }
        } else {
            JournalIcon("search", placeholder) { expanded = true }
        }
    }
}

private struct ChatAvatar: View {
    @EnvironmentObject var app: JournalStore
    let person: Record

    var body: some View {
        Button {
            app.open(.member(person.str("id")))
        } label: {
            AccountPortrait(name: person.str("name"), path: person.str("avatar"), size: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View " + person.str("name") + "'s profile")
    }
}

private struct ChatRequests: View {
    @EnvironmentObject var app: JournalStore
    let person: Record
    @State private var confirmRemoval = false

    var body: some View {
        let id = person.str("id")
        let name = person.str("name")
        let requested = chatMembership(app.state, "contacts", id)
        if chatMembership(app.state, "incomingRequests", id) {
            JournalIcon("check", "Accept request from " + name) { _ = app.change("respondFriendRequest", ["peerID": id, "accept": true]) }
            JournalIcon("close", "Decline request from " + name) { _ = app.change("respondFriendRequest", ["peerID": id, "accept": false]) }
        } else if chatMembership(app.state, "verifiedFriends", id) {
            JournalIcon("close", "Remove " + name + " from friends") { confirmRemoval = true }
                .alert("Remove " + name + " from friends?", isPresented: $confirmRemoval) {
                    Button("Cancel", role: .cancel) {}
                    Button("Remove", role: .destructive) { _ = app.change("removeFriend", ["peerID": id]) }
                }
        } else if requested || !chatMembership(app.state, "messagingPeers", id) {
            JournalIcon(requested ? "close" : "add-friend", (requested ? "Cancel request to " : "Send friend request to ") + name) {
                _ = app.change("setContact", ["peerID": id, "enabled": !requested])
            }
        }
    }
}

struct AccountChats: View {
    @EnvironmentObject var app: JournalStore
    @State private var removal: ChatRemoval?

    private struct ChatRemoval: Identifiable {
        let id: String
        let entryID: String
        let name: String
    }

    private struct InboxRow: Identifiable {
        let person: Record
        let last: Record?
        let position: Int
        let pin: Int
        let unread: Bool
        var id: String { person.str("id") }
    }

    private var rows: [InboxRow] {
        var latest: [String: (Int, Record)] = [:]
        for (index, entry) in app.state.rows("chatEntries").enumerated() {
            latest[entry.str("peerID")] = (index, entry)
        }
        let pins = app.state.strings("pinnedChats")
        let term = app.chatQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates: [InboxRow] = app.members.compactMap { member in
            let id = member.str("id")
            guard !chatMembership(app.state, "blocked", id) else { return nil }
            let entry = latest[id]
            if app.chatScope == "Friends" {
                guard chatMembership(app.state, "messagingPeers", id) else { return nil }
            } else {
                guard entry != nil, chatMembership(app.state, "archivedChats", id) == (app.chatScope == "Archived") else { return nil }
            }
            let fields = [member.str("name"), member.str("handle"), entry?.1.str("text") ?? ""]
            guard term.isEmpty || fields.contains(where: { $0.localizedCaseInsensitiveContains(term) }) else { return nil }
            return InboxRow(person: member, last: entry?.1, position: entry?.0 ?? -1,
                            pin: pins.firstIndex(of: id) ?? -1, unread: chatMembership(app.state, "unreadChats", id))
        }
        return candidates.sorted {
            if $0.pin != $1.pin { return $0.pin > $1.pin }
            return app.chatScope == "Friends"
                ? $0.person.str("name").localizedCaseInsensitiveCompare($1.person.str("name")) == .orderedAscending
                : $0.position > $1.position
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            JournalHeader(app.chatSearching ? "" : "Chats", root: true) {
                ChatSearch(placeholder: "Search chats", query: $app.chatQuery, expanded: $app.chatSearching)
                JournalIcon("add-friend", "Find friends") { app.open(.friends) }
            }
            AccountCategories(items: ["Recent", "Friends", "Archived"], selected: $app.chatScope)
            List {
                if rows.isEmpty {
                    VStack(spacing: 10) {
                        AccountGlyph(name: app.chatScope == "Friends" ? "add-friend" : "chat", size: 68)
                        Text(emptyLabel).font(.custom("Courgette-Regular", size: 23))
                        if app.chatQuery.isEmpty, app.chatScope != "Archived" {
                            JournalIcon("add-friend", "Find friends") { app.open(.friends) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                ForEach(rows) { row in
                    inboxRow(row)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if let last = row.last {
                                deleteAction(row, last)
                                unreadAction(row).tint(.orange)
                                pinAction(row).tint(JournalColor.petrol)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await app.accountRefresh() }
        }
        .alert(item: $removal) { item in
            Alert(title: Text("Delete all messages with " + item.name + " on this iPhone?"),
                  primaryButton: .destructive(Text("Delete")) { _ = app.change("deleteConversation", ["peerID": item.id, "lastEntryID": item.entryID]) },
                  secondaryButton: .cancel())
        }
    }

    private var emptyLabel: String {
        if !app.chatQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "No matches" }
        switch app.chatScope {
        case "Friends": return "No friends yet"
        case "Archived": return "No archived chats"
        default: return "No conversations yet"
        }
    }

    private func inboxRow(_ row: InboxRow) -> some View {
        HStack(spacing: 10) {
            ChatAvatar(person: row.person)
            Button {
                app.open(.chat(row.id))
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.person.str("name")).font(.custom("Kalam-Bold", size: 18))
                        Text(row.last?.str("text") ?? "@" + row.person.str("handle"))
                            .lineLimit(1).foregroundColor(.secondary)
                    }
                    Spacer()
                    if let last = row.last {
                        VStack(alignment: .trailing, spacing: 1) {
                            AccountDate(iso: last.str("createdAt"))
                            if row.unread {
                                AccountGlyph(name: "chat", size: 26)
                                    .overlay(alignment: .topTrailing) {
                                        Text("1").font(.caption2.bold()).foregroundColor(.white)
                                            .padding(.horizontal, 3).background(JournalColor.accent, in: Capsule())
                                    }
                                    .accessibilityLabel("1 unread")
                            }
                        }
                    }
                    if row.pin >= 0 {
                        AccountGlyph(name: "chat-pin", size: 21).accessibilityLabel("Pinned")
                    }
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let last = row.last {
                Menu {
                    menuActions(row, last)
                } label: {
                    AccountGlyph(name: "more", size: 24)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Actions for " + row.person.str("name"))
            }
        }
        .contextMenu {
            if let last = row.last { menuActions(row, last) }
        }
    }

    @ViewBuilder private func menuActions(_ row: InboxRow, _ last: Record) -> some View {
        pinAction(row)
        unreadAction(row)
        deleteAction(row, last)
    }

    private func pinAction(_ row: InboxRow) -> some View {
        Button(row.pin >= 0 ? "Unpin" : "Pin") {
            _ = app.change("setChatPinned", ["peerID": row.id, "enabled": row.pin < 0])
        }
    }

    private func unreadAction(_ row: InboxRow) -> some View {
        Button(row.unread ? "Mark read" : "Mark unread") {
            _ = app.change("setChatUnread", ["peerID": row.id, "enabled": !row.unread])
        }
    }

    private func deleteAction(_ row: InboxRow, _ last: Record) -> some View {
        Button("Delete", role: .destructive) {
            removal = ChatRemoval(id: row.id, entryID: last.str("id"), name: row.person.str("name"))
        }
    }
}

struct AccountFriends: View {
    @EnvironmentObject var app: JournalStore
    @State private var query = ""
    @State private var expanded = false

    var body: some View {
        let stripped = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let term = stripped.hasPrefix("@") ? String(stripped.dropFirst()) : stripped
        let people = app.members.filter { person in
            let id = person.str("id")
            guard !chatMembership(app.state, "blocked", id) else { return false }
            if term.isEmpty { return chatMembership(app.state, "incomingRequests", id) || chatMembership(app.state, "contacts", id) }
            return (person.str("name") + " " + person.str("handle")).localizedCaseInsensitiveContains(term)
        }
        VStack(spacing: 0) {
            JournalHeader(expanded ? "" : "Find friends") {
                ChatSearch(placeholder: "Search people", query: $query, expanded: $expanded)
            }
            ScrollView {
                VStack(alignment: .leading) {
                    AccountHeading(text: term.isEmpty ? "Friend requests" : "Search results")
                    ForEach(people, id: \.accountID) { person in
                        let id = person.str("id")
                        HStack(spacing: 6) {
                            ChatAvatar(person: person)
                            Button {
                                app.open(.member(id))
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(person.str("name")).font(.custom("Kalam-Bold", size: 18))
                                    Text(relationship(person, state: app.state)).foregroundColor(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            if chatMembership(app.state, "messagingPeers", id) {
                                JournalIcon("chat", "Message " + person.str("name")) { app.open(.chat(id)) }
                            }
                            ChatRequests(person: person)
                        }
                        Divider()
                    }
                    if people.isEmpty { AccountEmpty(title: term.isEmpty ? "No friend requests." : "No matching people.") }
                }.padding()
            }.refreshable { await app.accountRefresh() }
        }
    }
}

struct AccountConversation: View {
    @EnvironmentObject var app: JournalStore
    let peerID: String
    @State private var message = ""
    @State private var entryID = UUID().uuidString

    var body: some View {
        VStack(spacing: 0) {
            JournalHeader("Message")
            if let person = app.members.first(where: { $0.str("id") == peerID }), !chatMembership(app.state, "blocked", peerID) {
                let eligible = chatMembership(app.state, "messagingPeers", peerID)
                let archived = chatMembership(app.state, "archivedChats", peerID)
                let entries = app.state.rows("chatEntries").filter { $0.str("peerID") == peerID }
                HStack(spacing: 3) {
                    ChatAvatar(person: person)
                    VStack(alignment: .leading) {
                        Text(person.str("name")).font(.custom("Kalam-Bold", size: 17))
                        Text("@" + person.str("handle")).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                    if eligible {
                        JournalIcon("voice-call", "Voice call") { preview("voice") }
                        JournalIcon("video-call", "Video call") { preview("video") }
                    }
                    if !entries.isEmpty {
                        JournalIcon(archived ? "bookmark" : "bookmark-outline", archived ? "Unarchive conversation" : "Archive conversation", selected: archived) {
                            _ = app.change("setChatArchived", ["peerID": peerID, "enabled": !archived])
                        }
                    }
                }.padding(.horizontal, 12).padding(.vertical, 8)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .trailing, spacing: 10) {
                            if entries.isEmpty { AccountEmpty(title: "No messages yet") }
                            ForEach(entries, id: \.accountID) { entry in
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(entry.str("text")).fixedSize(horizontal: false, vertical: true)
                                    AccountDate(iso: entry.str("createdAt"))
                                }
                                .padding(10)
                                .background(JournalColor.petrol.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                                .padding(.leading, 30)
                                .id(entry.accountID)
                            }
                        }.frame(maxWidth: .infinity, alignment: .trailing).padding()
                    }
                    .onAppear { if let last = entries.last { proxy.scrollTo(last.accountID, anchor: .bottom) } }
                    .onChange(of: entries.last?.accountID) { id in if let id { proxy.scrollTo(id, anchor: .bottom) } }
                }
                Divider()
                HStack(spacing: 8) {
                    if eligible {
                        TextField("Write a message…", text: $message, axis: .vertical)
                            .accessibilityLabel("Message")
                            .lineLimit(1...4)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: message) { value in
                                if value.count > 2000 { message = String(value.prefix(2000)) }
                                entryID = UUID().uuidString
                            }
                        JournalIcon("check", "Send message") {
                            let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                            if app.change("saveChatEntry", ["id": entryID, "peerID": peerID, "text": text]) {
                                message = ""
                                entryID = UUID().uuidString
                            }
                        }.disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        let hasRequest = chatMembership(app.state, "incomingRequests", peerID) || chatMembership(app.state, "contacts", peerID)
                        Text(hasRequest ? relationship(person, state: app.state) : "Friend approval required")
                        ChatRequests(person: person)
                    }
                }.padding(.horizontal, 12).padding(.vertical, 6)
            } else {
                AccountEmpty(title: "Conversation unavailable.")
                Spacer()
            }
        }
        .onAppear {
            if chatMembership(app.state, "unreadChats", peerID) { _ = app.change("setChatUnread", ["peerID": peerID, "enabled": false]) }
        }
    }

    private func preview(_ mode: String) {
        Task { await app.accountPerform("openCallPreview", ["peerID": peerID, "mode": mode]) }
    }
}
