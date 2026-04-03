import UIKit

/// Bottom-sheet AI panel: text input → thinking animation → chip suggestions + quota display.
/// Presented modally with `.pageSheet` detent from the Focus tab.
class AIPanelViewController: UIViewController {

    // MARK: - Callbacks

    var apiClient: APIClient?
    var onChipSelected: ((AiChip) -> Void)?
    var onDismissed: (() -> Void)?
    var onUpgradeTapped: (() -> Void)?

    // MARK: - State

    private enum PanelState {
        case idle           // Text field visible, waiting for input
        case thinking       // Thinking dots animation
        case results        // Chips displayed
    }

    private var state: PanelState = .idle {
        didSet { transition(to: state) }
    }

    private var chips: [AiChip] = []
    var initialQuota: UsageQuota = UsageQuota(dailyLimit: 5, dailyUsed: 0, resetAt: Date())
    var isPro: Bool = false
    private lazy var quota: UsageQuota = initialQuota

    // MARK: - UI

    private let grabber = UIView()
    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let quotaLabel = UILabel()
    private let inputContainer = UIView()
    private let textField = UITextField()
    private let micButton = VoiceInputButton()
    private let sendButton = UIButton(type: .system)
    private let thinkingView = ThinkingAnimationView()
    private let thinkingLabel = UILabel()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, AiChip>!
    private let emptyQuotaView = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.surfacePrimary

        setupGrabber()
        setupHeader()
        setupInput()
        setupThinking()
        setupCollectionView()
        setupEmptyQuota()
        configureDataSource()

        // Hide mic for free users
        micButton.isHidden = !isPro

