import SwiftUI

struct PhotographyCompose: View {
    @EnvironmentObject private var app: JournalStore
    let draftID: String?
    let topic: String?
    @State private var newID = UUID().uuidString
    @State private var loaded = false
    @State private var caption = ""
    @State private var category = ""
    @State private var surface = "home"
    @State private var images: [String] = []
    @State private var paid = false
    @State private var price = "10"
    @State private var picking = false
    @State private var discard = false
    @State private var missingDraft = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                PhotographyTitle(title: draftID == nil ? "A new moment" : "Your draft", size: 24)
                HStack {
                    JournalIcon("back", "Back") {
                        if images.isEmpty && caption.isEmpty { app.back() }
                        else { discard = true }
                    }
                    Spacer()
                }
            }.padding(.horizontal, 8).frame(minHeight: 54)
            if missingDraft {
                Text("This draft is no longer available.").padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        photoPicker
                        Text("A few words · Optional")
                        TextField("What would you like to remember?", text: $caption, axis: .vertical)
                            .lineLimit(3...6).padding(10)
                            .background(PhotographyCatalog.cream, in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: caption) { if $0.count > 500 { caption = String($0.prefix(500)) } }
                        VStack(alignment: .leading) {
                            Text(surface == "topics" ? "Topic" : "Topic · Optional")
                            Picker("Topic", selection: $category) {
                                Text("Choose a topic").tag("")
                                ForEach(PhotographyCatalog.topics, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu).frame(minHeight: 44)
                        }
                        if surface == "topics" { access }
                        Text("Your photos stay in your library on this iPhone.").font(.footnote)
                        HStack(spacing: 38) {
                            JournalIcon("check", "Save moment") { save(draft: false) }
                            JournalIcon("bookmark", "Save draft") { save(draft: true) }
                        }.frame(maxWidth: .infinity).disabled(images.isEmpty || picking)
                    }.padding(16)
                }.scrollDismissesKeyboard(.interactively)
            }
        }.buttonStyle(.plain).onAppear(perform: load)
            .alert("Leave this moment?", isPresented: $discard) {
                Button("Keep editing", role: .cancel) {}
                Button("Leave", role: .destructive) { app.back() }
            } message: { Text("Choose Keep editing to return and save a draft.") }
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: pick) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(JournalColor.petrol.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .background(PhotographyCatalog.cream.opacity(0.7), in: RoundedRectangle(cornerRadius: 15))
                    if let first = images.first { JournalImage(first).padding(4) }
                    else { PhotographyArt(icon: "camera", size: 64) }
                }.frame(height: 180)
            }.disabled(picking).accessibilityLabel("Choose a little moment. Up to 3 photos")
            HStack(spacing: 10) {
                ForEach(Array(images.enumerated()), id: \.element) { index, path in
                    Button { images.removeAll { $0 == path } } label: {
                        JournalImage(path, mode: .fill).frame(width: 68, height: 68).clipped()
                            .overlay(alignment: .topTrailing) {
                                PhotographyArt(icon: "close", size: 20).background(PhotographyCatalog.cream, in: Circle())
                            }
                    }.accessibilityLabel("Remove photo \(index + 1)")
                }
            }
        }
    }

    private var access: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reader access")
            Picker("Reader access", selection: $paid) { Text("Free").tag(false); Text("Paid").tag(true) }.pickerStyle(.segmented)
            if paid {
                if !category.isEmpty { Text("\(category) category pass: \(app.passPrice(category)) Coins").font(.footnote) }
                Text("Unlock price in coins")
                TextField("Coins", text: $price).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    .onChange(of: price) { value in
                        let digits = String(value.filter { $0.isASCII && $0.isNumber }.prefix(4))
                        if value != digits { price = digits }
                    }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let draftID {
            guard let draft = app.state.rows("moments").first(where: { $0.str("id") == draftID && $0["draft"] as? Bool == true }) else {
                missingDraft = true
                return
            }
            images = draft.strings("images")
            caption = draft.str("caption")
            category = draft.str("topic")
            surface = draft.str("surface") == "topics" ? "topics" : "home"
            let amount = draft.int("coinPrice")
            paid = amount > 0
            price = paid ? String(amount) : "10"
        } else {
            surface = topic == nil ? "home" : "topics"
            category = topic ?? ""
        }
    }

    private func pick() {
        guard !picking else { return }
        picking = true
        Task {
            defer { picking = false }
            do {
                if let selected = try await app.perform("pickPhotos", ["purpose": "moment"]) as? [String], !selected.isEmpty {
                    images = selected
                }
            } catch { app.showError(error) }
        }
    }

    private func save(draft: Bool) {
        guard !images.isEmpty, !picking else { return }
        let amount = paid ? Int(price) : 0
        guard let amount, !paid || (amount > 0 && amount < app.passPrice(category)),
              surface != "topics" || draft || !category.isEmpty else {
            app.message = "Choose a category. A paid work needs a whole coin price below its category pass."
            return
        }
        if app.change("saveMoment", ["id": draftID ?? newID, "caption": caption, "images": images, "topic": category,
                                     "surface": surface, "draft": draft, "coinPrice": amount]) {
            app.meCollection = draft ? "Drafts" : "Moments"
            app.root(.me)
            app.message = draft ? "Draft saved." : "Moment saved to your library."
        }
    }
}
