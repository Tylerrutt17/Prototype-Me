import UIKit

/// Onboarding intro with 4 swipeable value-prop slides, page dots, and Next/Skip buttons.
final class IntroPageViewController: UIViewController {

    var onFinished: (() -> Void)?

    // MARK: - Slide Data

    private struct SlideData {
        let icon: String
        let title: String
        let subtitle: String
        let accentColor: UIColor
    }

    private let slides: [SlideData] = [
        SlideData(icon: "sparkles", title: "Your Personal OS", subtitle: "Organize your life with directives, situational modes, and notes.", accentColor: DesignTokens.Colors.accent),
        SlideData(icon: "brain.head.profile", title: "AI Drafts, You Confirm", subtitle: "AI suggests structure. You review, edit, and own every decision.", accentColor: DesignTokens.Colors.accentSecondary),
        SlideData(icon: "balloon.fill", title: "Visual Accountability", subtitle: "Balloons rise with urgency. Keep them pumped. Stay on track.", accentColor: DesignTokens.Colors.accentTertiary),
        SlideData(icon: "scope", title: "Focus on What Matters", subtitle: "One launch surface. Your situational modes, your schedule, your momentum.", accentColor: DesignTokens.Colors.accent),
    ]

    // MARK: - UI

    private var pageVC: UIPageViewController!
    private let pageControl = UIPageControl()
    private let nextButton = AppButton(title: "Next")
    private let skipButton = UIButton(type: .system)
    private var currentIndex = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background

        setupPageViewController()
        setupControls()
    }

    // MARK: - Page VC

    private func setupPageViewController() {
        pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageVC.dataSource = self
        pageVC.delegate = self

        addChild(pageVC)
        view.addSubview(pageVC.view)
        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        pageVC.didMove(toParent: self)

        let firstSlide = makeSlideVC(at: 0)
        pageVC.setViewControllers([firstSlide], direction: .forward, animated: false)
    }

    // MARK: - Controls

    private func setupControls() {
        // Page control
        pageControl.numberOfPages = slides.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = DesignTokens.Colors.textTertiary
        pageControl.currentPageIndicatorTintColor = DesignTokens.Colors.accent
        pageControl.isUserInteractionEnabled = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)

        // Next / Get Started button
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextButton)

        // Skip button
        skipButton.setTitle("Skip", for: .normal)
        skipButton.titleLabel?.font = DesignTokens.Typography.subheadline
        skipButton.setTitleColor(DesignTokens.Colors.textSecondary, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -DesignTokens.Spacing.xl),

            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.xxl),
            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),

            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.lg),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])
    }

    // MARK: - Actions

    @objc private func nextTapped() {
        if currentIndex < slides.count - 1 {
            currentIndex += 1
            let nextSlide = makeSlideVC(at: currentIndex)
            pageVC.setViewControllers([nextSlide], direction: .forward, animated: true)
            updateControls()
        } else {
            Haptics.medium()
            onFinished?()
        }
    }

    @objc private func skipTapped() {
        onFinished?()
    }

    private func updateControls() {
        pageControl.currentPage = currentIndex
        let isLast = currentIndex == slides.count - 1
        nextButton.setTitle(isLast ? "Get Started" : "Next", for: .normal)

        if isLast && !UIAccessibility.isReduceMotionEnabled {
            startButtonPulse()
        }
    }

    private func startButtonPulse() {
        UIView.animate(
            withDuration: 1.5,
            delay: 0,
            options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]
        ) {
            self.nextButton.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        }
    }

    // MARK: - Slide Factory

    private func makeSlideVC(at index: Int) -> IntroSlideViewController {
        let slide = slides[index]
        let vc = IntroSlideViewController()
        vc.iconName = slide.icon
        vc.titleText = slide.title
        vc.subtitleText = slide.subtitle
        vc.accentColor = slide.accentColor
        vc.pageIndex = index
        return vc
    }
}

// MARK: - UIPageViewControllerDataSource

extension IntroPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let slideVC = viewController as? IntroSlideViewController, slideVC.pageIndex > 0 else { return nil }
        return makeSlideVC(at: slideVC.pageIndex - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let slideVC = viewController as? IntroSlideViewController, slideVC.pageIndex < slides.count - 1 else { return nil }
        return makeSlideVC(at: slideVC.pageIndex + 1)
    }
}

// MARK: - UIPageViewControllerDelegate

extension IntroPageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let slideVC = pageViewController.viewControllers?.first as? IntroSlideViewController else { return }
        currentIndex = slideVC.pageIndex
        updateControls()
    }
}

// MARK: - IntroSlideViewController

final class IntroSlideViewController: UIViewController {

    var iconName: String = ""
    var titleText: String = ""
    var subtitleText: String = ""
    var accentColor: UIColor = DesignTokens.Colors.accent
    var pageIndex: Int = 0

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background
        buildLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    private func buildLayout() {
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .ultraLight)
        iconView.image = UIImage(systemName: iconName, withConfiguration: config)
        iconView.tintColor = accentColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

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

        view.addSubview(iconView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -view.bounds.height * 0.15),
            iconView.widthAnchor.constraint(equalToConstant: 100),
            iconView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DesignTokens.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
        ])

        // Start invisible for entrance animation
        iconView.alpha = 0
        iconView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
    }

    private func animateIn() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            iconView.alpha = 1; iconView.transform = .identity
            titleLabel.alpha = 1; titleLabel.transform = .identity
            subtitleLabel.alpha = 1; subtitleLabel.transform = .identity
            return
        }

        // Icon: spring scale-in
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3) {
            self.iconView.alpha = 1
            self.iconView.transform = .identity
        }

        // Title: slide up
        UIView.animate(withDuration: 0.4, delay: 0.2, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }

        // Subtitle: slide up
        UIView.animate(withDuration: 0.4, delay: 0.35, options: .curveEaseOut) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }
    }
}
