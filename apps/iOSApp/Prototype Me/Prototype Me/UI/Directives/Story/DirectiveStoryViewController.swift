import UIKit

/// Full-screen story experience explaining the Directives concept through animated pages.
final class DirectiveStoryViewController: UIViewController {

    // MARK: - Page Config

    private struct PageConfig {
        let title: String
        let subtitle: String
        let visualType: VisualType

        enum VisualType {
            case wave
            case experiment
            case directiveTypes
            case evolution
            case tools
            case pattern
            case framework
        }
    }

    private let pages: [PageConfig] = [
        PageConfig(
            title: "Your worst days aren't random",
            subtitle: "There's a reason some days you're off. What if you could figure out what's dragging you down — and stop it from happening?",
            visualType: .wave
        ),
        PageConfig(
            title: "You don't think your way there. You test your way there.",
            subtitle: "Self-improvement isn't about planning the perfect routine. It's about trying things and seeing what actually keeps the lows away.",
            visualType: .experiment
        ),
        PageConfig(
            title: "That's what directives are",
            subtitle: "Your experiments. A habit to try, a rule to follow, a reminder to keep, a principle to test. Flexible, not rigid.",
            visualType: .directiveTypes
        ),
        PageConfig(
            title: "Some will stick. Some won't.",
            subtitle: "And that's the whole point. Archive what doesn't work, double down on what does. No guilt, no broken streaks, no judgment.",
            visualType: .evolution
        ),
        PageConfig(
            title: "The system keeps you honest",
            subtitle: "Balloons keep things visible. Schedules build consistency. History shows what you actually did — not what you think you did.",
            visualType: .tools
        ),
        PageConfig(
            title: "Over time, a pattern emerges",
            subtitle: "The habits that stuck. The rules you actually follow. The things that keep working. Those aren't directives anymore — those are you.",
            visualType: .pattern
        ),
        PageConfig(
            title: "That's your Framework",
            subtitle: "The steadiest version of you, discovered through real experience. Not guessed. Not copied. Earned.",
            visualType: .framework
        ),
    ]

    // MARK: - UI

    private var pageVC: UIPageViewController!
    private let pageControl = UIPageControl()
    private let nextButton = AppButton(title: "Next")
    private let skipButton = UIButton(type: .system)
    private var currentIndex = 0
    private var isTransitioning = false

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.03, green: 0.05, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.06, green: 0.04, blue: 0.18, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1.0).cgColor,
            UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0).cgColor,
        ]
        layer.locations = [0.0, 0.35, 0.7, 1.0]
        return layer
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.addSublayer(gradientLayer)
        setupPageViewController()
        setupControls()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = view.bounds
        CATransaction.commit()
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

        let firstPage = makePageVC(at: 0)
        pageVC.setViewControllers([firstPage], direction: .forward, animated: false)
    }

    // MARK: - Controls

    private func setupControls() {
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = DesignTokens.Colors.textTertiary
        pageControl.currentPageIndicatorTintColor = DesignTokens.Colors.accent
        pageControl.isUserInteractionEnabled = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)

        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextButton)

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
        guard !isTransitioning else { return }
        if currentIndex < pages.count - 1 {
            isTransitioning = true
            currentIndex += 1
            let nextPage = makePageVC(at: currentIndex)
            pageVC.setViewControllers([nextPage], direction: .forward, animated: true) { [weak self] _ in
                self?.isTransitioning = false
            }
            updateControls()
            Haptics.selection()
        } else {
            finish()
        }
    }

    @objc private func skipTapped() {
        finish()
    }

    private func finish() {
        Haptics.medium()
        dismiss(animated: true)
    }

    private func updateControls() {
        pageControl.currentPage = currentIndex
        let isLast = currentIndex == pages.count - 1
        nextButton.setTitle(isLast ? "Got it!" : "Next", for: .normal)

        switch pages[currentIndex].visualType {
        case .framework: Haptics.success()
        case .evolution: Haptics.warning()
        default: break
        }

        if isLast && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(
                withDuration: 1.5,
                delay: 0,
                options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]
            ) {
                self.nextButton.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
            }
        } else {
            nextButton.layer.removeAllAnimations()
            nextButton.transform = .identity
        }
    }

    // MARK: - Page Factory

    private func makePageVC(at index: Int) -> BalloonStoryPageViewController {
        let config = pages[index]
        let vc = BalloonStoryPageViewController()
        vc.titleText = config.title
        vc.subtitleText = config.subtitle
        vc.pageIndex = index
        vc.animationView = makeVisual(for: config.visualType)
        return vc
    }

    private func makeVisual(for type: PageConfig.VisualType) -> UIView & StoryAnimatable {
        switch type {
        case .wave:            return DirectiveStoryWaveView()
        case .experiment:      return DirectiveStoryExperimentView()
        case .directiveTypes:  return DirectiveStoryTypesView()
        case .evolution:       return DirectiveStoryEvolutionView()
        case .tools:           return DirectiveStoryToolsView()
        case .pattern:         return DirectiveStoryPatternView()
        case .framework:       return DirectiveStoryFrameworkView()
        }
    }
}

// MARK: - UIPageViewControllerDataSource

extension DirectiveStoryViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let pageVC = viewController as? BalloonStoryPageViewController, pageVC.pageIndex > 0 else { return nil }
        return makePageVC(at: pageVC.pageIndex - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let pageVC = viewController as? BalloonStoryPageViewController, pageVC.pageIndex < pages.count - 1 else { return nil }
        return makePageVC(at: pageVC.pageIndex + 1)
    }
}

// MARK: - UIPageViewControllerDelegate

extension DirectiveStoryViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let pageVC = pageViewController.viewControllers?.first as? BalloonStoryPageViewController else { return }
        currentIndex = pageVC.pageIndex
        updateControls()
    }
}
