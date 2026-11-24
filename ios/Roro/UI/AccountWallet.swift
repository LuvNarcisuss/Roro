import SwiftUI

func accountCoinBalance(_ wallet: Record) -> String {
    guard let balance = wallet["balance"] as? Int else { return "— Coins" }
    return balance.formatted() + (balance == 1 ? " Coin" : " Coins")
}

struct AccountWallet: View {
    @EnvironmentObject var app: JournalStore
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var dynamicSize
    @State private var loading = false
    @State private var purchasing = false
    @State private var errorText = ""
    @State private var selection: String?

    private var checkoutBlocked: Bool { app.wallet["checkoutBlocked"] as? Bool == true }
    private var pricesAvailable: Bool {
        !loading && errorText.isEmpty && ["ready", "partial"].contains(app.wallet.str("status"))
    }

    var body: some View {
        VStack(spacing: 0) {
            JournalHeader("Wallet")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack {
                        Text("Your balance")
                        HStack {
                            AccountGlyph(name: "credit-coin", size: 36).accessibilityHidden(true)
                            Text(app.wallet["balance"] == nil ? "—" : app.wallet.int("balance").formatted())
                                .font(.custom("Kalam-Bold", size: 34, relativeTo: .largeTitle))
                        }
                        Text(app.wallet.int("balance") == 1 ? "Coin" : "Coins")
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(JournalColor.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                    AccountHeading(text: "Buy coins")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicSize.isAccessibilitySize ? 2 : 3), spacing: 8) {
                        ForEach(app.wallet.rows("products"), id: \.accountID) { product in offer(product) }
                    }
                    if !status.isEmpty { Text(status).foregroundColor(.secondary) }
                    if pricesAvailable, let selected = app.wallet.rows("products").first(where: { $0.accountID == selection }),
                       !selected.str("price").isEmpty {
                        HStack {
                            Text("Purchase · " + selected.str("price"))
                            Spacer()
                            JournalIcon("wallet", "Buy " + selected.int("credits").formatted() + " coins for " + selected.str("price")) {
                                buy(selected.accountID)
                            }.disabled(checkoutBlocked || purchasing)
                        }
                    }
                    if app.wallet["canRetry"] as? Bool == true {
                        Text("Pending purchase").font(.custom("Kalam-Bold", size: 17))
                        Text("Pull down to check again.").foregroundColor(.secondary)
                    }
                    if !app.wallet.str("notice").isEmpty { Text(app.wallet.str("notice")).foregroundColor(.secondary) }
                    AccountHeading(text: "Wallet activity")
                    if !app.wallet.isEmpty && app.wallet.rows("activity").isEmpty {
                        Text("No wallet activity yet.").foregroundColor(.secondary)
                    }
                    ForEach(app.wallet.rows("activity"), id: \.accountID) { activity in
                        HStack {
                            VStack(alignment: .leading) {
                                if !activity.str("label").isEmpty { Text(activity.str("label")) }
                                AccountDate(iso: activity.str("date"), history: true)
                            }
                            Spacer()
                            let credits = activity.int("credits")
                            Text((credits > 0 ? "+" : "") + credits.formatted() + (abs(credits) == 1 ? " coin" : " coins"))
                        }
                        Divider()
                    }
                }.padding(20)
            }
            .refreshable { await refresh(retry: true) }
        }
        .task { await refresh(retry: false) }
        .task(id: phase) {
            guard phase == .active else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
                do { _ = try await app.perform("walletSnapshot") }
                catch { errorText = error.localizedDescription; return }
            }
        }
    }

    private var status: String {
        if !errorText.isEmpty { return errorText }
        if loading { return "Loading prices…" }
        switch app.wallet.str("status") {
        case "ready": return ""
        case "partial": return "Some offers are unavailable. Pull down to check again."
        case "unavailable": return "Offers are unavailable. Pull down to check again."
        case "failed": return "Prices could not be loaded. Pull down to try again."
        default: return "Loading prices…"
        }
    }

    private func offer(_ product: Record) -> some View {
        let price = pricesAvailable ? product.str("price") : ""
        let selected = selection == product.accountID && !price.isEmpty
        let credits = product.int("credits")
        return Button {
            selection = product.accountID
        } label: {
            VStack(spacing: 1) {
                AccountGlyph(name: "credit-coin", size: 32)
                Text(credits.formatted()).font(.custom("Kalam-Bold", size: 18))
                Text(credits == 1 ? "Coin" : "Coins")
                Text(price.isEmpty ? (loading ? "—" : "Unavailable") : price)
            }
            .frame(maxWidth: .infinity, minHeight: 105)
            .background(JournalColor.paper.opacity(selected ? 1 : 0.65), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? JournalColor.accent : JournalColor.ink.opacity(0.25), lineWidth: selected ? 2 : 1))
            .overlay(alignment: .topTrailing) { if selected { AccountGlyph(name: "check", size: 19).padding(3) } }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(credits.formatted() + (credits == 1 ? " coin, " : " coins, ") + (price.isEmpty ? (loading ? "loading price" : "unavailable") : price))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .disabled(price.isEmpty || checkoutBlocked || purchasing)
    }

    @MainActor private func refresh(retry: Bool) async {
        guard !loading, !purchasing else { return }
        loading = true
        errorText = ""
        defer { loading = false }
        do {
            if retry, app.wallet["canRetry"] as? Bool == true { _ = try await app.perform("retryPurchases") }
            _ = try await app.perform("wallet")
        } catch { errorText = error.localizedDescription }
    }

    private func buy(_ id: String) {
        guard !purchasing, !loading, !checkoutBlocked else { return }
        purchasing = true
        Task {
            defer { purchasing = false }
            do { _ = try await app.perform("purchase", ["id": id]) }
            catch { app.showError(error) }
            app.refreshWallet()
        }
    }
}

