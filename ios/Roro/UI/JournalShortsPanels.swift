import SwiftUI

struct JournalShortComments: View {
    let workID: String
    let close: () -> Void
    let profile: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); PhotographyLabeledAction(icon: "close", label: "Close", below: true, action: close) }
                .padding(.horizontal).padding(.top, 8)
            PhotographyComments(workID: workID, onProfile: profile)
        }
        .modifier(ShortPaper())
    }
}

struct ShortPaper: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Kalam-Regular", size: 16, relativeTo: .body))
            .foregroundStyle(JournalColor.ink)
            .background { JournalPaper() }
    }
}

private enum ShortConfirmation: String, Identifiable {
    case report, reportAuthor, block, delete
    var id: String { rawValue }
}

struct JournalShortOptions: View {
    @EnvironmentObject private var app: JournalStore
    let clip: Record
    let close: () -> Void
    let notifyOnDismiss: (String) -> Void
    var share: (() -> Void)? = nil
    @State private var editingNotes = false
    @State private var note = ""
    @State private var confirmation: ShortConfirmation?
    private var workID: String { clip.str("id") }
    private var authorID: String { clip.str("authorID") }
    private var authorName: String { app.photographyMember(authorID).str("name") }
    private var notes: [Record] { app.state.rows("notes").filter { $0.str("postID") == workID } }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                PhotographyTitle(title: editingNotes ? "Private notes" : "This short")
                Spacer()
                PhotographyLabeledAction(icon: "close", label: "Close", below: true, action: close)
            }
            ScrollView {
                if editingNotes { noteForm }
                else { options }
            }
        }
        .padding(18)
        .modifier(ShortPaper())
        .alert(item: $confirmation) { kind in
            switch kind {
            case .reportAuthor, .block:
                let blocking = kind == .block
                let title = blocking ? "If you block \(authorName), you’ll no longer see their posts or comments." : "Report \(authorName) for this account?"
                return Alert(title: Text(title), primaryButton: .destructive(Text(blocking ? "Block" : "Report")) {
                    let payload: Record = ["id": authorID, "kind": "author", "postID": workID, "enabled": true]
                    if app.change(blocking ? "setBlock" : "setReport", payload) {
                        if !blocking { notifyOnDismiss("Report saved for this account.") }
                        close()
                    }
                }, secondaryButton: .cancel())
            case .report:
                return Alert(title: Text("Report this video and hide it for this account?"),
                             primaryButton: .destructive(Text("Report")) {
                    if app.change("setReport", ["kind": "video", "id": workID, "enabled": true]) {
                        notifyOnDismiss("Report saved for this account.")
                        close()
                    }
                }, secondaryButton: .cancel())
            case .delete:
                return Alert(title: Text("Delete this short from Roro?"),
                             message: Text("Your original video is kept."),
                             primaryButton: .destructive(Text("Delete")) {
                    let video = clip.str("video")
                    if app.change("deleteShort", ["id": workID]) {
                        Task { _ = try? await app.perform("discardVideo", ["video": video]) }
                        notifyOnDismiss("Short deleted.")
                        close()
                    }
                }, secondaryButton: .cancel())
            }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(clip.str("authorID").isEmpty ? "This video is saved in your personal Roro library." : "Video by \(clip.str("sourceAuthor")) · Pexels License")
                .foregroundStyle(JournalColor.ink.opacity(0.76))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .top)], spacing: 16) {
                if let share {
                    PhotographyLabeledAction(icon: "share", label: "Share short", below: true, action: share)
                }
                PhotographyLabeledAction(icon: "edit", label: "Private notes · \(notes.count)", below: true) { editingNotes = true }
                if clip.str("authorID").isEmpty {
                    PhotographyLabeledAction(icon: "trash", label: "Delete short", below: true) { confirmation = .delete }
                } else {
                    PhotographyLabeledAction(icon: "share", label: "View original source", below: true) {
                        Task { do { _ = try await app.perform("openSource", ["id": workID]) } catch { app.showError(error) } }
                    }
                    PhotographyLabeledAction(icon: "info", label: "Report video", below: true) { confirmation = .report }
                    PhotographyLabeledAction(icon: "profile", label: "Report author", below: true) { confirmation = .reportAuthor }.accessibilityLabel("Report author " + authorName)
                    PhotographyLabeledAction(icon: "block", label: "Block", below: true) { confirmation = .block }.accessibilityLabel("Block " + authorName)
                    PhotographyLabeledAction(icon: "eye", label: "Hide short", below: true) {
                        if app.change("hide", ["id": workID]) { close() }
                    }
                }
            }
        }
    }

    private var noteForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A few words for yourself. Notes stay on this iPhone.").foregroundStyle(JournalColor.ink.opacity(0.74))
            if notes.isEmpty { Text("No notes yet.") }
            ForEach(notes.map(PhotographyRow.init)) { entry in
                HStack {
                    Text(entry.value.str("text"))
                    Spacer()
                    JournalIcon("trash", "Delete note") { _ = app.change("deleteNote", ["id": entry.id]) }
                }
                Divider()
            }
            Text("Add a note")
            TextField("Add a note", text: $note, axis: .vertical)
                .lineLimit(2...6).textFieldStyle(.roundedBorder)
                .onChange(of: note) { if $0.count > 500 { note = String($0.prefix(500)) } }
            HStack {
                Spacer()
                JournalIcon("bookmark", "Save note") {
                    if app.change("addNote", ["id": UUID().uuidString, "postID": workID, "text": note.trimmingCharacters(in: .whitespacesAndNewlines)]) {
                        note = ""
                    }
                }.disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
