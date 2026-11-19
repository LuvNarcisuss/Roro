import UIKit
import PhotosUI
import ImageIO
import AVFoundation
import AVKit
import UniformTypeIdentifiers

final class MediaPicker: NSObject, PHPickerViewControllerDelegate {
    private var completion: ((Result<[String], Error>) -> Void)?
    private let library: PhotoLibrary
    private let pages: URL
    private let forAvatar: Bool

    init(library: PhotoLibrary, pages: URL, forAvatar: Bool) {
        self.library = library
        self.pages = pages
        self.forAvatar = forAvatar
    }

    func present(from controller: UIViewController, completion: @escaping (Result<[String], Error>) -> Void) {
        self.completion = completion
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = forAvatar ? 1 : 3
        configuration.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        controller.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { finish(.success([])); return }
        let group = DispatchGroup()
        let lock = NSLock()
        var imported = [Int: String]()
        var failure: Error?
        for (index, item) in results.enumerated() {
            group.enter()
            item.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.image") { url, error in
                defer { group.leave() }
                do {
                    guard let url else { throw error ?? roroError("This photo could not be opened.") }
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: self.forAvatar ? 640 : 1600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary),
                          let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.86) else { throw roroError("This photo format is unavailable.") }
                    let filename = UUID().uuidString + ".jpg"
                    try data.write(to: self.library.media.appendingPathComponent(filename), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                    lock.lock(); imported[index] = "media/" + filename; lock.unlock()
                } catch { lock.lock(); failure = error; lock.unlock() }
            }
        }
        group.notify(queue: .main) {
            if let failure {
                for item in imported.values { if let url = try? self.library.mediaURL(item) { try? FileManager.default.removeItem(at: url) } }
                self.finish(.failure(failure))
            } else {
                do {
                    try self.library.exportMedia(to: self.pages)
                    self.finish(.success(imported.keys.sorted().compactMap { imported[$0] }))
                } catch { self.finish(.failure(error)) }
            }
        }
    }

    private func finish(_ result: Result<[String], Error>) {
        let handler = completion
        completion = nil
        handler?(result)
    }
}

// Videos remain in native storage; the WebView only receives JPEG posters.
final class VideoPicker: NSObject, PHPickerViewControllerDelegate {
    private let library: PhotoLibrary
    private let pages: URL
    private var completion: ((Result<[String: Any]?, Error>) -> Void)?
    private var exportSession: AVAssetExportSession?
    private var importProgress: Progress?
    private var timeout: DispatchWorkItem?
    private var finished = false

    init(library: PhotoLibrary, pages: URL) { self.library = library; self.pages = pages }

