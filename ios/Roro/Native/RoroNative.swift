import Foundation
import UIKit
import React
import SafariServices
import AVFoundation

@objc(RoroNative)
final class RoroNative: NSObject {
    private let library = PhotoLibrary()
    private var pages: URL?
    private var picker: MediaPicker?
    private var videoPicker: VideoPicker?
    @objc static func requiresMainQueueSetup() -> Bool { true }
    @objc var methodQueue: DispatchQueue { .main }

    @objc func prepare(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        do {
            let root = try PageArchive().prepare()
            _ = try library.snapshot()
            try library.finishPendingCleanup(pages: root)
            try library.cleanRemovedMedia(pages: root)
            try library.exportMedia(to: root)
            pages = root
            _ = PurchaseService.shared
            resolve(["uri": root.appendingPathComponent("index.html").absoluteString, "directory": root.absoluteString])
        } catch { reject("OPEN_FAILED", error.localizedDescription, error) }
    }

    @objc func execute(_ command: String, payload: [String: Any], resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        do {
            guard let pages else { throw roroError("Please reopen your photo library.") }
            if !["snapshot", "consent", "openAgreement"].contains(command), try library.snapshot()["consent"] as? Bool != true {
                throw roroError("Please accept the agreements to continue.")
            }
            if ["videoSource", "sharePhoto", "openSource", "unlockTopicWork"].contains(command) {
                let snapshot = try library.snapshot()
                let blocked = Set(snapshot["blocked"] as? [String] ?? [])
                let works = try CommunityCatalog.records("photos") + CommunityCatalog.records("shorts")
                let match = works.first { record in
                    if command != "sharePhoto", let id = payload["id"] as? String { return record["id"] as? String == id }
                    guard let path = payload["image"] as? String else { return false }
                    return record["video"] as? String == path || (record["images"] as? [String] ?? []).contains(path)
                }
                if let id = match?["id"] as? String, (snapshot["reports"] as? [String] ?? []).contains(id) {
                    throw roroError("This video is hidden.")
                }
                if let id = match?["id"] as? String, (snapshot["reportedPosts"] as? [String] ?? []).contains(id) {
                    throw roroError("This post is hidden.")
                }
                if command == "unlockTopicWork", let id = match?["id"] as? String,
                   (snapshot["hidden"] as? [String] ?? []).contains(id) { throw roroError("This work is hidden.") }
                if command == "sharePhoto", let price = match?["coinPrice"] as? Int, price > 0,
                   let id = match?["id"] as? String {
                    let wallet = try PurchaseService.shared.snapshot()
                    let category = match?["topic"] as? String ?? ""
                    guard (wallet["unlockedTopics"] as? [String] ?? []).contains(id) ||
                          (wallet["unlockedCategories"] as? [String] ?? []).contains(category) else { throw roroError("Unlock this work before sharing it.") }
                }
                if let author = match?["authorID"] as? String, blocked.contains(author) {
                    throw roroError("Unblock this person before opening their work.")
                }
            }
            switch command {
            case "snapshot": resolve(try library.visibleSnapshot(reload: payload["reload"] as? Bool == true))
            case "openCallPreview":
                guard let peer = payload["peerID"] as? String, let mode = payload["mode"] as? String,
                      ["voice", "video"].contains(mode), PhotoLibrary.messagingPeers(try library.snapshot()).contains(peer),
                      let member = try CommunityCatalog.records("authors").first(where: { $0["id"] as? String == peer }),
                      let name = member["name"] as? String, let avatar = member["avatar"] as? String,
                      picker == nil, videoPicker == nil, let controller = presenter(),
                      !(controller is CallPreviewController), !controller.isBeingDismissed else {
                    throw roroError("Call preview unavailable.")
                }
                let preview = CallPreviewController(video: mode == "video", name: name, portrait: pages.appendingPathComponent(avatar), pages: pages)
                controller.present(preview, animated: true)
                resolve(NSNull())
            case "pickPhotos":
                guard picker == nil, videoPicker == nil, let controller = presenter() else { throw roroError("Please finish the current photo selection.") }
                _ = try library.snapshot()
                let picker = MediaPicker(library: library, pages: pages, forAvatar: payload["purpose"] as? String == "avatar")
                self.picker = picker
                picker.present(from: controller) { result in
                    self.picker = nil
                    switch result { case .success(let images): resolve(images); case .failure(let error): reject("PHOTO_FAILED", error.localizedDescription, error) }
                }
            case "pickVideo":
                guard picker == nil, videoPicker == nil, let controller = presenter() else { throw roroError("Please finish the current media selection.") }
                let picker = VideoPicker(library: library, pages: pages)
                videoPicker = picker
                picker.present(from: controller) { result in
                    self.videoPicker = nil
                    switch result {
                    case .success(let video): resolve(video as Any? ?? NSNull())
                    case .failure(let error): reject("VIDEO_FAILED", error.localizedDescription, error)
                    }
                }
            case "discardVideo":
                guard let video = payload["video"] as? String, picker == nil, videoPicker == nil else { throw roroError("Please finish choosing your video.") }
                try library.discardVideo(video, pages: pages)
                resolve(NSNull())
            case "videoSource":
                if let id = payload["id"] as? String, let bundled = try CommunityCatalog.video(id) {
                    guard FileManager.default.fileExists(atPath: pages.appendingPathComponent(bundled).path) else { throw roroError("This short is unavailable.") }
                    resolve(bundled)
                    return
                }
                guard let id = payload["id"] as? String,
                      let clips = try library.snapshot()["shorts"] as? [[String: Any]],
                      let clip = clips.first(where: { $0["id"] as? String == id }),
                      let video = clip["video"] as? String, video.hasSuffix(".mp4") else { throw roroError("This short is unavailable.") }
                let source = try library.mediaURL(video)
                let destination = pages.appendingPathComponent(video)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    let temporary = destination.appendingPathExtension("partial")
                    defer { try? FileManager.default.removeItem(at: temporary) }
                    try FileManager.default.copyItem(at: source, to: temporary)
                    try FileManager.default.moveItem(at: temporary, to: destination)
                }
                resolve(video)
            case "playVideo":
                guard let video = payload["video"] as? String, video.hasSuffix(".mp4"), let controller = presenter(), !(controller is ShortPlayerController) else { throw roroError("This video could not be opened.") }
                let player = ShortPlayerController()
                player.player = AVPlayer(url: try library.mediaURL(video))
                player.modalPresentationStyle = .fullScreen
                controller.present(player, animated: true) { player.player?.play() }
                resolve(NSNull())
            case "openSource":
                guard let id = payload["id"] as? String,
                      let record = try CommunityCatalog.records("shorts").first(where: { $0["id"] as? String == id }),
                      let link = record["sourceURL"] as? String, let url = URL(string: link),
                      url.scheme == "https", url.host == "www.pexels.com", let controller = presenter() else { throw roroError("This source could not be opened.") }
                controller.present(SFSafariViewController(url: url), animated: true)
                resolve(NSNull())
            case "openAgreement":
                guard let kind = payload["kind"] as? String, ["terms", "privacy"].contains(kind),
                      let file = Bundle.main.url(forResource: "agreements", withExtension: "json", subdirectory: "AppResources"),
                      let values = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: String],
                      let link = values[kind], let url = URL(string: link), url.scheme == "https", url.host == "docs.google.com",
                      let controller = presenter() else { throw roroError("This agreement could not be opened.") }
                controller.present(SFSafariViewController(url: url), animated: true)
                resolve(NSNull())
            case "sharePhoto":
                guard let image = payload["image"] as? String, let controller = presenter() else { throw roroError("This media file could not be shared.") }
                let url: URL
                if image.hasPrefix("media/") { url = try library.mediaURL(image) }
                else {
                    let clips = try CommunityCatalog.records("shorts")
                    let bundledVideos = try clips.compactMap { record -> String? in
                        guard let id = record["id"] as? String else { return nil }
                        return try CommunityCatalog.video(id)
                    }
                    let photos = try CommunityCatalog.records("photos").flatMap { $0["images"] as? [String] ?? [] }
                    let allowed = Set(photos).union(bundledVideos)
                    guard allowed.contains(image) else { throw roroError("This media file could not be shared.") }
                    url = pages.appendingPathComponent(image)
                }
                let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                share.popoverPresentationController?.sourceView = controller.view
                controller.present(share, animated: true)
                resolve(NSNull())
            case "unlockTopicWork":
                guard let id = payload["id"] as? String else { throw roroError("Choose a topic work.") }
                guard let scope = payload["scope"] as? String, let price = payload["price"] as? Int else { throw roroError("Choose an unlock option.") }
                resolve(try PurchaseService.shared.unlockTopicWork(id, scope: scope, quotedPrice: price))
            case "walletSnapshot": resolve(try PurchaseService.shared.snapshot())
            case "wallet":
                PurchaseService.shared.load { result in
                    switch result { case .success(let wallet): resolve(wallet); case .failure(let error): reject("PRICES_FAILED", error.localizedDescription, error) }
                }
            case "purchase":
                guard let id = payload["id"] as? String else { throw roroError("This offer is unavailable.") }
                try PurchaseService.shared.buy(id)
                resolve(NSNull())
            case "retryPurchases": PurchaseService.shared.retry(); resolve(NSNull())
            default:
                guard picker == nil, videoPicker == nil else { throw roroError("Please finish choosing your photos.") }
                _ = try library.change(command, payload)
                if command == "clearLibrary" {
                    // The committed state must reach the UI even if physical cleanup needs retry.
                    try? library.finishPendingCleanup(pages: pages)
                }
                resolve(try library.visibleSnapshot())
            }
        } catch { reject("ACTION_FAILED", error.localizedDescription, error) }
    }

    private func presenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var controller = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}
