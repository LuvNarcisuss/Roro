import SwiftUI

struct PhotographyRow: Identifiable {
    let value: Record
    var id: String { value.str("id") }
    init(_ value: Record) { self.value = value }
}

enum PhotographyCatalog {
    static let topics = ["Little joys", "On my walk", "At home", "Today's sky", "Something delicious"]
    static let prompts = [
        "Little joys": "What made you smile today?",
        "On my walk": "What caught your eye along the way?",
        "At home": "Which corner feels most like you?",
        "Today's sky": "What color is the sky right now?",
        "Something delicious": "What was worth a photo before the first bite?"
    ]
    static let descriptions = [
        "Little joys": "The small things that made you smile.",
        "On my walk": "Take the long way. Notice a little more.",
        "At home": "A favorite corner, a familiar kind of comfort.",
        "Today's sky": "Look up. There is always something new.",
        "Something delicious": "Something good, before the first bite."
    ]
    static let cream = Color(red: 1, green: 0.956, blue: 0.882)
    static let columns = [GridItem(.flexible(minimum: 0), spacing: 10, alignment: .top), GridItem(.flexible(minimum: 0), alignment: .top)]
    static func rotate<T>(_ values: [T], by turn: Int) -> [T] {
        guard values.count > 1 else { return values }
        let offset = turn % values.count
        return Array(values[offset...]) + Array(values[..<offset])
    }
    static func shortDate(_ value: String) -> String {
        let source = ISO8601DateFormatter()
        guard let date = source.date(from: value) else { return String(value.prefix(10)) }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US")
        format.setLocalizedDateFormatFromTemplate("MMMd")
        return format.string(from: date)
    }
}

extension JournalStore {
    func photographyMember(_ id: String) -> Record {
        if id.isEmpty || id == "you" {
            var profile = state["profile"] as? Record ?? [:]
            if profile.str("name").isEmpty { profile["name"] = "You" }
            return profile
        }
        return members.first { $0.str("id") == id } ?? ["id": id, "name": "Community member"]
    }

    func openPhotographyProfile(_ id: String) {
        open(id.isEmpty || id == "you" ? .me : .member(id))
    }

    func photoCount(_ key: String, _ work: Record) -> Int {
        work.int(key) + (state.strings(key).contains(work.str("id")) ? 1 : 0)
    }

    func passPrice(_ topic: String) -> Int {
        (catalog["categoryPrices"] as? Record)?.int(topic) ?? 0
    }

    func photographyRefresh() async -> Bool {
        do {
            _ = try await perform("snapshot", ["reload": true])
            return true
        } catch {
            showError(error)
            return false
        }
    }

    func sharePhotographyMedia(_ path: String) {
        Task {
            do { _ = try await perform("sharePhoto", ["image": path]) }
            catch { showError(error) }
        }
    }
}

struct PhotographyTitle: View {
    let title: String
    var size: CGFloat = 23

    var body: some View {
        Text(title).font(.custom("Courgette-Regular", size: size, relativeTo: .title2))
            .foregroundStyle(JournalColor.petrol).accessibilityAddTraits(.isHeader)
    }
}

