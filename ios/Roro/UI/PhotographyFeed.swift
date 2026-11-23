import SwiftUI

struct PhotographyFeed: View {
    let photos: [Record]
    let shorts: [Record]

    var body: some View {
        LazyVGrid(columns: PhotographyCatalog.columns, spacing: 16) {
            ForEach(photos.map(PhotographyRow.init)) { PhotographyCard(work: $0.value) }
            ForEach(shorts.map(PhotographyRow.init)) { PhotographyShortCard(work: $0.value) }
        }.padding(.horizontal, 9).padding(.vertical, 6).buttonStyle(.plain)
    }
}

private struct PhotographyCard: View {
    @EnvironmentObject private var app: JournalStore
    let work: Record
    @State private var page = 0

    var body: some View {
        let id = work.str("id")
        let paths = work.strings("images")
        let locked = app.locked(work)
        VStack(alignment: .leading, spacing: 3) {
            Group {
                if paths.count > 1 {
                    Color.clear.aspectRatio(0.8, contentMode: .fit).overlay {
                        TabView(selection: $page) {
                            ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                                cover(path, index: index).tag(index)
                            }
                        }.tabViewStyle(.page(indexDisplayMode: .never))
                    }
                } else { cover(paths.first ?? "", index: 0) }
            }.padding(4).background(PhotographyCatalog.cream)
                .overlay(alignment: .topTrailing) {
                    Rectangle().fill(Color(red: 0.94, green: 0.75, blue: 0.45).opacity(0.8))
                        .frame(width: 31, height: 9).rotationEffect(.degrees(16)).padding(.trailing, 2).accessibilityHidden(true)
                }.shadow(color: .brown.opacity(0.22), radius: 2, y: 2)
            if paths.count > 1 { Text("\(paths.count) photos · Swipe to explore").font(.caption) }
            if !work.str("caption").isEmpty { Text(work.str("caption")).padding(.top, 4) }
            if locked {
                Text("\(work.str("author")) · \(work.str("topic"))").font(.footnote)
                PhotographyLabeledAction(icon: "credit-coin", label: "\(work.int("coinPrice")) Coins") { app.open(.photo(id, false)) }
            } else {
                HStack(spacing: 0) {
                    PhotographyAuthor(id: work.str("authorID"))
                    Spacer(minLength: 0)
                    PhotographyOptions(work: work, placement: .card)
                }
                HStack(spacing: 0) {
                    PhotographyReaction(work: work, like: true).frame(maxWidth: .infinity)
                    PhotographyCountAction(icon: "comment", label: "Open photo and comments", count: app.comments(id).count) {
                        app.open(.photo(id, true))
                    }.frame(maxWidth: .infinity)
                    PhotographyReaction(work: work, like: false).frame(maxWidth: .infinity)
                }
                if !work.str("topic").isEmpty {
                    Button { app.open(.topic(work.str("topic"))) } label: { Text(work.str("topic")).frame(minHeight: 44) }
                        .foregroundStyle(JournalColor.petrol)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func cover(_ path: String, index: Int) -> some View {
        Button { app.open(.photo(work.str("id"), false)) } label: { PhotographyCrop(path: path) }
            .accessibilityLabel("View photo \(index + 1)")
    }
}

private struct PhotographyShortCard: View {
    @EnvironmentObject private var app: JournalStore
    let work: Record
    @State private var deleting = false
    private var id: String { work.str("id") }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { app.open(.shorts(id, nil)) } label: {
                PhotographyCrop(path: work.str("poster"))
                    .overlay { PhotographyArt(icon: "shorts", size: 42) }
                    .overlay(alignment: .bottomTrailing) {
                        let seconds = Int(ceil((work["duration"] as? NSNumber)?.doubleValue ?? 0))
                        Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                            .font(.caption).foregroundStyle(.white).padding(4)
                            .background(.black.opacity(0.6), in: Capsule()).padding(4)
                    }
            }.accessibilityLabel("Play \(work.str("caption"))")
            HStack(spacing: 3) {
                PhotographyAuthor(id: work.str("authorID"))
                Spacer(minLength: 1)
                Text(PhotographyCatalog.shortDate(work.str("createdAt"))).font(.caption2)
            }
            if !work.str("caption").isEmpty { Text(work.str("caption")).lineLimit(2) }
            if !work.str("topic").isEmpty { Text(work.str("topic")).font(.footnote) }
            LazyVGrid(columns: PhotographyCatalog.columns, spacing: 1) {
                PhotographyReaction(work: work, like: true)
                PhotographyReaction(work: work, like: false)
                JournalIcon("share", "Share short") { app.sharePhotographyMedia(work.str("video")) }
                PhotographyCountAction(icon: "comment", label: "Open short and comments", count: app.comments(id).count) { app.open(.shorts(id, nil)) }
                if work.str("authorID").isEmpty { JournalIcon("trash", "Delete short") { deleting = true } }
            }
        }.padding(5).background(PhotographyCatalog.cream, in: RoundedRectangle(cornerRadius: 5))
            .alert("Delete this short from Roro?", isPresented: $deleting) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if app.change("deleteShort", ["id": id]) {
                        Task { _ = try? await app.perform("discardVideo", ["video": work.str("video")]) }
                    }
                }
            } message: { Text("Your original video is kept.") }
    }
}

enum PhotographyOptionPlacement {
    case card, detail, comment
}

private enum PhotographyConfirmation: String, Identifiable {
    case report, block, deletePhoto, deleteComment
    var id: String { rawValue }
}

struct PhotographyOptions: View {
    @EnvironmentObject private var app: JournalStore
    let work: Record
    let placement: PhotographyOptionPlacement
    var comment: Record? = nil

