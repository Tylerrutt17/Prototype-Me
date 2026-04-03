import UIKit
import Speech
import AVFoundation

/// Tap-to-record mic button with built-in speech recognition + audio file recording.
/// Tap once to start, tap again to stop. Delivers both transcription and recorded audio file.
final class VoiceInputButton: UIButton {

    // MARK: - Callbacks

    /// Called with the final transcribed text when recording stops (Apple on-device).
    var onTranscription: ((String) -> Void)?

    /// Called with partial results while recording.
    var onPartialResult: ((String) -> Void)?

    /// Called with the recorded audio file URL when recording stops (for Whisper upload).
    var onAudioRecorded: ((URL) -> Void)?

    /// Called if an error occurs (permissions denied, etc.)
    var onError: ((String) -> Void)?

    // MARK: - State

    private(set) var isRecording = false
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    /// Audio file recorder (records .wav alongside speech recognition)
    private var audioFileURL: URL?
    private var audioFile: AVAudioFile?

    /// Max recording duration
    private static let maxDuration: TimeInterval = 60
    private var maxDurationTimer: Timer?

    private let pulseLayer = CAShapeLayer()
    private var pulseAnimation: CABasicAnimation?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "mic.fill")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        config.baseBackgroundColor = .clear
        config.baseForegroundColor = DesignTokens.Colors.textSecondary
        config.contentInsets = .zero
        configuration = config

        addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)

        // Pulse ring (hidden until recording)
        pulseLayer.fillColor = UIColor.clear.cgColor
        pulseLayer.strokeColor = DesignTokens.Colors.destructive.withAlphaComponent(0.4).cgColor
        pulseLayer.lineWidth = 2
        pulseLayer.opacity = 0
        layer.addSublayer(pulseLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = -4
        let rect = bounds.insetBy(dx: inset, dy: inset)
        pulseLayer.path = UIBezierPath(ovalIn: rect).cgPath
        pulseLayer.frame = bounds
    }

    // MARK: - Toggle

    /// Public toggle for external callers (e.g., big mic button).
    func toggleStatus() {
        toggleRecording()
    }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            requestPermissionsAndStart()
        }
    }

    // MARK: - Permissions

    private func requestPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.requestMicAndStart()
                case .denied, .restricted:
                    self?.onError?("Speech recognition permission denied. Enable it in Settings.")
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func requestMicAndStart() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startRecording()
                } else {
                    self?.onError?("Microphone access denied. Enable it in Settings.")
                }
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            onError?("Speech recognition is not available on this device.")
            return
        }

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        }
        self.recognitionRequest = request

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("voice_\(UUID().uuidString).wav")
        self.audioFileURL = fileURL

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Write in the input node's exact format — no conversion, writes always succeed
        audioFile = try? AVAudioFile(forWriting: fileURL, settings: recordingFormat.settings)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // Feed to speech recognizer
            request.append(buffer)

            try? self.audioFile?.write(from: buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.onTranscription?(text)
                } else {
                    self.onPartialResult?(text)
                }
            }
            if error != nil {
                self.stopRecording()
            }
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try audioEngine.start()
        } catch {
            onError?("Could not start audio recording.")
            return
        }

        isRecording = true
        updateAppearance()

        // Max duration timer — auto-stop after 60 seconds
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: Self.maxDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.stopRecording()
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        audioFile = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        updateAppearance()

        // Deliver the recorded audio file
        if let fileURL = audioFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            onAudioRecorded?(fileURL)
        }
    }

    /// Clean up any temporary audio files.
    func cleanupAudioFile() {
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
            audioFileURL = nil
        }
    }

    // MARK: - Appearance

    private func updateAppearance() {
        var config = configuration ?? .filled()
        if isRecording {
            config.baseForegroundColor = DesignTokens.Colors.destructive
            config.image = UIImage(systemName: "mic.fill")
            startPulse()
        } else {
            config.baseForegroundColor = DesignTokens.Colors.textSecondary
            config.image = UIImage(systemName: "mic.fill")
            stopPulse()
        }
        configuration = config
    }

    private func startPulse() {
        pulseLayer.opacity = 1
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1.0
        anim.toValue = 1.5
        anim.duration = 0.8
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseLayer.add(anim, forKey: "pulse")
        pulseAnimation = anim
    }

    private func stopPulse() {
        pulseLayer.removeAllAnimations()
        pulseLayer.opacity = 0
    }

    // MARK: - Cleanup

    deinit {
        if isRecording { stopRecording() }
        cleanupAudioFile()
    }
}
