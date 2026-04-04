import UIKit

// MARK: - Pro Voice Input

extension SpeakViewController {

    func setupProInput() {
        // Pro mic button stays at bottom
        var micConfig = UIButton.Configuration.filled()
        micConfig.image = UIImage(systemName: "mic.fill")
        micConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        micConfig.baseBackgroundColor = DesignTokens.Colors.accent
        micConfig.baseForegroundColor = .white
        micConfig.cornerStyle = .capsule
        micConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        proMicButton.configuration = micConfig
        proMicButton.translatesAutoresizingMaskIntoConstraints = false
        proMicButton.clipsToBounds = true
        proMicButton.addTarget(self, action: #selector(proMicTapped), for: .touchUpInside)

        proRecordingGradient.colors = [
            DesignTokens.Colors.destructive.cgColor,
            DesignTokens.Colors.destructive.withAlphaComponent(0.6).cgColor,
            UIColor.white.withAlphaComponent(0.3).cgColor,
            DesignTokens.Colors.destructive.withAlphaComponent(0.6).cgColor,
            DesignTokens.Colors.destructive.cgColor,
        ]
        proRecordingGradient.startPoint = CGPoint(x: 0, y: 0.5)
        proRecordingGradient.endPoint = CGPoint(x: 1, y: 0.5)
        proRecordingGradient.locations = [0, 0.3, 0.5, 0.7, 1]
        proRecordingGradient.opacity = 0
        proMicButton.layer.insertSublayer(proRecordingGradient, at: 0)

        proStatusLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        proStatusLabel.textColor = DesignTokens.Colors.textTertiary
        proStatusLabel.textAlignment = .center
        proStatusLabel.text = "Tap to speak"
        proStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(proMicButton)
        view.addSubview(proStatusLabel)

        proMicBottomConstraint = proMicButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.xl
        )

        NSLayoutConstraint.activate([
            proMicButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            proMicBottomConstraint,
            proMicButton.widthAnchor.constraint(equalToConstant: 56),
            proMicButton.heightAnchor.constraint(equalToConstant: 56),

            proStatusLabel.topAnchor.constraint(equalTo: proMicButton.bottomAnchor, constant: DesignTokens.Spacing.xs),
            proStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        // Response area leaves room at bottom for the mic button
        let responseBottom = responseScrollView.bottomAnchor.constraint(equalTo: proMicButton.topAnchor, constant: -DesignTokens.Spacing.md)
        responseBottom.isActive = true

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
            micButton.toggleStatus()
            isRecording = false
            proSetState(.transcribing)
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
            updateProMicAppearance(recording: false)

        case .recording:
            proStatusLabel.text = "Listening..."
            proStatusLabel.textColor = DesignTokens.Colors.destructive
            updateProMicAppearance(recording: true)
            hideEmptyState()

        case .transcribing:
            proStatusLabel.text = "Transcribing..."
            proStatusLabel.textColor = DesignTokens.Colors.accent
            proMicButton.isEnabled = false
            updateProMicAppearance(recording: false)
        }
    }

    func updateProMicAppearance(recording: Bool) {
        var config = proMicButton.configuration ?? .filled()

        if recording {
            config.baseBackgroundColor = DesignTokens.Colors.destructive
            config.image = UIImage(systemName: "stop.fill")
            proMicButton.configuration = config

            proMicButton.layoutIfNeeded()
            proRecordingGradient.frame = proMicButton.bounds
            proRecordingGradient.cornerRadius = proMicButton.bounds.height / 2
            proRecordingGradient.opacity = 1

            let sweep = CABasicAnimation(keyPath: "locations")
            sweep.fromValue = [-0.5, -0.2, 0.0, 0.2, 0.5]
            sweep.toValue = [0.5, 0.8, 1.0, 1.2, 1.5]
            sweep.duration = 1.5
            sweep.repeatCount = .infinity
            sweep.autoreverses = true
            sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            proRecordingGradient.add(sweep, forKey: "sweep")
        } else {
            config.baseBackgroundColor = DesignTokens.Colors.accent
            config.image = UIImage(systemName: "mic.fill")
            proMicButton.configuration = config

            proRecordingGradient.removeAllAnimations()
            proRecordingGradient.opacity = 0
        }
    }

    /// Pro voice flow: transcription completes -> auto-send to AI
    func proHandleTranscription(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            proSetState(.idle)
            return
        }
        proSetState(.idle)
        sendMessage(text)
    }
}
