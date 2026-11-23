import SwiftUI
import SafariServices
import AVFoundation

typealias Record = [String: Any]

extension Dictionary where Key == String, Value == Any {
    func str(_ key: String) -> String { self[key] as? String ?? "" }
    func strings(_ key: String) -> [String] { self[key] as? [String] ?? [] }
    func rows(_ key: String) -> [Record] { self[key] as? [Record] ?? [] }
    func int(_ key: String) -> Int { self[key] as? Int ?? 0 }
}

enum JournalAssets {
    static func url(_ path: String) -> URL? {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count >= 3, components.first == "assets",
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
              let root = Bundle.main.resourceURL else { return nil }
        return root.appendingPathComponent(components.dropFirst().joined(separator: "/"))
    }
}

enum JournalRoute: Hashable {
    case home, topics, shorts(String?, String?), chats, me
    case topic(String, access: String = "All"), photo(String, Bool), collection, member(String)
    case compose(String?, String?), createShort, chat(String), friends
    case wallet, settings, editProfile, credits, blocked, reports, hidden, reportedPosts, reportedComments
}

enum JournalTab: String, CaseIterable {
    case home = "Home", topics = "Topics", shorts = "Shorts", chats = "Chats", me = "Me"

    var icon: String {
        switch self {
        case .chats: return "chat"
        case .me: return "profile"
        default: return rawValue.lowercased()
        }
    }

    var route: JournalRoute {
        switch self {
        case .home: return .home
        case .topics: return .topics
        case .shorts: return .shorts(nil, nil)
        case .chats: return .chats
        case .me: return .me
        }
    }
}

@MainActor
final class JournalStore: ObservableObject {
    private let library = PhotoLibrary()
    private var photoPicker: MediaPicker?
    private var videoPicker: VideoPicker?

    @Published private(set) var state: Record = [:]
    @Published private(set) var wallet: Record = [:]
    private(set) var catalog: Record = [:]
    @Published private(set) var entered = false
    @Published private(set) var loadingError: String?
    @Published var message: String?
    @Published var confirmation: String?
    private weak var noticeView: UIView?
    @Published private(set) var tab = JournalTab.home
    @Published var path: [JournalRoute] = []
    @Published var discovery = PhotographySessionState()
    @Published var chatScope = "Recent"
    @Published var chatQuery = ""
    @Published var chatSearching = false
    @Published var meCollection = "Moments"
    var isRoot: Bool { path.isEmpty }

    var members: [Record] { catalog.rows("authors") }

    var photos: [Record] {
        let profile = state["profile"] as? Record
        let name = profile?.str("name") ?? ""
        let moments = state.rows("moments").filter { $0["draft"] as? Bool == false }.map {
            $0.merging(["editorial": false, "author": name.isEmpty ? "You" : name]) { _, new in new }
        }
        return (moments + catalog.rows("photos")).filter(visible).map { photo in
            guard locked(photo) else { return photo }
            var preview = photo
            preview["images"] = [photo["preview"] as? String ?? "assets/icons/credit-coin.png"]
            return preview
        }
    }

    var shorts: [Record] { (state.rows("shorts") + catalog.rows("shorts")).filter(visible) }

    private func visible(_ work: Record) -> Bool {
        !state.strings("blocked").contains(work.str("authorID"))
            && !["hidden", "reportedPosts", "reports"].contains { state.strings($0).contains(work.str("id")) }
    }

    func locked(_ work: Record) -> Bool {
        work["editorial"] as? Bool == true && work.int("coinPrice") > 0
            && !wallet.strings("unlockedTopics").contains(work.str("id"))
            && !wallet.strings("unlockedCategories").contains(work.str("topic"))
    }

    func comments(_ workID: String) -> [Record] {
        let work = (catalog.rows("photos") + catalog.rows("shorts")).first { $0.str("id") == workID }
        let community = (work?.rows("comments") ?? []).filter {
            !state.strings("blocked").contains($0.str("authorID"))
                && !state.strings("reportedComments").contains($0.str("id"))
        }.map { $0.merging(["postID": workID, "local": false]) { _, new in new } }
        let local = state.rows("comments").filter { $0.str("postID") == workID }.map {
            $0.merging(["authorID": "you", "local": true]) { _, new in new }
        }
        return community + local
    }

