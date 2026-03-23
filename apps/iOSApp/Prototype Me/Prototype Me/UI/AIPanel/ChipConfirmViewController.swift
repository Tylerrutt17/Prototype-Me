import UIKit

/// Quick edit + confirm screen for a selected AI chip.
/// Pre-fills title/body/tier from the chip; user can tweak before committing.
class ChipConfirmViewController: BaseViewController {

    var chip: AiChip!
    var onConfirm: ((AiChip) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let actionBadge = UILabel()
    private let whyLabel = UILabel()
    private lazy var titleField = FormTextField(title: "Title", placeholder: "Directive or item title")
    private lazy var bodyField = FormTextView(title: "Details", minHeight: 100)
    private let confirmButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Confirm Suggestion", animated: false)
        navBar.setLeftButton(title: nil, systemImage: "xmark") { [weak self] in
            self?.onCancel?()
        }
        setupLayout()
        populateFromChip()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.xl
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Action badge
        actionBadge.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        actionBadge.textColor = DesignTokens.Colors.accent
        actionBadge.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.15)
        actionBadge.layer.cornerRadius = DesignTokens.Radii.sm
        actionBadge.clipsToBounds = true
        actionBadge.textAlignment = .center

        // Why label
        whyLabel.font = DesignTokens.Typography.callout
        whyLabel.textColor = DesignTokens.Colors.textSecondary
        whyLabel.numberOfLines = 0

        // Confirm button
        var confirmConfig = UIButton.Configuration.filled()
        confirmConfig.title = "Accept Suggestion"
        confirmConfig.image = UIImage(systemName: "checkmark.circle.fill")
        confirmConfig.imagePadding = DesignTokens.Spacing.sm
        confirmConfig.baseBackgroundColor = DesignTokens.Colors.accent
        confirmConfig.baseForegroundColor = DesignTokens.Colors.textPrimary
        confirmConfig.cornerStyle = .large
        confirmConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        confirmButton.configuration = confirmConfig
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        // Cancel button
        var cancelConfig = UIButton.Configuration.plain()
        cancelConfig.title = "Skip"
        cancelConfig.baseForegroundColor = DesignTokens.Colors.textSecondary
        cancelButton.configuration = cancelConfig
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        // Button stack
        let buttonStack = UIStackView(arrangedSubviews: [confirmButton, cancelButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = DesignTokens.Spacing.sm
        buttonStack.alignment = .fill

        contentStack.addArrangedSubview(actionBadge)
        contentStack.addArrangedSubview(whyLabel)
        contentStack.addArrangedSubview(titleField)
        contentStack.addArrangedSubview(bodyField)
        contentStack.addArrangedSubview(buttonStack)

        // Set custom spacing
        contentStack.setCustomSpacing(DesignTokens.Spacing.md, after: actionBadge)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor, constant: DesignTokens.Spacing.lg),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: DesignTokens.Spacing.xl),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -DesignTokens.Spacing.xxxl),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -2 * DesignTokens.Spacing.xl),
        ])
    }

    // MARK: - Populate

    private func populateFromChip() {
        let actionText: String = switch chip.action {
        case .createDirective:  "  New Directive  "
        case .updateDirective:  "  Update Directive  "
        case .createNote:       "  New Note  "
        case .activateMode:     "  Activate Mode  "
        case .addSchedule:      "  Add Schedule  "
        }
        actionBadge.text = actionText

        whyLabel.text = chip.subtitle

        titleField.textField.text = chip.prefillTitle ?? chip.title
        bodyField.textView.text = chip.prefillBody ?? ""

        // For mode activation, hide body + title since it's a simple toggle
        if chip.action == .activateMode {
            titleField.isHidden = true
            bodyField.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        var accepted = chip!
        accepted.status = .accepted
        onConfirm?(accepted)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}
