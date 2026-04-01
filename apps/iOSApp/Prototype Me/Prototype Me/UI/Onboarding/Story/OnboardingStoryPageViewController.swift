import UIKit

/// Reusable onboarding story page with a configurable visual animation area + title + subtitle.
final class OnboardingStoryPageViewController: UIViewController {

    var titleText: String = ""
    var subtitleText: String = ""
    var attributedSubtitle: NSAttributedString?
    var pageIndex: Int = 0
    var animationView: (UIView & StoryAnimatable)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var isVisible = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildLayout()

        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
        animateIn()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        animationView?.stopAnimations()
    }

    @objc private func appDidEnterBackground() {
        guard isVisible else { return }
        animationView?.stopAnimations()
    }

    @objc private func appWillEnterForeground() {
        guard isVisible else { return }
        // Reset text to starting state so animateIn replays cleanly
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        animateIn()
    }

    // MARK: - Layout

    private func buildLayout() {
        if let animView = animationView {
            animView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(animView)
            let hInset = animView.prefersFullWidth ? 0 : DesignTokens.Spacing.xl
            NSLayoutConstraint.activate([
                animView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.xxxl),
                animView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hInset),
                animView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hInset),
                animView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),
            ])
        }

        titleLabel.text = titleText
        titleLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        if let attributed = attributedSubtitle {
            // Create a centered copy of the attributed string
            let centered = NSMutableAttributedString(attributedString: attributed)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            centered.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: centered.length))
            subtitleLabel.attributedText = centered
        } else {
            subtitleLabel.text = subtitleText
            subtitleLabel.font = DesignTokens.Typography.body
            subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        }
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        let titleTopAnchor = animationView?.bottomAnchor ?? view.centerYAnchor
        let titleOffset: CGFloat = animationView != nil ? DesignTokens.Spacing.xl : -DesignTokens.Spacing.xxxl

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: titleTopAnchor, constant: titleOffset),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
        ])

        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
    }

    // MARK: - Animation

    private func animateIn() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            titleLabel.alpha = 1; titleLabel.transform = .identity
            subtitleLabel.alpha = 1; subtitleLabel.transform = .identity
            animationView?.playEntrance()
            return
        }

        animationView?.playEntrance()

        UIView.animate(withDuration: 0.4, delay: 0.3, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }

        UIView.animate(withDuration: 0.4, delay: 0.45, options: .curveEaseOut) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }
    }
}