        transition(to: .idle)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Stop recording if active
        if micButton.isRecording {
            micButton.toggleStatus()
            updateMicAppearance(recording: false)
        }
        micButton.cleanupAudioFile()
        // Mark any remaining suggested chips as dismissed
        if chips.contains(where: { $0.status == .suggested }) {
            onDismissed?()
        }
    }

    // MARK: - Setup

    private func setupGrabber() {
        grabber.backgroundColor = DesignTokens.Colors.textTertiary
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grabber)

        NSLayoutConstraint.activate([
            grabber.topAnchor.constraint(equalTo: view.topAnchor, constant: DesignTokens.Spacing.sm),
            grabber.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
        ])
    }

    private func setupHeader() {
        titleLabel.text = "AI Suggestions"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        quotaLabel.font = DesignTokens.Typography.caption1
        quotaLabel.textColor = DesignTokens.Colors.textSecondary
        updateQuotaLabel()

        headerStack.axis = .horizontal
        headerStack.alignment = .lastBaseline
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(UIView()) // spacer
        headerStack.addArrangedSubview(quotaLabel)
        view.addSubview(headerStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: DesignTokens.Spacing.lg),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])
    }

    private let bigMicButton = UIButton(type: .system)
    private let micLabel = UILabel()

    private func setupInput() {
        // Text input bar
        inputContainer.backgroundColor = DesignTokens.Colors.surfaceSecondary
        inputContainer.layer.cornerRadius = DesignTokens.Radii.xl
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainer)

        textField.placeholder = "What should I work on?"
        textField.font = DesignTokens.Typography.body
        textField.textColor = DesignTokens.Colors.textPrimary
        textField.tintColor = DesignTokens.Colors.accent
        textField.returnKeyType = .send
        textField.delegate = self
        textField.attributedPlaceholder = NSAttributedString(
            string: "What should I work on?",
            attributes: [.foregroundColor: DesignTokens.Colors.textTertiary]
        )
        textField.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(textField)

        var sendConfig = UIButton.Configuration.filled()
        sendConfig.image = UIImage(systemName: "arrow.up.circle.fill")
        sendConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24)
        sendConfig.baseBackgroundColor = .clear
        sendConfig.baseForegroundColor = DesignTokens.Colors.accent
        sendConfig.contentInsets = .zero
        sendButton.configuration = sendConfig
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(sendButton)

        // Big mic button below text field
        let micSize: CGFloat = 64
        bigMicButton.translatesAutoresizingMaskIntoConstraints = false
        var micConfig = UIButton.Configuration.filled()
        micConfig.image = UIImage(systemName: "mic.fill")
        micConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        micConfig.baseBackgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        micConfig.baseForegroundColor = DesignTokens.Colors.accent
        micConfig.cornerStyle = .capsule
        micConfig.contentInsets = .zero
        bigMicButton.configuration = micConfig
        bigMicButton.layer.cornerRadius = micSize / 2
        bigMicButton.clipsToBounds = true
        bigMicButton.addTarget(self, action: #selector(bigMicTapped), for: .touchUpInside)
        view.addSubview(bigMicButton)

        micLabel.text = "Tap to speak"
        micLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        micLabel.textColor = DesignTokens.Colors.textTertiary
        micLabel.textAlignment = .center
        micLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(micLabel)

        // Wire up the existing VoiceInputButton for recording logic
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.isHidden = true // hidden — we use bigMicButton as the visual, micButton for logic
        view.addSubview(micButton)
        micButton.onTranscription = { [weak self] text in
            // Apple transcription — used for free users or as fallback
            guard let self else { return }
            print("[AI Mic] Apple transcription received. isPro: \(self.isPro)")
            if !self.isPro {
                self.handleFinalText(text)
            }
            // Pro users wait for Whisper result from onAudioRecorded
        }
        micButton.onPartialResult = { [weak self] text in
            self?.textField.text = text
            self?.micLabel.text = "Listening..."
        }
        micButton.onAudioRecorded = { [weak self] fileURL in
            guard let self else { return }
            print("[AI Mic] Audio recorded at \(fileURL.path). isPro: \(self.isPro)")
            guard self.isPro else { return }
            self.transcribeWithWhisper(fileURL: fileURL)
        }
        micButton.onError = { [weak self] message in
            self?.updateMicAppearance(recording: false)
            let alert = UIAlertController(title: "Voice Input", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }

        NSLayoutConstraint.activate([
            inputContainer.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: DesignTokens.Spacing.lg),
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            inputContainer.heightAnchor.constraint(equalToConstant: 48),

            textField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: DesignTokens.Spacing.lg),
            textField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -DesignTokens.Spacing.sm),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -DesignTokens.Spacing.sm),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 32),
            sendButton.heightAnchor.constraint(equalToConstant: 32),

            bigMicButton.topAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: DesignTokens.Spacing.xl),
            bigMicButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bigMicButton.widthAnchor.constraint(equalToConstant: micSize),
            bigMicButton.heightAnchor.constraint(equalToConstant: micSize),

            micLabel.topAnchor.constraint(equalTo: bigMicButton.bottomAnchor, constant: DesignTokens.Spacing.sm),
            micLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupThinking() {
        thinkingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thinkingView)

        thinkingLabel.text = "Analyzing your patterns…"
        thinkingLabel.font = DesignTokens.Typography.footnote
        thinkingLabel.textColor = DesignTokens.Colors.textSecondary
        thinkingLabel.textAlignment = .center
        thinkingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thinkingLabel)

        NSLayoutConstraint.activate([
            thinkingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            thinkingView.topAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: DesignTokens.Spacing.xxxl),
            thinkingLabel.topAnchor.constraint(equalTo: thinkingView.bottomAnchor, constant: DesignTokens.Spacing.md),
            thinkingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(100)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = DesignTokens.Spacing.md
            section.contentInsets = NSDirectionalEdgeInsets(
                top: DesignTokens.Spacing.md,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.xxxl,
                trailing: DesignTokens.Spacing.lg
            )
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: DesignTokens.Spacing.md),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupEmptyQuota() {
        emptyQuotaView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyQuotaView)

        let icon = UIImageView(image: UIImage(systemName: "sparkle.magnifyingglass"))
        icon.tintColor = DesignTokens.Colors.textTertiary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "You've used all your AI suggestions for today."
        label.font = DesignTokens.Typography.callout
        label.textColor = DesignTokens.Colors.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0

        let upgradeButton = UIButton(type: .system)
        var btnConfig = UIButton.Configuration.filled()
        btnConfig.title = "Upgrade to Pro"
        btnConfig.baseBackgroundColor = DesignTokens.Colors.accent
        btnConfig.baseForegroundColor = DesignTokens.Colors.textPrimary
        btnConfig.cornerStyle = .capsule
        btnConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24)
        upgradeButton.configuration = btnConfig
        upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, label, upgradeButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyQuotaView.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),

            emptyQuotaView.topAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: DesignTokens.Spacing.xxxl),
            emptyQuotaView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            emptyQuotaView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),

            stack.topAnchor.constraint(equalTo: emptyQuotaView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: emptyQuotaView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: emptyQuotaView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: emptyQuotaView.bottomAnchor),
        ])
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let cellReg = UICollectionView.CellRegistration<ChipCardCell, AiChip> { cell, _, chip in
            cell.configure(with: chip)
        }

        dataSource = UICollectionViewDiffableDataSource<Int, AiChip>(collectionView: collectionView) { collectionView, indexPath, chip in
            collectionView.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: chip)
        }
    }

    private func applyChipsSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, AiChip>()
        snapshot.appendSections([0])
        snapshot.appendItems(chips, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - State Transitions

    private func transition(to newState: PanelState) {
        let isQuotaEmpty = quota.remaining <= 0

        inputContainer.isHidden = false
        thinkingView.isHidden = true
        thinkingLabel.isHidden = true
        collectionView.isHidden = true
        emptyQuotaView.isHidden = true

        switch newState {
        case .idle:
            bigMicButton.isHidden = false
            micLabel.isHidden = false
            if isQuotaEmpty {
                emptyQuotaView.isHidden = false
                inputContainer.alpha = 0.5
                textField.isEnabled = false
                sendButton.isEnabled = false
                bigMicButton.isEnabled = false
                bigMicButton.alpha = 0.5
            } else {
                textField.isEnabled = true
                sendButton.isEnabled = true
                inputContainer.alpha = 1
                bigMicButton.isEnabled = true
                bigMicButton.alpha = 1
            }
            thinkingView.stopAnimating()

        case .thinking:
            bigMicButton.isHidden = true
            micLabel.isHidden = true
            thinkingView.isHidden = false
            thinkingLabel.isHidden = false
            thinkingView.startAnimating()
            textField.isEnabled = false
            sendButton.isEnabled = false
            inputContainer.alpha = 0.5

        case .results:
            bigMicButton.isHidden = true
            micLabel.isHidden = true
            collectionView.isHidden = false
            thinkingView.stopAnimating()
            textField.isEnabled = true
            sendButton.isEnabled = true
            inputContainer.alpha = 1
        }
    }

    // MARK: - Actions

    @objc private func sendTapped() {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        textField.resignFirstResponder()
        state = .thinking

        Task {
            do {
                guard let apiClient else { throw NSError(domain: "AIPanelVC", code: 0) }

                let response: AISuggestResponse = try await apiClient.post(
                    "/v1/ai/suggest",
                    body: ["context": text],
                    timeout: APIClient.Timeout.ai
                )

                await MainActor.run {
                    self.chips = response.chips
                    if let remaining = response.remainingQuota {
                        self.quota = UsageQuota(
                            dailyLimit: self.quota.dailyLimit,
                            dailyUsed: self.quota.dailyLimit - remaining,
                            resetAt: self.quota.resetAt
                        )
                    }
                    self.updateQuotaLabel()
                    self.applyChipsSnapshot()
                    self.state = .results
                    self.animateChipsIn()
                }
            } catch {
                await MainActor.run {
                    self.state = .idle
                    Haptics.error()
                    // Show error inline
                    let alert = UIAlertController(title: "AI Error", message: "Couldn't get suggestions. Try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - API Response Types

    private struct AISuggestResponse: Decodable {
        let chips: [AiChip]
        let remainingQuota: Int?
        let resetAt: String?
    }

    @objc private func bigMicTapped() {
        if micButton.isRecording {
            // Stop recording
            micButton.toggleStatus()
            updateMicAppearance(recording: false)
        } else {
            // Start recording
            micButton.toggleStatus()
            updateMicAppearance(recording: true)
        }
    }

    private func updateMicAppearance(recording: Bool) {
        var config = bigMicButton.configuration ?? .filled()
        if recording {
            config.baseBackgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.15)
            config.baseForegroundColor = DesignTokens.Colors.destructive
            config.image = UIImage(systemName: "stop.fill")
            micLabel.text = "Listening..."
            micLabel.textColor = DesignTokens.Colors.destructive

            // Pulse animation — allowUserInteraction so taps still register
            UIView.animate(withDuration: 0.8, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]) {
                self.bigMicButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
        } else {
            config.baseBackgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
            config.baseForegroundColor = DesignTokens.Colors.accent
            config.image = UIImage(systemName: "mic.fill")
            micLabel.text = "Tap to speak"
            micLabel.textColor = DesignTokens.Colors.textTertiary

            bigMicButton.layer.removeAllAnimations()
            bigMicButton.transform = .identity
        }
        bigMicButton.configuration = config
    }

    private func handleFinalText(_ text: String) {
        updateMicAppearance(recording: false)
        guard !text.isEmpty else { return }
        textField.text = text
        micLabel.text = "Tap to speak"
    }

    private func transcribeWithWhisper(fileURL: URL) {
        updateMicAppearance(recording: false)
        micLabel.text = "Transcribing..."
        bigMicButton.isEnabled = false

        Task {
            do {
                guard let apiClient else { throw NSError(domain: "AI", code: 0) }

                // Read audio file and encode as base64
                let audioData = try Data(contentsOf: fileURL)
                let base64Audio = audioData.base64EncodedString()

                let response: WhisperResponse = try await apiClient.post(
                    "/v1/ai/transcribe",
                    body: ["audio": base64Audio],
                    timeout: APIClient.Timeout.ai
                )

                await MainActor.run {
                    self.textField.text = response.text
                    self.micLabel.text = "Tap to speak"
                    self.bigMicButton.isEnabled = true
                    self.micButton.cleanupAudioFile()
                }
            } catch {
                print("[AI] Whisper transcription failed: \(error)")
                await MainActor.run {
                    // Fall back to whatever Apple gave us
                    self.micLabel.text = "Tap to speak"
                    self.bigMicButton.isEnabled = true
                    self.micButton.cleanupAudioFile()
                }
            }
        }
    }

    private struct WhisperResponse: Decodable {
        let text: String
    }

    @objc private func upgradeTapped() {
        onUpgradeTapped?()
    }

    private func updateQuotaLabel() {
        quotaLabel.text = "\(quota.remaining)/\(quota.dailyLimit) left today"
        quotaLabel.textColor = quota.remaining <= 2
            ? DesignTokens.Colors.warning
            : DesignTokens.Colors.textSecondary
    }

    // MARK: - Animations

    private func animateChipsIn() {
        for (index, cell) in collectionView.visibleCells.enumerated() {
            cell.alpha = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 30)
            UIView.animate(
                withDuration: 0.35,
                delay: 0.08 * Double(index),
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: .curveEaseOut
            ) {
                cell.alpha = 1
                cell.transform = .identity
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension AIPanelViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let chip = dataSource.itemIdentifier(for: indexPath) else { return }
        onChipSelected?(chip)
    }
}

// MARK: - UITextFieldDelegate

extension AIPanelViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}

// MARK: - ChipCardCell

private final class ChipCardCell: UICollectionViewCell {

    private let actionIcon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let destinationPill = UILabel()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .low)

        // Action icon
        actionIcon.contentMode = .scaleAspectFit
        actionIcon.tintColor = DesignTokens.Colors.accent

        // Title
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 2

        // Subtitle ("why")
        subtitleLabel.font = DesignTokens.Typography.footnote
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.numberOfLines = 2

        // Destination pill
        destinationPill.font = DesignTokens.Typography.caption2
        destinationPill.textColor = DesignTokens.Colors.accent
        destinationPill.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.15)
        destinationPill.layer.cornerRadius = DesignTokens.Radii.sm
        destinationPill.clipsToBounds = true
        destinationPill.textAlignment = .center

        // Chevron
        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit

        // Layout
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xs

        let topRow = UIStackView(arrangedSubviews: [actionIcon, textStack, chevron])
        topRow.axis = .horizontal
        topRow.spacing = DesignTokens.Spacing.md
        topRow.alignment = .center

        let mainStack = UIStackView(arrangedSubviews: [topRow, destinationPill])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.sm
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            actionIcon.widthAnchor.constraint(equalToConstant: 28),
            actionIcon.heightAnchor.constraint(equalToConstant: 28),
            chevron.widthAnchor.constraint(equalToConstant: 12),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with chip: AiChip) {
        titleLabel.text = chip.title
        subtitleLabel.text = chip.subtitle
        destinationPill.text = "  \(chip.destination)  "

        let iconName: String = switch chip.action {
        case .createDirective:  "plus.circle.fill"
        case .updateDirective:  "pencil.circle.fill"
        case .createNote:       "doc.badge.plus"
        case .activateMode:     "bolt.circle.fill"
        case .addSchedule:      "calendar.badge.plus"
        }
        actionIcon.image = UIImage(systemName: iconName)

        let tint: UIColor = switch chip.action {
        case .createDirective, .createNote: DesignTokens.Colors.accent
        case .updateDirective:              DesignTokens.Colors.accentTertiary
        case .activateMode:                 DesignTokens.Colors.accentSecondary
        case .addSchedule:                  DesignTokens.Colors.accent
        }
        actionIcon.tintColor = tint
    }
}
