import SwiftUI

struct PhotographyComments: View {
    let workID: String
    var onProfile: ((String) -> Void)? = nil
    var body: some View {
        PhotographyDiscussion(workID: workID, scrollToComments: false, showStorageNotice: true, onProfile: onProfile) { EmptyView() }
    }
}

private struct PhotographyCommentEntry: Identifiable {
    let record: Record
    let parent: Record?
    var id: String { record.str("id") }

    static func thread(_ records: [Record]) -> [Self] {
        let byID = Dictionary(records.map { ($0.str("id"), $0) }, uniquingKeysWith: { existing, _ in existing })
        var replies: [String: [Record]] = [:]
        var roots: [Record] = []
        for record in records {
            let parent = record.str("parentID")
            if byID[parent] != nil { replies[parent, default: []].append(record) }
            else { roots.append(record) }
        }
        var visited = Set<String>()
        var pending = Array(roots.reversed())
        var ordered: [Self] = []
        while let record = pending.popLast() {
            let id = record.str("id")
            guard visited.insert(id).inserted else { continue }
            ordered.append(Self(record: record, parent: byID[record.str("parentID")]))
            if let children = replies[id] { pending.append(contentsOf: children.reversed()) }
        }
        return ordered
    }
}

private struct PhotographyDiscussion<Prefix: View>: View {
    @EnvironmentObject private var app: JournalStore
    let workID: String
    let scrollToComments: Bool
    let showStorageNotice: Bool
    var onProfile: ((String) -> Void)? = nil
    @ViewBuilder let prefix: () -> Prefix
    @State private var text = ""
    @State private var replyID: String?
    @State private var didScroll = false
    @FocusState private var focused: Bool

    var body: some View {
        let comments = app.comments(workID)
        let thread = PhotographyCommentEntry.thread(comments)
        let reply = comments.first { $0.str("id") == replyID }
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        prefix()
                        PhotographyTitle(title: "Comments · \(comments.count)", size: 20)
                            .id("discussion").padding(.horizontal, 14)
                        if thread.isEmpty { Text("Start with a little thought.").padding(.horizontal, 14) }
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(thread) { entry in
                                PhotographyCommentLine(workID: workID, entry: entry, open: { id in
                                    focused = false
                                    if let onProfile { onProfile(id) }
                                    else { app.openPhotographyProfile(id) }
                                }, reply: {
                                    replyID = entry.id
                                    focused = true
                                })
                            }
                        }.padding(.horizontal, 14)
                        if showStorageNotice {
                            Text("Your comments are kept on this iPhone.").font(.footnote).padding(.horizontal, 14)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
                }.scrollDismissesKeyboard(.interactively)
                    .refreshable { _ = await app.photographyRefresh() }
                    .onAppear {
                        if scrollToComments && !didScroll {
                            didScroll = true
                            DispatchQueue.main.async { proxy.scrollTo("discussion", anchor: .top) }
                        }
                    }
            }
            VStack(spacing: 1) {
                if replyID != nil {
                    HStack {
                        Text(reply.map { "Replying to " + app.photographyMember($0.str("authorID")).str("name") } ?? "Comment unavailable")
                        Spacer()
                        JournalIcon("close", "Cancel reply") { replyID = nil; focused = true }
                    }
                }
                HStack(alignment: .bottom, spacing: 6) {
                    TextField(replyID == nil ? "Add a comment…" : "Write a reply…", text: $text, axis: .vertical)
                        .lineLimit(1...4).focused($focused)
                        .padding(9).background(PhotographyCatalog.cream, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel(replyID == nil ? "Add a comment" : "Write a reply")
                        .onChange(of: text) { if $0.count > 500 { text = String($0.prefix(500)) } }
                    JournalIcon("send", "Add comment") {
                        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !content.isEmpty, replyID == nil || reply != nil else { return }
                        var payload: Record = ["id": UUID().uuidString, "postID": workID, "text": content]
                        payload["parentID"] = replyID
                        if app.change("addComment", payload) { text = ""; replyID = nil; focused = false }
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (replyID != nil && reply == nil))
                }
            }.padding(.horizontal, 12).padding(.vertical, 4)
                .background(JournalColor.paper.opacity(0.96))
        }.buttonStyle(.plain)
    }
}

private struct PhotographyCommentLine: View {
    @EnvironmentObject private var app: JournalStore
    let workID: String
    let entry: PhotographyCommentEntry
    let open: (String) -> Void
    let reply: () -> Void

