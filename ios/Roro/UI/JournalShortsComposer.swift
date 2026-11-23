import SwiftUI

struct JournalShortComposer: View {
    @EnvironmentObject private var app: JournalStore
    @State private var topic: String
    @State private var caption = ""
    @State private var video: Record?
    @State private var pending = false
    @State private var failure = ""
    @State private var confirmingDiscard = false
    @State private var id = UUID().uuidString
    let onClose: ((String?) -> Void)?

    init(initialTopic: String = "", onClose: ((String?) -> Void)? = nil) {
        _topic = State(initialValue: initialTopic)
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("A little motion").font(.custom("Courgette-Regular", size: 27, relativeTo: .title))
                    .foregroundStyle(JournalColor.petrol).accessibilityAddTraits(.isHeader)
                HStack {
                    Spacer()
                    JournalIcon("close", "Close") {
                        if video != nil || !caption.isEmpty { confirmingDiscard = true }
                        else { finish(nil) }
                    }.disabled(pending)
                }
            }.padding(.horizontal, 16).padding(.vertical, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Keep a little piece of your day. Up to 60 seconds.")
                    if let video { preview(video) }
                    if pending {
                        ProgressView("Preparing your video…")
                    } else {
                        JournalIcon("plus", video == nil ? "Choose a video" : "Choose another video") { choose() }
                            .frame(maxWidth: .infinity)
                    }
                    if !failure.isEmpty { Text(failure).foregroundStyle(JournalColor.accent) }
                    Text("A few words")
                    TextField("The little things in motion…", text: $caption, axis: .vertical)
                        .accessibilityLabel("A few words").lineLimit(3...6)
                        .textFieldStyle(.roundedBorder).disabled(pending)
                        .onChange(of: caption) { if $0.count > 500 { caption = String($0.prefix(500)) } }
                    Text("Topic · optional")
                    Picker("Topic", selection: $topic) {
                        Text("No topic").tag("")
                        ForEach(PhotographyCatalog.topics, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu).tint(JournalColor.petrol).disabled(pending)
                    Text("Your short stays in your library on this iPhone.")
                    JournalIcon("check", "Save short") { save() }
                        .disabled(pending || video == nil).frame(maxWidth: .infinity)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .modifier(ShortPaper())
        .interactiveDismissDisabled(pending || video != nil || !caption.isEmpty)
        .alert("Discard this short?", isPresented: $confirmingDiscard) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive) {
                pending = true
                Task {
                    if let video { _ = try? await app.perform("discardVideo", ["video": video.str("video")]) }
                    pending = false
                    finish(nil)
                }
            }
        } message: { Text("Your original video is kept.") }
    }

    private func finish(_ saved: String?) {
        if let onClose { onClose(saved) }
        else {
            app.back()
            if let saved { app.open(.shorts(saved, nil)) }
        }
    }

    private func preview(_ video: Record) -> some View {
        Button {
            Task { do { _ = try await app.perform("playVideo", ["video": video.str("video")]) } catch { failure = error.localizedDescription } }
        } label: {
            VStack(spacing: 8) {
                JournalImage(video.str("poster")).frame(height: 218)
                HStack {
                    JournalImage("assets/icons/shorts.png").frame(width: 23, height: 23)
                    Text(journalShortClock(ceil((video["duration"] as? NSNumber)?.doubleValue ?? 0)))
                        .foregroundStyle(.white)
                }.padding(.bottom, 8)
            }.frame(maxWidth: .infinity).background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain).accessibilityLabel("Preview selected video").disabled(pending)
    }

    private func choose() {
        guard !pending else { return }
        pending = true
        failure = ""
        Task {
            defer { pending = false }
            do {
                if let selected = try await app.perform("pickVideo") as? Record {
                    let previous = video
                    video = selected
                    if let previous, previous.str("video") != selected.str("video") {
                        _ = try? await app.perform("discardVideo", ["video": previous.str("video")])
                    }
                }
            } catch { failure = error.localizedDescription }
        }
    }

    private func save() {
        guard !pending, var payload = video else { return }
        payload["id"] = id
        payload["caption"] = caption
        payload["topic"] = topic
        if app.change("saveShort", payload) {
            if onClose == nil { app.message = "Short saved to your library." }
            finish(id)
        } else { failure = "Your short could not be saved. Keep this page open and try again." }
    }
}
