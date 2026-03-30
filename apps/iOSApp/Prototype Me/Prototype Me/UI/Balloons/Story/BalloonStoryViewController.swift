import UIKit
import SpriteKit

/// Full-screen story experience explaining the Balloons concept through animated pages.
final class BalloonStoryViewController: UIViewController {

    // MARK: - Page Config

    private struct PageConfig {
        let title: String
        let subtitle: String
        let visualType: VisualType
        let particleIntensity: CGFloat

        enum VisualType {
            case particles
            case directiveExplainer
            case balloonRise
            case examples
            case balloonDeflate
            case balloonPump
            case celebration
            case forgettingCurve
            case brainRAM
            case spacedRepetition
        }
    }

    private let pages: [PageConfig] = [
        // The science (the problem + the solution)
        PageConfig(
            title: "The Problem: The Forgetting Curve",
            subtitle: "Your brain naturally lets go of things over time. Without reminders, the habits you're building and the things you're working to keep top of mind can quietly slip away — that's the forgetting curve.",
            visualType: .forgettingCurve,
            particleIntensity: 0.6
        ),
        PageConfig(
            title: "The Solution: Spaced Reminders",
            subtitle: "Each time you actively bring something back to mind, it sticks longer. The more you revisit it, the slower it fades from memory.",
            visualType: .spacedRepetition,
            particleIntensity: 0.8
        ),
        // The implementation (balloons)
        PageConfig(
            title: "That's what balloons do",
            subtitle: "Balloons are built on this science. They periodically remind you of the things that matter — so nothing quietly slips away.",
            visualType: .balloonRise,
            particleIntensity: 1.0
        ),
        PageConfig(
            title: "How the system works",
            subtitle: "Here's the full cycle — from things you're trying to remember, to life getting in the way, to balloons bringing them back.",
            visualType: .brainRAM,
            particleIntensity: 0.6
        ),
        PageConfig(
            title: "What are some examples?",
            subtitle: "Things you want to periodically revisit — not one-off tasks, but ongoing intentions.",
            visualType: .examples,
            particleIntensity: 0.8
        ),
        PageConfig(
            title: "Balloons live inside directives",
            subtitle: "Open any directive and activate the balloon feature. Once enabled, a countdown starts — and when it runs out, you'll get a push notification to bring it back to mind.",
            visualType: .directiveExplainer,
            particleIntensity: 0.8
        ),
        PageConfig(
            title: "But balloons slowly deflate",
            subtitle: "Over time, balloons lose air and change color as they get more urgent. You'll get a push notification when they run out — a nudge to bring it back to mind.",
            visualType: .balloonDeflate,
            particleIntensity: 0.6
        ),
        PageConfig(
            title: "Pump to reload",
            subtitle: "When you get the notification, tap it to go straight to the directive — read it, click pump to blow it back up, and the cycle starts again.",
            visualType: .balloonPump,
            particleIntensity: 1.0
        ),
        PageConfig(
            title: "Stay aware, stay on track",
            subtitle: "Balloons keep the important things from slipping through the cracks. As long as you keep pumping, nothing gets forgotten.",
            visualType: .celebration,
            particleIntensity: 2.5
        ),
    ]

    // MARK: - UI

    private var pageVC: UIPageViewController!
    private let pageControl = UIPageControl()
    private let nextButton = AppButton(title: "Next")
    private let skipButton = UIButton(type: .system)
    private var currentIndex = 0
    private var navigationLocked = false
    private var brainRAMVisited = false

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
        skView?.frame = view.bounds
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
//        skView = SKView()
//        skView.allowsTransparency = true
//        skView.backgroundColor = .clear
//        view.addSubview(skView)
//
//        particleScene = AmbientParticleScene(size: view.bounds.size)
//        particleScene.intensityMultiplier = pages[0].particleIntensity
//        skView.presentScene(particleScene)
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
        guard !navigationLocked else { return }
        if currentIndex < pages.count - 1 {
            currentIndex += 1
            let nextPage = makePageVC(at: currentIndex)
            pageVC.setViewControllers([nextPage], direction: .forward, animated: true)
            updateControls()
            checkNavigationLock()
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

    private func checkNavigationLock() {
        let config = pages[currentIndex]
        guard config.visualType == .brainRAM, !brainRAMVisited else { return }

        navigationLocked = true
        nextButton.isEnabled = false
        nextButton.alpha = 0.4
        skipButton.isEnabled = false
        skipButton.alpha = 0.3
    }

    private func unlockNavigation() {
        brainRAMVisited = true
        navigationLocked = false
        nextButton.isEnabled = true
        skipButton.isEnabled = true

        UIView.animate(withDuration: 0.3) {
            self.nextButton.alpha = 1.0
            self.skipButton.alpha = 1.0
        }
    }

    private func updateControls() {
        pageControl.currentPage = currentIndex
        let isLast = currentIndex == pages.count - 1
        nextButton.setTitle(isLast ? "Got it!" : "Next", for: .normal)

        // Update particle intensity
        particleScene?.intensityMultiplier = pages[currentIndex].particleIntensity

        // Page-specific haptics
        switch pages[currentIndex].visualType {
        case .balloonDeflate: Haptics.warning()
        case .celebration: Haptics.success()
        default: break
        }

        if isLast && !UIAccessibility.isReduceMotionEnabled {
            startButtonPulse()
        } else {
            nextButton.layer.removeAllAnimations()
            nextButton.transform = .identity
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

    // MARK: - Page Factory

    private func makePageVC(at index: Int) -> BalloonStoryPageViewController {
        let config = pages[index]
        let vc = BalloonStoryPageViewController()
        vc.titleText = config.title
        vc.subtitleText = config.subtitle
        vc.pageIndex = index
        var visual = makeVisual(for: config.visualType)
        if visual.locksNavigation {
            visual.onAnimationComplete = { [weak self] in
                self?.unlockNavigation()
            }
        }
        vc.animationView = visual
        return vc
    }

    private func makeVisual(for type: PageConfig.VisualType) -> (UIView & StoryAnimatable) {
        switch type {
        case .particles:
            return StoryParticleView()
        case .directiveExplainer:
            return StoryDirectiveExplainerView()
        case .balloonRise:
            return StoryBalloonRiseView(isCelebration: false)
        case .examples:
            return StoryExamplesView()
        case .balloonDeflate:
            return StoryBalloonDemoView(mode: .deflate)
        case .balloonPump:
            return StoryBalloonDemoView(mode: .pump)
        case .celebration:
            return StoryBalloonRiseView(isCelebration: true)
        case .forgettingCurve:
            return StoryScienceGraphView(graphType: .forgettingCurve)
        case .brainRAM:
            return StoryBrainRAMView()
        case .spacedRepetition:
            return StoryScienceGraphView(graphType: .spacedRepetition)
        }
    }
}

// MARK: - UIPageViewControllerDataSource

extension BalloonStoryViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard !navigationLocked else { return nil }
        guard let pageVC = viewController as? BalloonStoryPageViewController, pageVC.pageIndex > 0 else { return nil }
        return makePageVC(at: pageVC.pageIndex - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard !navigationLocked else { return nil }
        guard let pageVC = viewController as? BalloonStoryPageViewController, pageVC.pageIndex < pages.count - 1 else { return nil }
        return makePageVC(at: pageVC.pageIndex + 1)
    }
}

// MARK: - UIPageViewControllerDelegate

extension BalloonStoryViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let pageVC = pageViewController.viewControllers?.first as? BalloonStoryPageViewController else { return }
        currentIndex = pageVC.pageIndex
        updateControls()
        checkNavigationLock()
    }
}
