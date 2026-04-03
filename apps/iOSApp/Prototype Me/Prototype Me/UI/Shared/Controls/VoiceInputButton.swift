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

    /// Called with normalized audio power level (0.0–1.0) during recording.
    var onAudioLevel: ((Float) -> Void)?

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

            // Compute RMS power for audio visualization
            if let onAudioLevel = self.onAudioLevel,
               let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += channelData[i] * channelData[i]
                }
                let rms = sqrtf(sum / Float(max(frameLength, 1)))
                // Normalize: typical speech RMS ~0.01-0.1, map to 0-1
                let normalized = min(max(rms * 5, 0), 1)
                DispatchQueue.main.async {
                    onAudioLevel(normalized)
                }
            }
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

        // Analyze, compress, and deliver the recorded audio file
        if let fileURL = audioFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            let result = analyzeAndTrim(fileURL: fileURL)
            switch result {
            case .silence:
                cleanupAudioFile()
                onError?("No speech detected. Try again.")
            case .trimmed, .unchanged:
                compressToAAC(wavURL: fileURL) { [weak self] aacURL in
                    if let aacURL {
                        self?.audioFileURL = aacURL
                        try? FileManager.default.removeItem(at: fileURL)
                        self?.onAudioRecorded?(aacURL)
                    } else {
                        // Compression failed — send the WAV as fallback
                        self?.onAudioRecorded?(fileURL)
                    }
                }
            }
        }
    }

    // MARK: - Post-Recording Analysis

    private enum AnalysisResult {
        case silence    // no meaningful audio
        case trimmed    // trailing silence removed
        case unchanged  // file is fine as-is
    }

    /// Analyze the WAV file: detect silence-only recordings, trim trailing dead air,
    /// and compress internal silence gaps longer than 2s down to 2s.
    private func analyzeAndTrim(fileURL: URL) -> AnalysisResult {
        guard let file = try? AVAudioFile(forReading: fileURL) else { return .unchanged }
        let format = file.processingFormat
        let totalFrames = file.length
        guard totalFrames > 0 else { return .silence }

        let sampleRate = format.sampleRate
        let channels = Int(format.channelCount)
        let threshold: Float = 0.005 // amplitude threshold for "sound"
        let maxSilenceFrames = Int(sampleRate * 2.0) // 2s max silence

        // Read entire file into a buffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else { return .unchanged }
        do { try file.read(into: buffer) } catch { return .unchanged }

        guard let channelData = buffer.floatChannelData else { return .unchanged }
        let frameCount = Int(buffer.frameLength)

        // Classify each frame as sound or silence
        // Then build output: copy sound frames, cap silence runs at 2s, trim trailing silence
        var isSound = [Bool](repeating: false, count: frameCount)
        var lastSoundFrame = -1
        for frame in 0..<frameCount {
            for ch in 0..<channels {
                if abs(channelData[ch][frame]) > threshold {
                    isSound[frame] = true
                    lastSoundFrame = frame
                    break
                }
            }
        }

        // No sound at all
        if lastSoundFrame < 0 { return .silence }

        // Trim trailing silence: only keep up to 0.3s after last sound
        let endFrame = min(frameCount, lastSoundFrame + Int(sampleRate * 0.3))

        // Build output frames, compressing silence gaps > 2s
        // Collect ranges of (start, length) to copy from source
        var ranges: [(start: Int, count: Int)] = []
        var silenceRun = 0
        var outputFrameCount = 0

        for frame in 0..<endFrame {
            if isSound[frame] {
                silenceRun = 0
                if let last = ranges.last, last.start + last.count == frame {
                    ranges[ranges.count - 1] = (last.start, last.count + 1)
                } else {
                    ranges.append((start: frame, count: 1))
                }
                outputFrameCount += 1
            } else {
                silenceRun += 1
                if silenceRun <= maxSilenceFrames {
                    if let last = ranges.last, last.start + last.count == frame {
                        ranges[ranges.count - 1] = (last.start, last.count + 1)
                    } else {
                        ranges.append((start: frame, count: 1))
                    }
                    outputFrameCount += 1
                }
                // else: skip — silence beyond 2s cap
            }
        }

        // Nothing to change
        let framesRemoved = frameCount - outputFrameCount
        guard framesRemoved > Int(sampleRate) else { return .unchanged } // only bother if we save > 1s

        // Write compressed file
        let trimmedURL = fileURL.deletingLastPathComponent().appendingPathComponent("trimmed_\(UUID().uuidString).wav")
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(outputFrameCount)) else { return .unchanged }

        var writePos = 0
        for range in ranges {
            for ch in 0..<channels {
                memcpy(outBuffer.floatChannelData![ch].advanced(by: writePos),
                       channelData[ch].advanced(by: range.start),
                       range.count * MemoryLayout<Float>.size)
            }
            writePos += range.count
        }
        outBuffer.frameLength = AVAudioFrameCount(outputFrameCount)

        guard let outFile = try? AVAudioFile(forWriting: trimmedURL, settings: format.settings) else { return .unchanged }
        do {
            try outFile.write(from: outBuffer)
        } catch {
            try? FileManager.default.removeItem(at: trimmedURL)
            return .unchanged
        }

        // Replace original
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.moveItem(at: trimmedURL, to: fileURL)
        return .trimmed
    }

    // MARK: - WAV → AAC Compression

    /// Compress a WAV file to AAC m4a. Calls completion on main thread with the AAC URL, or nil on failure.
    private func compressToAAC(wavURL: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: wavURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(nil)
            return
        }

        let aacURL = wavURL.deletingLastPathComponent()
            .appendingPathComponent("voice_\(UUID().uuidString).m4a")
        exporter.outputURL = aacURL
        exporter.outputFileType = .m4a

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                switch exporter.status {
                case .completed:
                    completion(aacURL)
                default:
                    try? FileManager.default.removeItem(at: aacURL)
                    completion(nil)
                }
            }
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