    @State private var showing = false
    @State private var shareAfterDismiss = false

    private var targetAuthor: String { comment?.str("authorID") ?? work.str("authorID") }
    private var authorName: String { app.photographyMember(targetAuthor).str("name") }
    private var title: String {
        if placement == .comment { return "More options for comment by \(authorName)" }
        return placement == .detail ? "More post options" : "Photo options"
    }

    var body: some View {
        JournalIcon("more", title) { showing = true }
            .sheet(isPresented: $showing, onDismiss: {
                if shareAfterDismiss {
                    shareAfterDismiss = false
                    if let image = work.strings("images").first { app.sharePhotographyMedia(image) }
                }
            }) {
                PhotographySafetySheet(work: work, placement: placement, comment: comment) {
                    shareAfterDismiss = true
                }.presentationDetents([.height(210), .medium])
            }
    }
}

private struct PhotographySafetySheet: View {
    @EnvironmentObject private var app: JournalStore
    @Environment(\.dismiss) private var dismiss
    let work: Record
    let placement: PhotographyOptionPlacement
    let comment: Record?
    let requestShare: () -> Void
    @State private var confirmation: PhotographyConfirmation?

    private var author: String { comment?.str("authorID") ?? work.str("authorID") }
    private var name: String { app.photographyMember(author).str("name") }
    private var isMine: Bool { author.isEmpty || author == "you" || comment?["local"] as? Bool == true }
    private var canReport: Bool { !isMine && (placement != .card || work.str("surface") == "topics") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if placement == .card && work.str("surface") != "topics" { PhotographyTitle(title: "This moment") }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 12) {
                    if canReport {
                        PhotographyLabeledAction(icon: "info", label: placement == .comment ? "Report comment" : "Report post", below: true) { confirmation = .report }
                        PhotographyLabeledAction(icon: "block", label: "Block", below: true) { confirmation = .block }.accessibilityLabel("Block \(name)")
                    }
                    if placement == .comment && isMine {
                        PhotographyLabeledAction(icon: "trash", label: "Delete comment", below: true) { confirmation = .deleteComment }
                    }
                    if placement == .card {
                        PhotographyLabeledAction(icon: "share", label: "Share photo", below: true) { requestShare(); dismiss() }
                        if isMine {
                            PhotographyLabeledAction(icon: "trash", label: "Delete moment", below: true) { confirmation = .deletePhoto }
                        } else {
                            PhotographyLabeledAction(icon: "eye", label: "Hide photo", below: true) {
                                if app.change("hide", ["id": work.str("id")]) { dismiss() }
                            }
                        }
                    }
                    PhotographyLabeledAction(icon: "close", label: "Cancel", below: true) { dismiss() }
                }
            }.padding(20)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { JournalPaper() }
            .alert(item: $confirmation) { selection in
                let label: String
                let title: String
                switch selection {
                case .report:
                    label = "Report"
                    title = "Report this \(placement == .comment ? "comment" : "post") and hide it for this account?"
                case .block: label = "Block"; title = "If you block \(name), you’ll no longer see their posts or comments."
                case .deletePhoto: label = "Delete"; title = "Delete this moment from Roro? Your original photos are kept."
                case .deleteComment: label = "Delete"; title = "Delete this comment?"
                }
                return Alert(title: Text(title), primaryButton: .destructive(Text(label)) { commit(selection) }, secondaryButton: .cancel())
            }
    }

    private func commit(_ selection: PhotographyConfirmation) {
        let postID = work.str("id")
        let commentID = comment?.str("id")
        let success: Bool
        switch selection {
        case .block:
            var payload: Record = ["id": author, "enabled": true, "postID": postID]
            payload["commentID"] = commentID
            success = app.change("setBlock", payload)
        case .report:
            var payload: Record = ["kind": commentID == nil ? "post" : "comment", "id": commentID ?? postID, "enabled": true]
            if commentID != nil { payload["postID"] = postID }
            success = app.change("setReport", payload)
            if success { app.confirmation = "Report saved for this account." }
        case .deletePhoto: success = app.change("deleteMoment", ["id": postID])
        case .deleteComment: success = app.change("deleteComment", ["id": commentID ?? ""])
        }
        if success { dismiss() }
    }
}

struct PhotographyUnlock: View {
    @EnvironmentObject private var app: JournalStore
    let work: Record
    let category: Bool
    var redirectIfNeeded = false
    @State private var confirming = false
    @State private var busy = false

    private var topic: String { work.str("topic") }
    private var price: Int { category ? app.passPrice(topic) : work.int("coinPrice") }

    var body: some View {
        PhotographyLabeledAction(icon: category ? "topics" : "credit-coin", label: "\(category ? "Category pass" : "This work") · \(price) Coins") {
            if app.wallet.int("balance") < price && redirectIfNeeded { app.open(.wallet) }
            else { confirming = true }
        }.disabled(busy || price <= 0 || (!redirectIfNeeded && app.wallet.int("balance") < price))
            .alert("Spend \(price) Coins?", isPresented: $confirming) {
                Button("Cancel", role: .cancel) {}
                Button("Unlock") {
                    busy = true
                    Task {
                        defer { busy = false }
                        do { _ = try await app.perform("unlockTopicWork", ["id": work.str("id"), "scope": category ? "category" : "work", "price": price]) }
                        catch { app.showError(error) }
                    }
                }
            } message: {
                Text(category ? "Unlock all current and future works in \(topic) on this iPhone." : "Unlock this work on this iPhone.")
            }
    }
}
