import UIKit

/// Reusable coach mark overlay that highlights a UI element with a tooltip.
/// Present over the current view controller to guide users through features.
final class CoachMarkOverlayView: UIView {

    var onDismiss: (() -> Void)?
    var onNext: (() -> Void)?

    private let dimView = UIView()
    private let tooltipContainer = UIView()
    private let arrowView = UIView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let nextButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    private let stepLabel = UILabel()

    private var currentStep: Int = 0
    private var totalSteps: Int = 0

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        // Dim background
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Tap to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dimTapped))
        dimView.addGestureRecognizer(tapGesture)

        // Tooltip
        tooltipContainer.backgroundColor = DesignTokens.Colors.surfacePrimary
        tooltipContainer.layer.cornerRadius = DesignTokens.Radii.lg
        DesignTokens.Shadows.apply(to: tooltipContainer.layer, elevation: .high)
        tooltipContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tooltipContainer)

        // Title
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        // Body
        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0

        // Step indicator
        stepLabel.font = DesignTokens.Typography.caption1
        stepLabel.textColor = DesignTokens.Colors.textTertiary

        // Next button
        var nextConfig = UIButton.Configuration.filled()
        nextConfig.baseBackgroundColor = DesignTokens.Colors.accent
        nextConfig.baseForegroundColor = .white
        nextConfig.cornerStyle = .capsule
        nextConfig.contentInsets = NSDirectionalEdgeInsets(
            top: DesignTokens.Spacing.sm,
            leading: DesignTokens.Spacing.lg,
            bottom: DesignTokens.Spacing.sm,
            trailing: DesignTokens.Spacing.lg
        )
        nextConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
            return outgoing
        }
        nextButton.configuration = nextConfig
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // Dismiss button
        dismissButton.setTitle("Skip tour", for: .normal)
        dismissButton.titleLabel?.font = DesignTokens.Typography.footnote
        dismissButton.setTitleColor(DesignTokens.Colors.textTertiary, for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        // Layout inside tooltip
        let buttonRow = UIStackView(arrangedSubviews: [stepLabel, UIView(), nextButton])
        buttonRow.axis = .horizontal
        buttonRow.alignment = .center
        buttonRow.spacing = DesignTokens.Spacing.sm

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, buttonRow, dismissButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        tooltipContainer.addSubview(stack)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            tooltipContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            tooltipContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            tooltipContainer.centerYAnchor.constraint(equalTo: centerYAnchor),

            stack.topAnchor.constraint(equalTo: tooltipContainer.topAnchor, constant: padding),
            stack.leadingAnchor.constraint(equalTo: tooltipContainer.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: tooltipContainer.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: tooltipContainer.bottomAnchor, constant: -padding),
        ])
    }

    // MARK: - Public API

    /// Configure the overlay with a coach mark and step info.
    func configure(mark: CoachMark, step: Int, of total: Int) {
        titleLabel.text = mark.title
        bodyLabel.text = mark.body
        currentStep = step
        totalSteps = total
        stepLabel.text = "\(step) of \(total)"

        let isLast = step == total
        var config = nextButton.configuration
        config?.title = isLast ? "Got it!" : "Next"
        nextButton.configuration = config

        dismissButton.isHidden = isLast
    }

    /// Show the overlay with a fade-in animation.
    func showAnimated(in parentView: UIView) {
        alpha = 0
        parentView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor),
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
        ])

        // Scale-in tooltip
        tooltipContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.tooltipContainer.transform = .identity
        }
    }

    /// Dismiss with fade-out.
    func dismissAnimated(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
            self.tooltipContainer.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    // MARK: - Actions

    @objc private func nextTapped() {
        onNext?()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }

    @objc private func dimTapped() {
        onDismiss?()
    }
}