    func present(from controller: UIViewController, completion: @escaping (Result<[String: Any]?, Error>) -> Void) {
        self.completion = completion
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        controller.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { finish(.success(nil)); return }
        let deadline = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.importProgress?.cancel()
            self.exportSession?.cancelExport()
            self.finish(.failure(roroError("This video took too long to prepare. Try a shorter clip stored on your iPhone.")))
        }
        timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: deadline)
        importProgress = result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            do {
                guard let url else { throw error ?? roroError("This video could not be opened.") }
                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard bytes > 0, bytes <= 200 * 1024 * 1024 else { throw roroError("Choose a video smaller than 200 MB.") }
                // The provider's URL is valid only until this callback returns.
                let input = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
                try FileManager.default.copyItem(at: url, to: input)
                DispatchQueue.main.async {
                    if self.finished { try? FileManager.default.removeItem(at: input); return }
                    Task { await self.prepare(input) }
                }
            } catch { DispatchQueue.main.async { self.finish(.failure(error)) } }
        }
    }

    @MainActor private func prepare(_ input: URL) async {
        let filename = UUID().uuidString
        let video = library.media.appendingPathComponent(filename + ".mp4")
        let poster = library.media.appendingPathComponent(filename + ".jpg")
        defer { try? FileManager.default.removeItem(at: input) }
        do {
            let asset = AVURLAsset(url: input)
            let duration = try await asset.load(.duration).seconds
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard duration.isFinite, duration > 0, duration <= 60, !tracks.isEmpty else {
                throw roroError("Choose a video up to 60 seconds long.")
            }
            guard !finished else { return }
            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720), exporter.supportedFileTypes.contains(.mp4) else {
                throw roroError("This video format is unavailable.")
            }
            exportSession = exporter
            exporter.outputURL = video
            exporter.outputFileType = .mp4
            exporter.shouldOptimizeForNetworkUse = true
            // Avoid copying location and other private source metadata.
            exporter.metadata = []
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                exporter.exportAsynchronously { continuation.resume() }
            }
            guard !finished, exporter.status == .completed else { throw exporter.error ?? roroError("Your video could not be prepared.") }
            let size = try video.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 80 * 1024 * 1024 else { throw roroError("This video is too large. Choose a shorter clip.") }
            let output = AVURLAsset(url: video)
            let finalDuration = try await output.load(.duration).seconds
            guard finalDuration.isFinite, finalDuration > 0, finalDuration <= 60 else { throw roroError("Choose a video up to 60 seconds long.") }
            let generator = AVAssetImageGenerator(asset: output)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1000, height: 1000)
            let frame = try await generator.image(at: CMTime(seconds: min(0.1, finalDuration / 2), preferredTimescale: 600)).image
            guard !finished, let jpeg = UIImage(cgImage: frame).jpegData(compressionQuality: 0.86) else { throw roroError("Your video cover could not be prepared.") }
            try jpeg.write(to: poster, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: video.path)
            try library.exportMedia(to: pages)
            finish(.success(["video": "media/" + video.lastPathComponent, "poster": "media/" + poster.lastPathComponent, "duration": finalDuration]))
        } catch {
            for url in [video, poster, pages.appendingPathComponent("media/" + poster.lastPathComponent)] { try? FileManager.default.removeItem(at: url) }
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<[String: Any]?, Error>) {
        guard !finished else { return }
        finished = true
        timeout?.cancel()
        timeout = nil
        let handler = completion
        completion = nil
        handler?(result)
    }
}

final class ShortPlayerController: UIViewController {
    private let playback = AVPlayerViewController()
    var player: AVPlayer? {
        get { playback.player }
        set { playback.player = newValue }
    }
    private var backgroundObserver: NSObjectProtocol?
    private var failureObservation: NSKeyValueObservation?
    private var failureShown = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        playback.allowsPictureInPicturePlayback = false
        addChild(playback)
        view.addSubview(playback.view)
        playback.view.translatesAutoresizingMaskIntoConstraints = false
        playback.didMove(toParent: self)
        let close = UIButton(type: .custom)
        if let path = Bundle.main.path(forResource: "journal-back", ofType: "png", inDirectory: "AppResources") {
            close.setImage(UIImage(contentsOfFile: path), for: .normal)
        }
        close.accessibilityLabel = "Close video"
        close.imageView?.contentMode = .scaleAspectFit
        close.imageEdgeInsets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        close.backgroundColor = UIColor(red: 1, green: 0.94, blue: 0.85, alpha: 0.95)
        close.layer.cornerRadius = 8
        close.addTarget(self, action: #selector(closePlayer), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(close)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            close.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            close.heightAnchor.constraint(equalToConstant: 44),
            close.widthAnchor.constraint(equalToConstant: 48),
            playback.view.topAnchor.constraint(equalTo: close.bottomAnchor),
            playback.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playback.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playback.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.player?.pause() }
        failureObservation = player?.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                guard let self, !self.failureShown else { return }
                self.failureShown = true
                self.player?.pause()
                let alert = UIAlertController(title: "Video unavailable", message: "This video could not be played. Your original file has been kept.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Close", style: .default) { [weak self] _ in self?.dismiss(animated: true) })
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func closePlayer() {
        player?.pause()
        dismiss(animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player?.pause()
    }

    deinit {
        player?.pause()
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }
}
