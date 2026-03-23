import UIKit
import Speech
import AVFoundation

/// Tap-to-record mic button with built-in speech recognition.
/// Tap once to start, tap again to stop. Transcribed text delivered via `onTranscription`.
final class VoiceInputButton: UIButton {

    // MARK: - Callbacks

    /// Called with the final transcribed text when recording stops.
    var onTranscription: ((String) -> Void)?

    /// Called with partial results while recording.
    var onPartialResult: ((String) -> Void)?

    /// Called if an error occurs (permissions denied, etc.)
    var onError: ((String) -> Void)?

    // MARK: - State

    private(set) var isRecording = false
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

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

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
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
    }

    private func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isRecording = false
        updateAppearance()
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
    }
}