    func prepare() {
        do {
            catalog = try CommunityCatalog.load()
            _ = try library.snapshot(reload: true)
            try library.finishPendingCleanup()
            try library.cleanRemovedMedia()
            try? library.removeLegacyMediaCache()
            state = try library.visibleSnapshot()
            loadingError = nil
        } catch { loadingError = error.localizedDescription }
    }

    func login() {
        if state["consent"] as? Bool != true && !change("consent") { return }
        entered = true
        refreshWallet()
    }

    func logout() {
        entered = false
        root(.home)
        meCollection = "Moments"
        discovery = PhotographySessionState()
        chatScope = "Recent"
        chatQuery = ""
        chatSearching = false
    }

    func refreshWallet() {
        guard entered else { return }
        do { wallet = try PurchaseService.shared.snapshot() }
        catch { wallet = [:]; showError(error) }
    }

    func showError(_ error: Error) { message = error.localizedDescription }
    func open(_ route: JournalRoute) { path.append(route) }
    func back() { if !path.isEmpty { path.removeLast() } }
    func root(_ tab: JournalTab) {
        path.removeAll()
        self.tab = tab
    }

    @discardableResult
    func change(_ command: String, _ payload: Record = [:]) -> Bool {
        do {
            guard entered || command == "consent" else { throw roroError("Please log in to continue.") }
            guard photoPicker == nil, videoPicker == nil else { throw roroError("Please finish the current selection.") }
            _ = try library.change(command, payload)
            if command == "clearLibrary" {
                do { try library.finishPendingCleanup() }
                catch { message = "Your library was cleared. Reopen Roro to finish removing its media files." }
            }
            state = try library.visibleSnapshot()
            if command == "setBlock", payload["enabled"] as? Bool == true {
                root(tab)
                confirmation = "User blocked."
            }
            if command == "clearLibrary" { logout() }
            return true
        } catch {
            showError(error)
            return false
        }
    }

    func imageURL(_ path: String) -> URL? {
        if path.hasPrefix("media/") { return try? library.mediaURL(path) }
        return JournalAssets.url(path)
    }

    private func presenter() throws -> UIViewController {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard var controller = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else {
            throw roroError("Please try again after opening your library.")
        }
        while let presented = controller.presentedViewController { controller = presented }
        return controller
    }

