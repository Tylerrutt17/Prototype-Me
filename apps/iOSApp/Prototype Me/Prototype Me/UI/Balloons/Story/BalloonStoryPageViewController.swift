import UIKit

/// Protocol for injectable animation views used in story pages.
protocol StoryAnimatable: UIView {
    func playEntrance()
    func stopAnimations()
}

/// Reusable story page with a configurable visual animation area + title + subtitle.
final class BalloonStoryPageViewController: UIViewController {

    var titleText: String = ""
    var subtitleText: String = ""
    var pageIndex: Int = 0
    var animationView: (UIView & StoryAnimatable)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        animationView?.stopAnimations()
    }

    // MARK: - Layout

    private func buildLayout() {
        // Animation visual area
        if let animView = animationView {
            animView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(animView)
            NSLayoutConstraint.activate([
                animView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.xxxl),
                animView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
                animView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),
                animView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),
            ])
        }

        titleLabel.text = titleText
        titleLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = subtitleText
        subtitleLabel.font = DesignTokens.Typography.body
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
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

        // Start invisible for entrance animation
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

        // Visual entrance
        animationView?.playEntrance()

        // Title slides up
        UIView.animate(withDuration: 0.4, delay: 0.3, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }

        // Subtitle slides up
        UIView.animate(withDuration: 0.4, delay: 0.45, options: .curveEaseOut) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }
    }
}
