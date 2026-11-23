import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class JournalShortsTimeline: ObservableObject {
    @Published var time: Double = 0
}

@MainActor
final class JournalShortsPlayer: ObservableObject {
    let player = AVPlayer()
    let timeline = JournalShortsTimeline()
    @Published private(set) var duration: Double = 0
    @Published private(set) var ready = false
    @Published private(set) var failure: String?

    private var status: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var shouldPlay = false

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .none
    }

    func load(_ url: URL, duration estimate: Double) {
        clear()
        duration = estimate
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        status = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor in
                guard let self, self.player.currentItem === observed else { return }
                switch observed.status {
                case .readyToPlay:
                    self.ready = true
                    if observed.duration.seconds.isFinite { self.duration = observed.duration.seconds }
                    self.sync()
                case .failed:
                    self.fail(observed.error?.localizedDescription ?? "This video could not be played. Try again.")
                default: break
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.player.currentItem === item else { return }
                self.seek(to: 0)
                self.sync()
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] notification in
            let message = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
            Task { @MainActor in
                guard let self, self.player.currentItem === item else { return }
                self.fail(message ?? "This video could not be played. Try again.")
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] position in
            Task { @MainActor in
                guard let self, self.player.currentItem === item, position.seconds.isFinite else { return }
                self.timeline.time = max(0, position.seconds)
            }
        }
    }

    func setPlaying(_ value: Bool) {
        shouldPlay = value
        sync()
    }

    private func sync() {
        if ready && shouldPlay && failure == nil { player.play() }
        else { player.pause() }
    }

    func fail(_ message: String) {
        failure = message
        player.pause()
    }

    func seek(to value: Double) {
        guard value.isFinite else { return }
        let target = min(duration, max(0, value))
        timeline.time = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func clear() {
        player.pause()
        status?.invalidate()
        status = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        endObserver = nil
        failureObserver = nil
        timeObserver = nil
        player.replaceCurrentItem(with: nil)
        timeline.time = 0
        duration = 0
        ready = false
        failure = nil
    }
}

private final class ShortPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playbackLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct JournalShortsVideo: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = ShortPlayerView()
        view.playbackLayer.videoGravity = .resizeAspect
        view.playbackLayer.player = player
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        (view as? ShortPlayerView)?.playbackLayer.player = player
    }

    static func dismantleUIView(_ view: UIView, coordinator: Void) {
        (view as? ShortPlayerView)?.playbackLayer.player = nil
    }
}

func journalShortClock(_ seconds: Double) -> String {
    let whole = seconds.isFinite ? Int(max(0, seconds)) : 0
    return String(format: "%d:%02d", whole / 60, whole % 60)
}

@MainActor
struct JournalShortTransport: View {
    let playback: JournalShortsPlayer
    @ObservedObject var timeline: JournalShortsTimeline
    @Binding var muted: Bool
    let estimate: Double
    @State private var seeking = false
    @State private var seekValue = 0.0

    var body: some View {
        let duration = max(0.1, playback.duration > 0 ? playback.duration : estimate)
        let progress = seeking ? seekValue : min(timeline.time, duration)
        return VStack(spacing: -4) {
            HStack {
                JournalIcon(muted ? "mute" : "sound", muted ? "Turn sound on" : "Mute video") { muted.toggle() }
                Spacer()
                Text("\(journalShortClock(progress)) / \(journalShortClock(duration))")
                    .monospacedDigit().font(.custom("Kalam-Regular", size: 13))
            }
            Slider(value: Binding(get: { progress }, set: { newValue in
                seekValue = newValue
                playback.seek(to: newValue)
            }), in: 0...duration, onEditingChanged: { editing in
                if editing { seekValue = min(timeline.time, duration) }
                seeking = editing
            })
            .tint(Color(red: 0.91, green: 0.71, blue: 0.54))
            .accessibilityLabel("Video progress").accessibilityValue("\(journalShortClock(progress)) of \(journalShortClock(duration))")
        }
        .padding(.horizontal, 18)
    }
}