    func presentNotice(_ text: String) async {
        guard let window = try? presenter().viewIfLoaded?.window else { return }
        noticeView?.removeFromSuperview()
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics.default.scaledFont(for: UIFont(name: "Kalam-Regular", size: 16) ?? .preferredFont(forTextStyle: .body))
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        let banner = UIView()
        banner.backgroundColor = UIColor(red: 0.09, green: 0.298, blue: 0.271, alpha: 0.96)
        banner.layer.cornerRadius = 10
        banner.isUserInteractionEnabled = false
        banner.addSubview(label)
        window.addSubview(banner)
        banner.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            banner.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, constant: -32),
            banner.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -8)
        ])
        noticeView = banner
        UIAccessibility.post(notification: .announcement, argument: text)
        defer { banner.removeFromSuperview() }
        do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
        if message == text { message = nil }
    }

    // A report can finish inside a confirmation nested in the comments sheet.
    // Present its result from the visible controller once dismissal has settled.
    func presentConfirmation(_ text: String) async {
        while !Task.isCancelled && confirmation == text {
            do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return }
            guard let controller = try? presenter(), controller.viewIfLoaded?.window != nil,
                  controller.transitionCoordinator == nil, !controller.isBeingDismissed,
                  !controller.isBeingPresented, !(controller is UIAlertController) else { continue }
            guard confirmation == text, !Task.isCancelled else { return }
            let alert = UIAlertController(title: "Roro", message: text, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                if self?.confirmation == text { self?.confirmation = nil }
            })
            controller.present(alert, animated: true)
            return
        }
    }

    @discardableResult
    func perform(_ command: String, _ payload: Record = [:]) async throws -> Any {
        guard entered || command == "openAgreement" || command == "snapshot" else {
            throw roroError("Please log in to continue.")
        }
        let id = payload.str("id")
        switch command {
        case "snapshot":
            state = try library.visibleSnapshot(reload: payload["reload"] as? Bool == true)
            return state
        case "wallet", "walletSnapshot", "retryPurchases", "purchase", "unlockTopicWork":
            let service = PurchaseService.shared
            if command == "wallet" {
                wallet = try await withCheckedThrowingContinuation { continuation in
                    service.load { continuation.resume(with: $0) }
                }
            } else if command == "unlockTopicWork" {
                guard let work = catalog.rows("photos").first(where: { $0.str("id") == id }), visible(work) else {
                    throw roroError("This work is hidden.")
                }
                wallet = try service.unlockTopicWork(id, scope: payload.str("scope"), quotedPrice: payload.int("price"))
            } else {
                if command == "purchase" { try service.buy(id) }
                if command == "retryPurchases" { service.retry() }
                wallet = try service.snapshot()
            }
            return wallet
        case "pickPhotos":
            guard photoPicker == nil, videoPicker == nil else { throw roroError("Please finish the current selection.") }
            let controller = try presenter()
            let picker = MediaPicker(library: library, forAvatar: payload.str("purpose") == "avatar")
            photoPicker = picker
            defer { photoPicker = nil }
            let images: [String] = try await withCheckedThrowingContinuation { continuation in
                picker.present(from: controller) { continuation.resume(with: $0) }
            }
            return images
        case "pickVideo":
            guard photoPicker == nil, videoPicker == nil else { throw roroError("Please finish the current selection.") }
            let controller = try presenter()
            let picker = VideoPicker(library: library)
            videoPicker = picker
            defer { videoPicker = nil }
            let video: Record? = try await withCheckedThrowingContinuation { continuation in
                picker.present(from: controller) { continuation.resume(with: $0) }
            }
            return video as Any? ?? NSNull()
        case "discardVideo":
            try library.discardVideo(payload.str("video"))
        case "videoSource":
            guard let clip = shorts.first(where: { $0.str("id") == id }) else { throw roroError("This short is unavailable.") }
            if let path = try CommunityCatalog.video(id), let url = JournalAssets.url(path),
               FileManager.default.fileExists(atPath: url.path) { return url }
            return try library.mediaURL(clip.str("video"))
        case "playVideo":
            let controller = try presenter()
            let url = try library.mediaURL(payload.str("video"))
            guard url.pathExtension == "mp4", !(controller is ShortPlayerController) else { throw roroError("This video could not be opened.") }
            let preview = ShortPlayerController()
            preview.player = AVPlayer(url: url)
            preview.modalPresentationStyle = .fullScreen
            controller.present(preview, animated: true) { preview.player?.play() }
        case "openCallPreview":
            let peer = payload.str("peerID"), mode = payload.str("mode")
            let controller = try presenter()
            guard ["voice", "video"].contains(mode), !(controller is CallPreviewController),
                  PhotoLibrary.messagingPeers(try library.snapshot()).contains(peer),
                  let member = members.first(where: { $0.str("id") == peer }),
                  let portrait = JournalAssets.url(member.str("avatar")) else { throw roroError("Call preview unavailable.") }
            controller.present(CallPreviewController(video: mode == "video", name: member.str("name"), portrait: portrait), animated: true)
        case "openSource":
            guard let clip = catalog.rows("shorts").first(where: { $0.str("id") == id }),
                  !state.strings("blocked").contains(clip.str("authorID")), !state.strings("reports").contains(id),
                  let url = URL(string: clip.str("sourceURL")),
                  url.scheme == "https", url.host == "www.pexels.com" else { throw roroError("This source could not be opened.") }
            try presenter().present(SFSafariViewController(url: url), animated: true)
        case "openAgreement":
            let kind = payload.str("kind")
            guard ["privacy", "terms"].contains(kind),
                  let file = Bundle.main.url(forResource: "agreements", withExtension: "json", subdirectory: "Configuration"),
                  let values = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: String],
                  let link = values[kind], let url = URL(string: link), url.scheme == "https", url.host == "docs.google.com" else {
                throw roroError("This agreement could not be opened.")
            }
            try presenter().present(SFSafariViewController(url: url), animated: true)
        case "sharePhoto":
            let path = payload.str("image")
            guard let url = imageURL(path), (photos + shorts).contains(where: {
                !locked($0) && ($0.strings("images").contains(path) || $0["video"] as? String == path)
            }) else { throw roroError("This media file could not be shared.") }
            let controller = try presenter()
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.popoverPresentationController?.sourceView = controller.view
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                share.completionWithItemsHandler = { _, _, _, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
                controller.present(share, animated: true)
            }
        default: throw roroError("This action is unavailable.")
        }
        return NSNull()
    }
}
