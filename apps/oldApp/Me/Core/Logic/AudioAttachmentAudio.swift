import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioRecorderController: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording: Bool = false
    @Published var elapsed: TimeInterval = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentURL: URL?

    func start() async throws -> URL {
        guard try await requestPermission() else {
            throw AudioAttachmentStoreError.recordingUnavailable
        }
        let url = try AudioAttachmentStore.shared.newRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        recorder?.record()
        isRecording = true
        currentURL = url
        startTimer()
        return url
    }

    func stop() -> (url: URL, duration: TimeInterval)? {
        defer { cleanup() }
        guard let recorder else { return nil }
        recorder.stop()
        let duration = recorder.currentTime
        return (recorder.url, duration)
    }

    func cancel() {
        cleanup()
        if let url = currentURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        currentURL = nil
        elapsed = 0
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let recorder else { return }
            self.elapsed = recorder.currentTime
        }
    }

    private func requestPermission() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

@MainActor
final class AudioPlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var currentlyPlayingId: String? = nil
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?

    func togglePlay(attachment: AudioAttachment) {
        if currentlyPlayingId == attachment.id {
            stop()
            return
        }
        do {
            let url = try AudioAttachmentStore.shared.url(for: attachment.fileName)
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.play()
            player = audioPlayer
            currentlyPlayingId = attachment.id
        } catch {
            errorMessage = "Playback failed."
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentlyPlayingId = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}