struct PhotographyArt: View {
    let icon: String
    var size: CGFloat = 28
    var body: some View {
        JournalImage("assets/icons/\(icon).png").frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct PhotographyCrop: View {
    let path: String
    var ratio: CGFloat = 0.8
    var body: some View {
        Color.clear.aspectRatio(ratio, contentMode: .fit)
            .overlay { JournalImage(path, mode: .fill) }
            .clipped()
    }
}

struct PhotographyPortrait: View {
    let profile: Record
    var size: CGFloat = 32
    var body: some View {
        let path = profile.str("avatar")
        Group {
            if path.isEmpty {
                Text(String(profile.str("name").prefix(1)).uppercased())
                    .font(.custom("Courgette-Regular", size: size * 0.5))
                    .foregroundStyle(JournalColor.petrol)
            } else { JournalImage(path, mode: .fill) }
        }.frame(width: size, height: size)
            .background(PhotographyCatalog.cream).clipShape(Circle())
            .overlay(Circle().stroke(JournalColor.petrol.opacity(0.3), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

struct PhotographyAuthor: View {
    @EnvironmentObject private var app: JournalStore
    let id: String
    var body: some View {
        let member = app.photographyMember(id)
        Button {
            app.openPhotographyProfile(id)
        } label: {
            HStack(spacing: 5) {
                PhotographyPortrait(profile: member, size: 28)
                Text(member.str("name")).font(.custom("Kalam-Regular", size: 15, relativeTo: .subheadline))
                    .multilineTextAlignment(.leading)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityLabel("Open \(member.str("name"))'s profile")
    }
}

struct PhotographyLabeledAction: View {
    let icon: String
    let label: String
    var below = false
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if below {
                    VStack(spacing: 4) { artwork; Text(label).font(.footnote) }
                } else {
                    HStack(spacing: 5) { artwork; Text(label) }
                }
            }.frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 3).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var artwork: some View {
        PhotographyArt(icon: icon, size: icon == "block" ? 24 : 28)
            .frame(width: 28, height: 28)
    }
}

struct PhotographyCountAction: View {
    let icon: String
    let label: String
    var count: Int? = nil
    var selected = false
    let action: () -> Void
    // Match the visible ink height across artwork with different transparent margins.
    private var artworkSize: CGFloat {
        switch icon {
        case "heart", "heart-outline": return 27.5
        case "share": return 29.5
        default: return 25
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                PhotographyArt(icon: icon, size: artworkSize)
                    .frame(height: 25)
                if let count {
                    Text("\(count)").font(.custom("Kalam-Regular", size: 13, relativeTo: .caption))
                }
            }.frame(minWidth: 44, minHeight: 44, alignment: .top).contentShape(Rectangle())
        }.accessibilityLabel(label).accessibilityValue(count.map { String($0) } ?? "")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PhotographyReaction: View {
    @EnvironmentObject private var app: JournalStore
    let work: Record
    let like: Bool
    var body: some View {
        let key = like ? "likes" : "saves"
        let selected = app.state.strings(key).contains(work.str("id"))
        let noun = work.str("poster").isEmpty ? "photo" : "short"
        let icon = like ? "heart" : "bookmark"
        PhotographyCountAction(icon: selected ? icon : "\(icon)-outline", label: "\(like ? "Like" : "Save") \(noun)",
                               count: app.photoCount(key, work), selected: selected) {
            _ = app.change(like ? "toggleLike" : "toggleSave", ["id": work.str("id")])
        }
    }
}

struct PhotographySearch: View {
    @Binding var visible: Bool
    @Binding var query: String
    let label: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            if visible {
                TextField(label, text: $query)
                    .textFieldStyle(.roundedBorder).focused($focused).submitLabel(.search)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .onSubmit { focused = false }.accessibilityLabel(label)
            }
            JournalIcon(visible ? "close" : "search", visible ? "Close search" : label) {
                if visible { focused = false; query = ""; visible = false }
                else {
                    visible = true
                    DispatchQueue.main.async { focused = true }
                }
            }
        }
    }
}

struct PhotographyGrid: View {
    @EnvironmentObject private var app: JournalStore
    let works: [Record]
    var collection = false

    var body: some View {
        LazyVGrid(columns: PhotographyCatalog.columns, spacing: 10) {
            ForEach(works.map(PhotographyRow.init)) { row in
                let work = row.value
                let video = !work.str("poster").isEmpty
                Button {
                    app.open(video ? .shorts(row.id, nil) : .photo(row.id, false))
                } label: {
                    PhotographyCrop(path: video ? work.str("poster") : work.strings("images").first ?? "", ratio: collection || video ? 0.75 : 4 / 4.6)
                        .overlay(alignment: .bottomTrailing) {
                            if video || collection {
                                PhotographyArt(icon: video ? "shorts" : "topics", size: 24)
                                    .padding(2).background(PhotographyCatalog.cream, in: Circle()).padding(4)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }.accessibilityLabel("\(video ? "Play" : "View") \(work.str("caption").isEmpty ? (video ? "short" : "moment") : work.str("caption"))")
            }
        }.buttonStyle(.plain)
    }
}

struct PhotographyMomentsGrid: View {
    @EnvironmentObject private var app: JournalStore
    let works: [Record]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 5), count: 3), spacing: 5) {
            ForEach(works.map(PhotographyRow.init)) { row in
                Button { app.open(.photo(row.id, false)) } label: {
                    PhotographyCrop(path: row.value.strings("images").first ?? "", ratio: 1)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }.accessibilityLabel(row.value.str("caption").isEmpty ? "Your moment" : row.value.str("caption"))
            }
        }.buttonStyle(.plain)
    }
}
