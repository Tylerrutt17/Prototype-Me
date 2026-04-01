import UIKit

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(renderingMode)
    }
}

/// Lightweight button descriptor for `AppNavBar`.
struct NavBarButton {
    let systemImage: String?
    let assetImage: String?
    let title: String?
    let action: () -> Void

    init(systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.assetImage = nil
        self.title = nil
        self.action = action
    }

    init(assetImage: String, action: @escaping () -> Void) {
        self.systemImage = nil
        self.assetImage = assetImage
        self.title = nil
        self.action = action
    }

    init(title: String, action: @escaping () -> Void) {
        self.systemImage = nil
        self.assetImage = nil
        self.title = title
        self.action = action
    }
}

/// Custom navigation bar that replaces the system `UINavigationBar`.
/// Provides smooth title fade-in animations and consistent styling.
final class AppNavBar: UIView {

    // MARK: - Public

    var onBackTapped: (() -> Void)?

    // MARK: - Subviews

    private let contentView = UIView()
    private let backButton = UIButton(type: .system)
    private let leftButtonView = UIButton(type: .system)
    private let titleLabel = UILabel()
    private var customTitleView: UIView?
    private let rightStack = UIStackView()
    private let separator = UIView()

    private var leftButtonAction: (() -> Void)?
    private var rightButtonActions: [() -> Void] = []

    private static let contentHeight: CGFloat = 44

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
        backgroundColor = DesignTokens.Colors.background

        // Content view — sits below the safe area
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        // Back button
        let chevron = UIImage(systemName: "chevron.left",
                              withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        var btnConfig = UIButton.Configuration.plain()
        btnConfig.image = chevron
        btnConfig.baseForegroundColor = DesignTokens.Colors.accent
        btnConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16)
        backButton.configuration = btnConfig
        backButton.isHidden = true
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        contentView.addSubview(backButton)

        // Left button (Cancel, etc.)
        leftButtonView.tintColor = DesignTokens.Colors.accent
        leftButtonView.titleLabel?.font = DesignTokens.Typography.body
        leftButtonView.isHidden = true
        leftButtonView.translatesAutoresizingMaskIntoConstraints = false
        leftButtonView.addTarget(self, action: #selector(leftTapped), for: .touchUpInside)
        contentView.addSubview(leftButtonView)

        // Title label
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Right stack
        rightStack.axis = .horizontal
        rightStack.spacing = DesignTokens.Spacing.lg
        rightStack.alignment = .center
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rightStack)

        // Separator
        separator.backgroundColor = DesignTokens.Colors.separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        let padding: CGFloat = DesignTokens.Spacing.lg

        NSLayoutConstraint.activate([
            // Content view pinned below safe area, 44pt tall
            contentView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            // Ensure minimum top padding for modals where safe area is zero
            contentView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: DesignTokens.Spacing.lg),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.heightAnchor.constraint(equalToConstant: Self.contentHeight),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Back button — full bar height with 44pt min width for easy tapping
            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            backButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            backButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            backButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            // Left button (after back button)
            leftButtonView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            leftButtonView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Title label — centered with insets so it doesn't overlap buttons
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 72),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -72),

            // Right stack
            rightStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            rightStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Separator
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    // MARK: - Public API

    /// Sets the title with an optional fade animation.
    func setTitle(_ title: String?, animated: Bool = true) {
        guard animated else {
            titleLabel.text = title
            titleLabel.alpha = title != nil ? 1 : 0
            titleLabel.transform = .identity
            return
        }

        // Same text — no animation needed
        if titleLabel.text == title { return }

        if titleLabel.alpha > 0 {
            // Fade out existing, then fade in new
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseIn) {
                self.titleLabel.alpha = 0
                self.titleLabel.transform = CGAffineTransform(translationX: 0, y: 4)
            } completion: { _ in
                self.titleLabel.text = title
                guard title != nil else { return }
                UIView.animate(withDuration: 0.25, delay: 0.05, options: .curveEaseOut) {
                    self.titleLabel.alpha = 1
                    self.titleLabel.transform = .identity
                }
            }
        } else {
            // First appearance — just fade in
            titleLabel.text = title
            titleLabel.transform = CGAffineTransform(translationX: 0, y: 4)
            guard title != nil else { return }
            UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut) {
                self.titleLabel.alpha = 1
                self.titleLabel.transform = .identity
            }
        }
    }

    /// Replaces the title label with a custom view (e.g. segmented control).
    func setTitleView(_ view: UIView?) {
        customTitleView?.removeFromSuperview()
        customTitleView = nil
        titleLabel.isHidden = view != nil

        guard let view else { return }
        customTitleView = view
        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)

        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 72),
            view.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -72),
        ])
    }

    /// Sets or clears the left button (e.g. Cancel for modals).
    func setLeftButton(title: String?, systemImage: String?, action: @escaping () -> Void) {
        leftButtonAction = action
        if let title {
            leftButtonView.setTitle(title, for: .normal)
            leftButtonView.setImage(nil, for: .normal)
        } else if let systemImage {
            leftButtonView.setTitle(nil, for: .normal)
            leftButtonView.setImage(UIImage(systemName: systemImage), for: .normal)
        }
        leftButtonView.isHidden = false
    }

    /// Clears the left button.
    func clearLeftButton() {
        leftButtonView.isHidden = true
        leftButtonAction = nil
    }

    /// Sets the right-side buttons.
    func setRightButtons(_ buttons: [NavBarButton]) {
        rightStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rightButtonActions = buttons.map { $0.action }

        for (index, btn) in buttons.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.tintColor = DesignTokens.Colors.accent

            if let systemImage = btn.systemImage {
                let config = UIImage.SymbolConfiguration(weight: .medium)
                button.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)
            } else if let assetImage = btn.assetImage {
                let size: CGFloat = 22
                let img = UIImage(named: assetImage)?
                    .withRenderingMode(.alwaysTemplate)
                    .resized(to: CGSize(width: size, height: size))
                button.setImage(img, for: .normal)
            } else if let title = btn.title {
                button.setTitle(title, for: .normal)
                button.titleLabel?.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
            }

            button.addTarget(self, action: #selector(rightButtonTapped(_:)), for: .touchUpInside)
            rightStack.addArrangedSubview(button)
        }
    }

    /// Shows or hides the back chevron.
    func setShowsBackButton(_ shows: Bool) {
        backButton.isHidden = !shows
    }

    // MARK: - Actions

    @objc private func backTapped() {
        onBackTapped?()
    }

    @objc private func leftTapped() {
        leftButtonAction?()
    }

    @objc private func rightButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < rightButtonActions.count else { return }
        rightButtonActions[index]()
    }
}