enum AccountSafetyKind: String {
    case blocked, video = "reports", post = "reportedPosts", comment = "reportedComments", author = "reportedAuthors"

    var title: String {
        switch self {
        case .blocked: return "Blocked people"
        case .video: return "Reported videos"
        case .post: return "Reported posts"
        case .comment: return "Reported comments"
        case .author: return "Reported authors"
        }
    }
}

struct AccountSafety: View {
    @EnvironmentObject var app: JournalStore
    let kind: AccountSafetyKind
    @State private var pending: SafetyAction?

    private struct SafetyAction: Identifiable {
        let id: String
        let prompt: String
    }

    private var records: [String] { app.state.strings(kind.rawValue) }

    private func label(for id: String) -> String {
        switch kind {
        case .blocked, .author:
            return app.members.first { $0.accountID == id }?.str("name") ?? "Community member"
        case .video, .post:
            let works = app.catalog.rows(kind == .video ? "shorts" : "photos")
            return works.first { $0.accountID == id }?.str("caption") ?? (kind == .video ? "Community video" : "Community post")
        case .comment:
            let works = app.catalog.rows("photos") + app.catalog.rows("shorts")
            for work in works {
                if let comment = work.rows("comments").first(where: { $0.accountID == id }) {
                    let name = app.members.first { $0.accountID == comment.str("authorID") }?.str("name") ?? "Community member"
                    return name + " — " + comment.str("text")
                }
            }
            return "Community comment"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            JournalHeader(kind.title)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if records.isEmpty { AccountEmpty(title: "No " + kind.title.lowercased()) }
                    ForEach(records, id: \.self) { id in
                        safetyRow(id)
                        Divider()
                    }
                }.padding(20)
            }.refreshable { await app.accountRefresh() }
        }
        .alert(item: $pending) { action in
            Alert(title: Text(action.prompt + "?"), primaryButton: .default(Text(kind == .blocked ? "Unblock" : "Withdraw")) {
                if kind == .blocked {
                    _ = app.change("setBlock", ["id": action.id, "enabled": false])
                } else {
                    var payload: Record = ["id": action.id, "enabled": false]
                    if kind == .post { payload["kind"] = "post" }
                    if kind == .comment { payload["kind"] = "comment" }
                    if kind == .author { payload["kind"] = "author" }
                    _ = app.change("setReport", payload)
                }
            }, secondaryButton: .cancel())
        }
    }

    private func safetyRow(_ id: String) -> some View {
        let name = label(for: id)
        let action = SafetyAction(id: id, prompt: (kind == .blocked ? "Unblock " : "Withdraw report for ") + name)
        return HStack {
            if kind == .blocked {
                Button { app.open(.member(id)) } label: {
                    Text(name).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain)
            } else { Text(name); Spacer() }
            JournalIcon(kind == .blocked ? "block" : "close", action.prompt) { pending = action }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.6) { pending = action }
        .accessibilityAction(named: Text(action.prompt)) { pending = action }
    }
}

struct AccountCredits: View {
    @EnvironmentObject var app: JournalStore
    @State private var photographs: [Record] = []

    private func loadCredits() async {
        guard let file = try? await app.assetFile("assets/photos/manifest.json"), let data = try? Data(contentsOf: file),
              let values = try? JSONSerialization.jsonObject(with: data) as? [Record] else { return }
        photographs = values.filter { $0.str("license") == "Pexels License" }
    }

    var body: some View {
        VStack(spacing: 0) {
            JournalHeader("Artwork & credits")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    AccountHeading(text: "Everyday inspiration")
                    Text("Home features photography from Unsplash and Pexels. Topic photographs, editorial covers and member avatars are licensed from Pexels. These images are editorial material. Photo subjects are not presented as Roro members.")
                    Text("Source URLs, file hashes and license information are included in the app’s asset manifest.")
                    Text("The prohibited emoji is from Twemoji by Twitter, Inc. and other contributors, licensed under CC BY 4.0.")
                    AccountHeading(text: "Pexels photography")
                    ForEach(photographs, id: \.accountID) { photo in
                        Text(photo.str("title") + " · " + photo.str("author"))
                    }
                    AccountHeading(text: "Shorts sources")
                    Text("Videos are licensed from Pexels. Community profiles are locally curated fictional personas. Source creators and people in the footage are not represented as Roro members.")
                    ForEach(app.catalog.rows("shorts"), id: \.accountID) { clip in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(clip.str("sourceAuthor")).font(.custom("Kalam-Bold", size: 17))
                                Text("Pexels License")
                            }
                            Spacer()
                            JournalIcon("share", "View original video") {
                                Task { await app.accountPerform("openSource", ["id": clip.accountID]) }
                            }
                        }
                        Divider()
                    }
                    Text("Typography — Kalam and Courgette, SIL Open Font License 1.1.")
                    Text("Interface artwork — original images generated for Roro.")
                    Text("Your imported photographs and videos remain yours.")
                }.padding(20)
            }.task { await loadCredits() }.refreshable { await loadCredits(); await app.accountRefresh() }
        }
    }
}