    var body: some View {
        let authorID = entry.record.str("authorID")
        let member = app.photographyMember(authorID)
        HStack(alignment: .top, spacing: 6) {
            Button { open(authorID) } label: {
                PhotographyPortrait(profile: member).frame(width: 44, height: 44).contentShape(Rectangle())
            }.accessibilityLabel("Open \(member.str("name"))'s profile")
            VStack(alignment: .leading, spacing: 0) {
                Button { open(authorID) } label: { Text(member.str("name")).fontWeight(.bold).frame(minHeight: 44) }
                let parentName = entry.parent.map { "@" + app.photographyMember($0.str("authorID")).str("name") + " " } ?? ""
                Text(parentName).foregroundColor(JournalColor.petrol) + Text(entry.record.str("text"))
                HStack(spacing: 3) {
                    Text(PhotographyCatalog.shortDate(entry.record.str("createdAt"))).font(.footnote)
                    JournalIcon("comment", "Reply to \(member.str("name"))", action: reply)
                    PhotographyOptions(work: ["id": workID], placement: .comment, comment: entry.record)
                }
            }
        }.padding(.leading, entry.parent == nil ? 0 : 20)
    }
}

private struct PhotographyFullImage: Identifiable {
    let id: String
}

struct PhotographyDetail: View {
    @EnvironmentObject private var app: JournalStore
    let id: String
    let focusComments: Bool
    @State private var fullImage: PhotographyFullImage?

    var body: some View {
        let photo = app.photos.first { $0.str("id") == id }
        VStack(spacing: 0) {
            JournalHeader("A little moment") {
                if let photo, !photo.str("authorID").isEmpty { PhotographyOptions(work: photo, placement: .detail) }
            }
            if let photo {
                if app.locked(photo) {
                    ScrollView {
                        VStack(spacing: 10) {
                            Text("\(photo.str("author")) · \(photo.str("topic"))")
                            PhotographyTitle(title: photo.str("caption"))
                            if app.wallet.isEmpty { Text("Checking balance…") }
                            else { Text("Your balance: \(app.wallet.int("balance")) Coins") }
                            PhotographyUnlock(work: photo, category: false)
                            PhotographyUnlock(work: photo, category: true)
                            Text("The pass includes current and future works in \(photo.str("topic")) on this iPhone.").font(.footnote)
                            if app.wallet.isEmpty || app.wallet.int("balance") < max(photo.int("coinPrice"), app.passPrice(photo.str("topic"))) {
                                PhotographyLabeledAction(icon: "wallet", label: "Add coins") { app.open(.wallet) }
                            }
                        }.multilineTextAlignment(.center).padding()
                    }.refreshable { _ = await app.photographyRefresh() }
                } else {
                    PhotographyDiscussion(workID: id, scrollToComments: focusComments, showStorageNotice: false) {
                        detail(photo)
                    }
                }
            } else {
                VStack { PhotographyTitle(title: "Photo unavailable"); Text("This photo may have been removed.") }.padding()
                Spacer()
            }
        }.buttonStyle(.plain)
            .onChange(of: photo == nil) { missing in
                if missing, app.path.last == .photo(id, focusComments) { app.back() }
            }
            .fullScreenCover(item: $fullImage) { image in
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    JournalImage(image.id).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Full photo")
                    JournalIcon("close", "Close full photo") { fullImage = nil }
                        .background(JournalColor.paper.opacity(0.85), in: Circle()).padding()
                }
            }
    }

    private func detail(_ photo: Record) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(photo.strings("images").enumerated()), id: \.offset) { index, path in
                Button { fullImage = PhotographyFullImage(id: path) } label: {
                    JournalImage(path).frame(maxWidth: .infinity)
                }.accessibilityLabel("Open full photo \(index + 1)")
            }
            VStack(alignment: .leading, spacing: 6) {
                PhotographyAuthor(id: photo.str("authorID"))
                PhotographyTitle(title: photo.str("caption").isEmpty ? "A little moment" : photo.str("caption"))
                if !photo.str("topic").isEmpty {
                    Button { app.open(.topic(photo.str("topic"))) } label: { Text(photo.str("topic")).frame(minHeight: 44) }.foregroundStyle(JournalColor.petrol)
                }
                HStack(alignment: .top, spacing: 14) {
                    PhotographyReaction(work: photo, like: true)
                    PhotographyReaction(work: photo, like: false)
                    PhotographyCountAction(icon: "share", label: "Share photo") { if let first = photo.strings("images").first { app.sharePhotographyMedia(first) } }
                }
            }.padding(.horizontal, 14)
        }
    }
}
