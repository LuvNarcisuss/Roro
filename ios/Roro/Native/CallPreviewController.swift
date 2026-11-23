import AVFoundation
import Accelerate
import UIKit

final class CallPreviewController: UIViewController {
    private let video: Bool
    private let peerName: String
    private let portrait: URL
    private let camera = AVCaptureSession()
    private var microphone: AVAudioEngine?
    private let queue = DispatchQueue(label: "com.roro.photography.call-preview")
    private let audio = AVAudioSession.sharedInstance()
    private var previousAudio: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?
    private var preview: AVCaptureVideoPreviewLayer?
    private let meter = UIProgressView(progressViewStyle: .default)
    private var micButton = UIButton()
    private var speakerButton = UIButton()
    private var microphoneOn = true
    private var speakerOn = true
    private var open = false
    private var suspended = false
    private var generation = 0
    private var recoveredCameraReset = false

    init(video: Bool, name: String, portrait: URL) {
        self.video = video
        peerName = name
        self.portrait = portrait
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { nil }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = video ? .black : UIColor(red: 0.055, green: 0.23, blue: 0.22, alpha: 1)
        let safe = view.safeAreaLayoutGuide
        if video {
            let layer = AVCaptureVideoPreviewLayer(session: camera)
            layer.videoGravity = .resizeAspectFill
            view.layer.insertSublayer(layer, at: 0)
            preview = layer
        } else {
            let avatar = UIImageView(image: UIImage(contentsOfFile: portrait.path))
            avatar.contentMode = .scaleAspectFill
            avatar.layer.cornerRadius = 48
            avatar.clipsToBounds = true
            avatar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(avatar)
            NSLayoutConstraint.activate([
                avatar.widthAnchor.constraint(equalToConstant: 96), avatar.heightAnchor.constraint(equalTo: avatar.widthAnchor),
                avatar.centerXAnchor.constraint(equalTo: safe.centerXAnchor), avatar.centerYAnchor.constraint(equalTo: safe.centerYAnchor)
            ])
        }
        let title = UILabel()
        title.text = peerName
        title.font = UIFont(name: "Kalam-Regular", size: 30) ?? .preferredFont(forTextStyle: .title1)
        let mode = UILabel()
        mode.text = video ? "Video call" : "Voice call"
        for label in [title, mode] {
            label.textAlignment = .center
            label.textColor = .white
            label.numberOfLines = 0
        }
        let heading = UIStackView(arrangedSubviews: [title, mode])
        heading.axis = .vertical
        heading.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        heading.layer.cornerRadius = 14
        heading.isLayoutMarginsRelativeArrangement = true
        heading.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        heading.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(heading)
        speakerButton = button("sound", "Speaker", #selector(toggleSpeaker))
        let hangUp = button("call-hangup", "End call", #selector(finish))
        micButton = button("call-microphone", "Microphone", #selector(toggleMicrophone))
        updateControls()
        let controls = UIStackView(arrangedSubviews: [speakerButton, hangUp, micButton])
        controls.spacing = 18
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)
        meter.translatesAutoresizingMaskIntoConstraints = false
        meter.progressTintColor = UIColor(red: 0.96, green: 0.72, blue: 0.29, alpha: 1)
        meter.trackTintColor = UIColor.white.withAlphaComponent(0.45)
        meter.accessibilityLabel = "Microphone level"
        meter.isHidden = true
        view.addSubview(meter)
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            heading.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            heading.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -24),
            controls.centerXAnchor.constraint(equalTo: safe.centerXAnchor), controls.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -20),
            meter.centerXAnchor.constraint(equalTo: safe.centerXAnchor), meter.widthAnchor.constraint(equalToConstant: 120),
            meter.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -20)
        ])
        let notifications = NotificationCenter.default
        notifications.addObserver(self, selector: #selector(enterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notifications.addObserver(self, selector: #selector(returnToCall), name: UIApplication.didBecomeActiveNotification, object: nil)
        notifications.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: audio)
        camera.automaticallyConfiguresApplicationAudioSession = false
        notifications.addObserver(self, selector: #selector(resumeCamera), name: AVCaptureSession.interruptionEndedNotification, object: camera)
        notifications.addObserver(self, selector: #selector(recoverCamera(_:)), name: AVCaptureSession.runtimeErrorNotification, object: camera)
        notifications.addObserver(self, selector: #selector(audioInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: audio)
        notifications.addObserver(self, selector: #selector(restoreAudio), name: AVAudioSession.mediaServicesWereResetNotification, object: audio)
    }

    private func artwork(_ name: String) -> UIImage? {
        guard let icon = JournalAssets.url("assets/icons/\(name).png"), let pixels = UIImage(contentsOfFile: icon.path)?.cgImage else { return nil }
        return UIImage(cgImage: pixels, scale: CGFloat(pixels.width) / 38, orientation: .up).withRenderingMode(.alwaysOriginal)
    }

    private func button(_ icon: String, _ label: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setImage(artwork(icon), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.backgroundColor = UIColor(red: 1, green: 0.94, blue: 0.83, alpha: 0.95)
        button.layer.cornerRadius = 27
        button.accessibilityLabel = label
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 54).isActive = true
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true
        return button
    }

    private func updateControls() {
        speakerButton.setImage(artwork(speakerOn ? "sound" : "call-speaker-off"), for: .normal)
        micButton.setImage(artwork(microphoneOn ? "call-microphone" : "call-microphone-off"), for: .normal)
        speakerButton.accessibilityValue = speakerOn ? "On" : "Off"
        micButton.accessibilityValue = microphoneOn ? "On" : "Off"
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
        if let connection = preview?.connection {
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        open = true
        suspended = UIApplication.shared.applicationState == .background
        beginCapture()
    }

    private func beginCapture() {
        guard open, !suspended else { return }
        generation += 1
        recoveredCameraReset = false
        let attempt = generation
        applySpeakerRoute()
        if video {
            authorize(.video) { [weak self] allowed in
                guard let self, self.open, self.generation == attempt else { return }
                if allowed { self.startCamera() }
                self.requestMicrophone(attempt)
            }
        } else { requestMicrophone(attempt) }
    }

    private func authorize(_ type: AVMediaType, then: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: then(true)
        case .notDetermined: AVCaptureDevice.requestAccess(for: type) { allowed in DispatchQueue.main.async { then(allowed) } }
        default: then(false)
        }
    }

    private func requestMicrophone(_ attempt: Int) {
        authorize(.audio) { [weak self] allowed in
            guard let self, self.open, self.generation == attempt else { return }
            if allowed, self.microphoneOn { self.startMicrophone() }
            if !allowed {
                self.microphoneOn = false
                self.updateControls()
            }
        }
    }

    private func startCamera() {
        queue.async { [self] in
            if camera.inputs.isEmpty {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                      let input = try? AVCaptureDeviceInput(device: device), camera.canAddInput(input) else { return }
                camera.beginConfiguration()
                if camera.canSetSessionPreset(.high) { camera.sessionPreset = .high }
                camera.addInput(input)
                camera.commitConfiguration()
            }
            if !camera.isInterrupted && !camera.isRunning { camera.startRunning() }
            DispatchQueue.main.async { [weak self] in self?.view.setNeedsLayout() }
        }
    }

    private func startMicrophone() {
        queue.async { [self] in
            guard microphone?.isRunning != true, audio.isInputAvailable else { return }
            stopMicrophone()
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.inputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else { return }
            input.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
                guard let self, !self.video, buffer.frameLength > 0, let samples = buffer.floatChannelData?[0] else { return }
                var rms: Float = 0
                vDSP_rmsqv(samples, vDSP_Stride(buffer.stride), &rms, vDSP_Length(buffer.frameLength))
                let level = max(0, min(1, (20 * log10(max(rms, 0.001)) + 60) / 60))
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.open, !self.suspended, self.microphoneOn else { return }
                    self.meter.isHidden = false
                    self.meter.progress = level
                }
            }
            do {
                try engine.start()
                microphone = engine
            } catch {
                input.removeTap(onBus: 0)
                engine.stop()
            }
        }
    }

    private func stopMicrophone() {
        guard let engine = microphone else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        microphone = nil
    }

    @objc private func toggleMicrophone() {
        microphoneOn.toggle()
        updateControls()
        if microphoneOn {
            applySpeakerRoute()
            requestMicrophone(generation)
        } else {
            meter.isHidden = true
            queue.async { [self] in stopMicrophone() }
        }
    }

    @objc private func toggleSpeaker() {
        speakerOn.toggle()
        updateControls()
        applySpeakerRoute()
    }

    private func applySpeakerRoute() {
        let enabled = speakerOn
        queue.async { [self] in
            if previousAudio == nil { previousAudio = (audio.category, audio.mode, audio.categoryOptions) }
            do {
                if audio.category != .playAndRecord || audio.mode != .default || audio.categoryOptions != [] {
                    try audio.setCategory(.playAndRecord, mode: .default, options: [])
                }
                try audio.setActive(true)
                try audio.overrideOutputAudioPort(enabled ? .speaker : .none)
            } catch {
                // The preference is reapplied on foreground entry or a device route change.
            }
        }
    }

    @objc private func routeChanged(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
              reason == .newDeviceAvailable || reason == .oldDeviceUnavailable else { return }
        restoreAudio()
    }

    @objc private func enterBackground() {
        guard open, !suspended else { return }
        suspended = true
        generation += 1
        releaseInputs()
    }

    @objc private func returnToCall() {
        guard open, suspended else { return }
        suspended = false
        beginCapture()
    }

    @objc private func resumeCamera() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.video, self.open, !self.suspended,
                  AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
            self.startCamera()
        }
    }

    @objc private func recoverCamera(_ notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError,
              error.code == .mediaServicesWereReset else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.video, self.open, !self.suspended, !self.recoveredCameraReset else { return }
            self.recoveredCameraReset = true
            self.queue.async { self.stopCamera() }
            self.resumeCamera()
        }
    }

    @objc private func restoreAudio() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.open, !self.suspended else { return }
            self.queue.async { self.stopMicrophone() }
            self.applySpeakerRoute()
            if self.microphoneOn { self.requestMicrophone(self.generation) }
        }
    }

    @objc private func audioInterrupted(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended { restoreAudio(); return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.open else { return }
            self.meter.isHidden = true
            self.queue.async { self.stopMicrophone() }
        }
    }

    @objc private func finish() {
        guard !isBeingDismissed else { return }
        open = false
        dismiss(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        open = false
        generation += 1
        releaseInputs()
    }

    private func stopCamera() {
        if camera.isRunning { camera.stopRunning() }
        camera.beginConfiguration()
        camera.inputs.forEach { camera.removeInput($0) }
        camera.commitConfiguration()
    }

    private func releaseInputs() {
        meter.isHidden = true
        queue.async { [self] in
            stopCamera()
            stopMicrophone()
            if let (category, mode, options) = previousAudio {
                try? audio.overrideOutputAudioPort(.none)
                try? audio.setActive(false, options: .notifyOthersOnDeactivation)
                try? audio.setCategory(category, mode: mode, options: options)
                previousAudio = nil
            }
        }
    }
}
