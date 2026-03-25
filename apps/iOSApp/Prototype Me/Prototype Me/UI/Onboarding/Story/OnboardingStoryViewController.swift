import UIKit
import SpriteKit

/// Full-screen animated story that introduces the app's purpose, features, and philosophy.
/// Replaces the basic IntroPageViewController with a rich, multi-page experience.
final class OnboardingStoryViewController: UIViewController {

    var onFinished: (() -> Void)?

    // MARK: - Page Config

    private struct PageConfig {
        let title: String
        let subtitle: String
        let visualType: VisualType
        let particleIntensity: CGFloat

        enum VisualType {
            case chaoticParticles
            case forgettingCurve
            case organizingParticles
            case directives
            case modes
            case balloons
            case wavyLine
            case relaxed
            case hero
        }
    }

    private let pages: [PageConfig] = [
        PageConfig(
            title: "Life is complex",
            subtitle: "You've got goals, habits, responsibilities, and ideas — all competing for space in your head.",
            visualType: .chaoticParticles,
            particleIntensity: 0.6
        ),
        PageConfig(
            title: "Your brain wasn't built for this",
            subtitle: "Without a system, the things that matter quietly slip away. That's not a flaw — it's just how memory works.",
            visualType: .forgettingCurve,
            particleIntensity: 0.5
        ),
        PageConfig(
            title: "What if you had a system?",
            subtitle: "Not a rigid rulebook — more like a personal operating system that adapts to you through trial and error.",
            visualType: .organizingParticles,
            particleIntensity: 0.8
        ),
        PageConfig(
            title: "Directives",
            subtitle: "The building blocks. Your goals, habits, and commitments — written down so they don't live rent-free in your head.",
            visualType: .directives,
            particleIntensity: 0.8
        ),
        PageConfig(
            title: "Modes",
            subtitle: "Different states for different situations. Activate a mode and your Focus tab filters to just what's relevant. Over time, they become second nature.",
            visualType: .modes,
            particleIntensity: 0.8
        ),
        PageConfig(
            title: "Balloons",
            subtitle: "Attach a balloon to anything you want to periodically keep top of mind. You'll get a push notification when it runs out — pump it back up to keep it fresh.",
            visualType: .balloons,
            particleIntensity: 1.0
        ),
        PageConfig(
            title: "It gets smoother over time",
            subtitle: "Figure out what makes your best days and what makes your worst. Trial and error. Every adjustment gets you closer to your version of the best life.",
            visualType: .wavyLine,
            particleIntensity: 0.8
        ),
        PageConfig(
            title: "Not a rulebook",
            subtitle: "Follow it loosely. Forget the rules sometimes — that's fine. What matters is the pattern over time, not perfection on any given day.",
            visualType: .relaxed,
            particleIntensity: 0.4
        ),
        PageConfig(
            title: "Let's build your system",
            subtitle: "We'll help you set up a starter plan. You can change everything later — this is just the beginning.",
            visualType: .hero,
            particleIntensity: 2.5
        ),
    ]

    // MARK: - UI

    private var pageVC: UIPageViewController!
    private let pageControl = UIPageControl()
    private let nextButton = AppButton(title: "Next")
    private let skipButton = UIButton(type: .system)
    private var currentIndex = 0

    // Shared background
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

    private var skView: SKView!
    private var particleScene: AmbientParticleScene!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.addSublayer(gradientLayer)
        setupParticles()
        setupPageViewController()
        setupControls()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = view.bounds
        CATransaction.commit()
        skView.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        particleScene?.isPaused = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        skView?.presentScene(nil)
    }

    // MARK: - Particles

    private func setupParticles() {
        skView = SKView()
        skView.allowsTransparency = true
        skView.backgroundColor = .clear
        view.addSubview(skView)

        particleScene = AmbientParticleScene(size: view.bounds.size)
        particleScene.intensityMultiplier = pages[0].particleIntensity
        skView.presentScene(particleScene)
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
        if currentIndex < pages.count - 1 {
            currentIndex += 1
            let nextPage = makePageVC(at: currentIndex)
            pageVC.setViewControllers([nextPage], direction: .forward, animated: true)
            updateControls()
            Haptics.selection()
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
        let isLast = currentIndex == pages.count - 1
        nextButton.setTitle(isLast ? "Get Started" : "Next", for: .normal)

        particleScene.intensityMultiplier = pages[currentIndex].particleIntensity

        if isLast {
            Haptics.success()
            if !UIAccessibility.isReduceMotionEnabled {
                UIView.animate(withDuration: 1.5, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]) {
                    self.nextButton.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                }
            }
        } else {
            nextButton.layer.removeAllAnimations()
            nextButton.transform = .identity
        }
    }

    // MARK: - Page Factory

    private func makePageVC(at index: Int) -> OnboardingStoryPageViewController {
        let config = pages[index]
        let vc = OnboardingStoryPageViewController()
        vc.titleText = config.title
        vc.subtitleText = config.subtitle
        vc.pageIndex = index
        vc.animationView = makeVisual(for: config.visualType)
        return vc
    }

    private func makeVisual(for type: PageConfig.VisualType) -> (UIView & StoryAnimatable) {
        switch type {
        case .chaoticParticles:
            return OnboardingChaoticParticlesView(mode: .chaotic)
        case .forgettingCurve:
            return StoryScienceGraphView(graphType: .forgettingCurve)
        case .organizingParticles:
            return OnboardingChaoticParticlesView(mode: .organizing)
        case .directives:
            return OnboardingDirectiveCardsView()
        case .modes:
            return OnboardingModeCardsView()
        case .balloons:
            return OnboardingBalloonDemoView()
        case .wavyLine:
            return OnboardingWavyLineView()
        case .relaxed:
            return OnboardingRelaxedView()
        case .hero:
            return OnboardingHeroView()
        }
    }
}

// MARK: - UIPageViewControllerDataSource

extension OnboardingStoryViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let pageVC = viewController as? OnboardingStoryPageViewController, pageVC.pageIndex > 0 else { return nil }
        return makePageVC(at: pageVC.pageIndex - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let pageVC = viewController as? OnboardingStoryPageViewController, pageVC.pageIndex < pages.count - 1 else { return nil }
        return makePageVC(at: pageVC.pageIndex + 1)
    }
}

// MARK: - UIPageViewControllerDelegate

extension OnboardingStoryViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let pageVC = pageViewController.viewControllers?.first as? OnboardingStoryPageViewController else { return }
        currentIndex = pageVC.pageIndex
        updateControls()
    }
}
