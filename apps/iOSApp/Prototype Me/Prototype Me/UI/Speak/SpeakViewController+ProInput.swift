import UIKit

// MARK: - Pro Voice Input

extension SpeakViewController {

    func setupProInput() {
        // Pro mic button sits above the text input bar
        var micConfig = UIButton.Configuration.filled()
        micConfig.image = UIImage(systemName: "mic.fill")
        micConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        micConfig.baseBackgroundColor = DesignTokens.Colors.accent
        micConfig.baseForegroundColor = .white
        micConfig.cornerStyle = .capsule
        micConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        proMicButton.configuration = micConfig
        proMicButton.translatesAutoresizingMaskIntoConstraints = false
        proMicButton.clipsToBounds = false
        proMicButton.addTarget(self, action: #selector(proMicTapped), for: .touchUpInside)

        proStatusLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        proStatusLabel.textColor = DesignTokens.Colors.textTertiary
        proStatusLabel.textAlignment = .center
        proStatusLabel.text = "Tap to speak"
        proStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        // Waveform — hidden until recording
        proWaveformView.translatesAutoresizingMaskIntoConstraints = false
        proWaveformView.alpha = 0
        proWaveformView.isHidden = true

        // Small stop button overlaid on the waveform
        var stopConfig = UIButton.Configuration.filled()
        stopConfig.image = UIImage(systemName: "stop.fill")
        stopConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        stopConfig.baseBackgroundColor = DesignTokens.Colors.destructive
        stopConfig.baseForegroundColor = .white
        stopConfig.cornerStyle = .capsule
        stopConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        proStopButton.configuration = stopConfig
        proStopButton.translatesAutoresizingMaskIntoConstraints = false
        proStopButton.alpha = 0
        proStopButton.isHidden = true
        proStopButton.addTarget(self, action: #selector(proMicTapped), for: .touchUpInside)

        view.addSubview(proWaveformView)
        view.addSubview(proMicButton)
        view.addSubview(proStopButton)
        view.addSubview(proStatusLabel)

        // Anchor: status label just above input bar, mic button above status label
        proMicBottomConstraint = proMicButton.bottomAnchor.constraint(
            equalTo: proStatusLabel.topAnchor, constant: -DesignTokens.Spacing.xs
        )

        proWaveformWidth = proWaveformView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.35)

        NSLayoutConstraint.activate([
            proStatusLabel.bottomAnchor.constraint(equalTo: inputBar.topAnchor, constant: -DesignTokens.Spacing.xs),
            proStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            proMicButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            proMicBottomConstraint,
            proMicButton.widthAnchor.constraint(equalToConstant: 56),
            proMicButton.heightAnchor.constraint(equalToConstant: 56),

            // Waveform centered on mic button, width animated
            proWaveformView.centerYAnchor.constraint(equalTo: proMicButton.centerYAnchor),
            proWaveformView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            proWaveformWidth,
            proWaveformView.heightAnchor.constraint(equalToConstant: 48),

            // Stop button — trailing edge, outside waveform
            proStopButton.centerYAnchor.constraint(equalTo: proWaveformView.centerYAnchor),
            proStopButton.leadingAnchor.constraint(equalTo: proWaveformView.trailingAnchor, constant: DesignTokens.Spacing.md),
            proStopButton.widthAnchor.constraint(equalToConstant: 36),
            proStopButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Update response area to clear the mic button
        responseBottomConstraint.isActive = false
        responseBottomConstraint = responseScrollView.bottomAnchor.constraint(equalTo: proMicButton.topAnchor, constant: -DesignTokens.Spacing.md)
        responseBottomConstraint.isActive = true

        inputAreaTopAnchor = proMicButton.topAnchor
    }

    @objc func proMicTapped() {
        guard !isProcessing else { return }
        if micButton.isRecording {
            if let start = recordingStartTime, Date().timeIntervalSince(start) < 1.0 {
                micButton.toggleStatus()
                isRecording = false
                proSetState(.idle)
                micButton.cleanupAudioFile()
                return
            }
            proSetState(.transcribing)
            isRecording = false
            micButton.toggleStatus()
        } else {
            recordingStartTime = Date()
            micButton.toggleStatus()
            isRecording = true
            proSetState(.recording)
        }
    }

    enum ProState {
        case idle, recording, transcribing
    }

    func proSetState(_ state: ProState) {
        switch state {
        case .idle:
            proStatusLabel.text = "Tap to speak"
            proStatusLabel.textColor = DesignTokens.Colors.textTertiary
            proMicButton.isEnabled = !isProcessing
            showMicButton()

        case .recording:
            proStatusLabel.text = "Listening..."
            proStatusLabel.textColor = DesignTokens.Colors.destructive
            showWaveform()
            hideEmptyState()

        case .transcribing:
            proStatusLabel.text = "Transcribing..."
            proStatusLabel.textColor = DesignTokens.Colors.accent
            proMicButton.isEnabled = false
            showMicButton()
        }
    }

    // MARK: - Crossfade: Mic Button ↔ Waveform

    private func showWaveform() {
        proWaveformView.isHidden = false
        proStopButton.isHidden = false
        proStopButton.alpha = 0

        // Start fully collapsed horizontally from center
        proWaveformView.alpha = 1
        proWaveformView.transform = CGAffineTransform(scaleX: 0.01, y: 1)
        proWaveformView.startAnimating()

        // 1) Mic shrinks into nothing
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseIn) {
            self.proMicButton.alpha = 0
            self.proMicButton.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        }

        // 2) Waveform expands horizontally from center
        UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.proWaveformView.transform = .identity
        }

        // 3) Stop button fades in
        UIView.animate(withDuration: 0.2, delay: 0.25, options: .curveEaseOut) {
            self.proStopButton.alpha = 1
        }
    }

    private func showMicButton() {
        proWaveformView.stopAnimating()

        // 1) Waveform collapses horizontally back to center
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.proWaveformView.transform = CGAffineTransform(scaleX: 0.01, y: 1)
            self.proStopButton.alpha = 0
        } completion: { _ in
            self.proWaveformView.alpha = 0
            self.proWaveformView.isHidden = true
            self.proStopButton.isHidden = true
        }

        // 2) Mic pops back from center
        UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.proMicButton.alpha = 1
            self.proMicButton.transform = .identity
        }
    }

    /// Pro voice flow: transcription completes -> auto-send to AI
    func proHandleTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[Speak] proHandleTranscription: empty text, returning to idle")
            proSetState(.idle)
            return
        }
        print("[Speak] proHandleTranscription: text chars: \(text.count), handing off to sendMessage")
        proSetState(.idle)
        sendMessage(text)
    }
}
