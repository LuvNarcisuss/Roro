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

enum JournalRoute: Hashable {
    case home, topics, shorts(String?, String?), chats, me
    case topic(String, access: String = "All"), photo(String, Bool), collection, member(String)
    case compose(String?, String?), createShort, chat(String), friends
    case wallet, settings, editProfile, credits, blocked, reports, hidden, reportedPosts, reportedComments, reportedAuthors
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
    private var library = PhotoLibrary()
    private let authentication = JournalAuthentication()
    private var session: JournalAuthentication.Session?
    private var renewal: Task<Void, Never>?
    private var expiresAt = Date.distantPast
    @Published private(set) var authenticating = false
    @Published private(set) var catalogReady = false
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
    private var confirmationWindow: UIWindow?
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
        let parent = work ?? (state.rows("moments") + state.rows("shorts")).first { $0.str("id") == workID }
        guard let parent, visible(parent) else { return [] }
        let community = (work?.rows("comments") ?? []).filter {
            !state.strings("blocked").contains($0.str("authorID"))
                && !state.strings("reportedComments").contains($0.str("id"))
        }.map { $0.merging(["postID": workID, "local": false]) { _, new in new } }
        let local = state.rows("comments").filter { $0.str("postID") == workID }.map {
            $0.merging(["authorID": "you", "local": true]) { _, new in new }
        }
        return community + local
    }

    func prepare() async {
        if !catalogReady, let initial = try? CommunityCatalog.load() { catalog = initial; catalogReady = true }

        do {
            _ = try await JournalAssets.fetch("assets/community/catalog.json")
            catalog = try CommunityCatalog.load()
            catalogReady = true
            loadingError = nil
        } catch { loadingError = error.localizedDescription }
    }

    func login(email: String, password: String, consent: Bool) async throws {
        guard consent, !authenticating, !entered else { return }
        authenticating = true
        defer { authenticating = false }
        let verified = try await authentication.signIn(email: email, password: password)
        do {
            let directory = try PhotoLibrary.directory(for: verified.user.id)
            library = PhotoLibrary(directory: directory)
            _ = try library.snapshot(reload: true)
            try library.finishPendingCleanup()
            try library.cleanRemovedMedia()
            try? library.removeLegacyMediaCache()
            if try library.snapshot()["consent"] as? Bool != true { _ = try library.change("consent", [:]) }
            state = try library.visibleSnapshot()
            PurchaseService.shared.signedInUser = verified.user.id
            startSession(verified)
            entered = true
            refreshWallet()
        } catch {
            state = [:]
            Task { try? await authentication.signOut(verified) }
            throw error
        }
    }

    private func startSession(_ verified: JournalAuthentication.Session) {
        session = verified
        expiresAt = Date().addingTimeInterval(verified.expires_in)
        renewal = Task {
            do {
                let delay = max(1, verified.expires_in - min(60, verified.expires_in / 2))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                let renewed = try await authentication.refresh(verified)
                guard !Task.isCancelled, session?.access_token == verified.access_token else { return }
                startSession(renewed)
            } catch {
                guard !Task.isCancelled, session?.access_token == verified.access_token else { return }
                let remaining = max(0, expiresAt.timeIntervalSinceNow)
                try? await Task.sleep(nanoseconds: UInt64(min(remaining, verified.expires_in) * 1_000_000_000))
                guard !Task.isCancelled, session?.access_token == verified.access_token else { return }
                logout()
            }
        }
    }

    func checkSessionExpiry() {
        if entered && Date() >= expiresAt { logout() }
    }

    func logout() {
        renewal?.cancel()
        renewal = nil
        if let session { Task { try? await authentication.signOut(session) } }
        session = nil
        entered = false
        PurchaseService.shared.signedInUser = nil
        state = [:]
        wallet = [:]
        message = nil
        confirmation = nil
        confirmationWindow?.isHidden = true
        confirmationWindow = nil
        library = PhotoLibrary()
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
            guard entered else { throw roroError("Please log in to continue.") }
            guard photoPicker == nil, videoPicker == nil else { throw roroError("Please finish the current selection.") }
            let wasBlocked = state.strings("blocked").contains(payload.str("id"))
            _ = try library.change(command, payload)
            if command == "clearLibrary" {
                do { try library.finishPendingCleanup() }
                catch { message = "Your library was cleared. Reopen Roro to finish removing its media files." }
            }
            state = try library.visibleSnapshot()
            if ["setBlock", "toggleBlock"].contains(command), !wasBlocked, state.strings("blocked").contains(payload.str("id")) {
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

    func assetFile(_ path: String) async throws -> URL {
        if path.hasPrefix("media/") {
            guard entered else { throw roroError("Please log in to view this media.") }
            return try library.mediaURL(path)
        }
        let identity = session?.user.id
        let file = try await JournalAssets.fetch(path, token: session?.access_token)
        guard identity == session?.user.id else { throw CancellationError() }
        return file
    }

    func imageURL(_ path: String) -> URL? {
        if path.hasPrefix("media/") { return entered ? try? library.mediaURL(path) : nil }
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

    // Removing reported content can tear down the sheet that initiated the action.
    // Keep the acknowledgement alive until the user dismisses it.
    func presentConfirmation(_ text: String) async {
        while !Task.isCancelled && confirmation == text {
            do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return }
            guard let controller = try? presenter(), controller.viewIfLoaded?.window != nil,
                  controller.transitionCoordinator == nil, !controller.isBeingDismissed,
                  !controller.isBeingPresented, !(controller is UIAlertController) else { continue }
            guard confirmation == text, !Task.isCancelled else { return }
            if text == "User blocked.", !isRoot || controller.presentingViewController != nil { continue }
            guard confirmationWindow == nil, let previous = controller.view.window,
                  let scene = previous.windowScene else { return }
            let window = UIWindow(windowScene: scene)
            let host = UIViewController()
            host.view.backgroundColor = .clear
            window.backgroundColor = .clear
            window.rootViewController = host
            window.windowLevel = .alert + 1
            confirmationWindow = window
            window.makeKeyAndVisible()
            let alert = UIAlertController(title: "Roro", message: text, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak previous] _ in
                self?.confirmationWindow?.isHidden = true
                self?.confirmationWindow = nil
                previous?.makeKey()
                if self?.confirmation == text { self?.confirmation = nil }
            })
            host.present(alert, animated: true)
            return
        }
    }

    @discardableResult
    func perform(_ command: String, _ payload: Record = [:]) async throws -> Any {
        guard entered || command == "openAgreement" else {
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
                let requester = session?.user.id
                let result: Record = try await withCheckedThrowingContinuation { continuation in
                    service.load { continuation.resume(with: $0) }
                }
                guard entered, session?.user.id == requester else { throw CancellationError() }
                wallet = result
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
            if let path = try CommunityCatalog.video(id) {
                let file = try await assetFile(path)
                guard shorts.contains(where: { $0.str("id") == id }) else { throw roroError("This short is unavailable.") }
                return file
            }
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
                  let member = members.first(where: { $0.str("id") == peer }) else { throw roroError("Call preview unavailable.") }
            let portrait = try await assetFile(member.str("avatar"))
            for icon in ["sound", "call-hangup", "call-speaker-off", "call-microphone", "call-microphone-off"] {
                _ = try await assetFile("assets/icons/" + icon + ".png")
            }
            guard entered, PhotoLibrary.messagingPeers(try library.snapshot()).contains(peer) else {
                throw roroError("Call preview unavailable.")
            }
            controller.present(CallPreviewController(video: mode == "video", name: member.str("name"), portrait: portrait), animated: true)
        case "openSource":
            guard let clip = shorts.first(where: { $0.str("id") == id }),
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
            func canShare() -> Bool {
                (photos + shorts).contains {
                    !locked($0) && ($0.strings("images").contains(path) || $0["video"] as? String == path)
                }
            }
            guard canShare() else { throw roroError("This media file could not be shared.") }
            let url = try await assetFile(path)
            guard canShare() else { throw roroError("This media file could not be shared.") }
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
