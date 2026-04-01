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
        let visualType: VisualType?
        let particleIntensity: CGFloat

        enum VisualType {
            case vision
            case buildFade
            case bestWorstDays
            case wavyLine
            case framework
            case modesVision
            case directiveTrial
            case weakPoints
            case shortcomings
            case systemEvolves
            case journal
            case aiInsights
            case directives
            case modes
            case balloons
            case notesFolders
            case converge
            case relaxed
            case hero
        }
    }

    private let pages: [PageConfig] = [
        // ── Narrative ──────────────────────────────
        // 1. Hook
        PageConfig(
            title: "You've done this before",
            subtitle: "The better habits. The goals. The fresh starts. It works for a while — then it doesn't.",
            visualType: .vision,
            particleIntensity: 0.4
        ),
        // 2. The Gap
        PageConfig(
            title: "Why? The hard part isn't starting",
            subtitle: "It's sticking with it. You try building better habits, it works, then life gets in the way and it fades. Every time.",
            visualType: .buildFade,
            particleIntensity: 0.4
        ),
        // 3. The Insight
        PageConfig(
            title: "What makes your best & worst days?",
            subtitle: "It's not random. Your worst days have patterns — the things you skipped, the habits you dropped. Fix those, and your best days happen on their own.",
            visualType: .bestWorstDays,
            particleIntensity: 0.4
        ),
        // 4. Escalation
        PageConfig(
            title: "What's actually dragging you down?",
            subtitle: "Low energy, bad habits, irritability. Some are always there. Some only show up in certain situations. If you've never mapped them out, how would you know what to fix?",
            visualType: .shortcomings,
            particleIntensity: 0.6
        ),
//        // 5. Failed solutions
//        PageConfig(
//            title: "You've tried routines. They don't adapt.",
//            subtitle: "Habits apps, rules, willpower. They work until life changes — then they break. Because they were built for a version of you that doesn't exist anymore.",
//            visualType: nil,
//            particleIntensity: 0.4
//        ),
        // 5. The Real Solution
        PageConfig(
            title: "Try things. See what sticks.",
            subtitle: "Find the habits and practices that keep the lows from happening. Track what works, drop what doesn't. No one can figure this out for you.",
            visualType: .wavyLine,
            particleIntensity: 0.8
        ),
        // ── How It Works ───────────────────────────
        // 7. Transition
        PageConfig(
            title: "So how does it work?",
            subtitle: "",
            visualType: nil,
            particleIntensity: 0.4
        ),
        // 8. Directives
        PageConfig(
            title: "These are Directives",
            subtitle: "The small things that keep you from hitting a low. Habits, rules, reminders — they're not always exciting, but they're what make the difference.",
            visualType: .directiveTrial,
            particleIntensity: 0.8
        ),
        // 9. System evolves
        PageConfig(
            title: "Figure out what works best",
            subtitle: "Some things will help, some won't. Swap what doesn't work, double down on what does. Over time, you learn exactly what keeps you steady.",
            visualType: .systemEvolves,
            particleIntensity: 0.8
        ),
        // 10. Journal + AI
        PageConfig(
            title: "Track what's working",
            subtitle: "Rate your day. Write what happened. The app finds patterns — what dragged you down, what kept you steady. So you can see what's actually making the difference.",
            visualType: .journal,
            particleIntensity: 0.8
        ),
        // ── The Close ──────────────────────────────
        // 11. CTA
        PageConfig(
            title: "Let's build your system",
            subtitle: "Skip days. Change your mind. The system adapts to how you actually live. We'll help you set up a starter plan — you can change everything later.",
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

    // MARK: - Particles (disabled for now)

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

        // particleScene.intensityMultiplier = pages[currentIndex].particleIntensity

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
        if let visualType = config.visualType {
            vc.animationView = makeVisual(for: visualType)
        }
        if let attributed = Self.attributedSubtitles[index] {
            vc.attributedSubtitle = attributed
        }
        return vc
    }

    // MARK: - Attributed Subtitles

    /// Styled subtitles with bold/italic emphasis for specific pages.
    private static let attributedSubtitles: [Int: NSAttributedString] = {
        let body = DesignTokens.Typography.body
        let bold = DesignTokens.Typography.rounded(style: .body, weight: .bold)
        let italic = UIFont.italicSystemFont(ofSize: body.pointSize)
        let boldItalic = UIFont(descriptor: bold.fontDescriptor.withSymbolicTraits(.traitItalic) ?? bold.fontDescriptor, size: bold.pointSize)
        let color = DesignTokens.Colors.textSecondary
        let accent = DesignTokens.Colors.accent
        let fwColor = NoteKind.framework.color
        let modeColor = NoteKind.mode.color

        var map: [Int: NSAttributedString] = [:]

        // 0 - Hook
        map[0] = styled {
            $0.normal("The better habits. The goals. The fresh starts. It works for a while — ")
            $0.italic("then it doesn't.")
        }

        // 1 - The Gap
        map[1] = styled {
            $0.normal("It's ")
            $0.bold("sticking with it")
            $0.normal(". You try building better habits, it works, then life gets in the way and it fades. ")
            $0.italic("Every time.")
        }

        // 2 - Insight
        map[2] = styled {
            $0.normal("It's not random. Your worst days have patterns — the things you skipped, the habits you dropped. ")
            $0.bold("Fix those, and your best days happen on their own.")
        }

        // 3 - Escalation
        map[3] = styled {
            $0.normal("Low energy, bad habits, irritability. Some are ")
            $0.bold("always there")
            $0.normal(". Some only show up in ")
            $0.bold("certain situations")
            $0.normal(". If you've never mapped them out, ")
            $0.italic("how would you know what to fix?")
        }

        // 4 - Real solution
        map[4] = styled {
            $0.normal("Find the habits and practices that keep the lows from happening. Track what works, drop what doesn't. ")
            $0.italic("No one can figure this out for you.")
        }

        // 6 - Directives
        map[6] = styled {
            $0.normal("The small things that keep you from hitting a low. Habits, rules, reminders — they're not always exciting, ")
            $0.bold("but they're what make the difference")
            $0.normal(".")
        }

        // 7 - System evolves
        map[7] = styled {
            $0.normal("Some things will help, some won't. Swap what doesn't work, double down on what does. Over time, you learn exactly what ")
            $0.bold("keeps you steady")
            $0.normal(".")
        }

        // 8 - Journal
        map[8] = styled {
            $0.normal("Rate your day. Write what happened. The app finds ")
            $0.bold("patterns")
            $0.normal(" — what dragged you down, what kept you steady. So you can see what's ")
            $0.italic("actually")
            $0.normal(" making the difference.")
        }

        // 9 - CTA
        map[9] = styled {
            $0.normal("Skip days. Change your mind. ")
            $0.italic("The system adapts to how you actually live.")
            $0.normal(" We'll help you set up a starter plan — you can change ")
            $0.italic("everything")
            $0.normal(" later.")
        }

        return map
    }()

    /// Helper to build attributed strings with a builder pattern.
    private static func styled(_ build: (StyledStringBuilder) -> Void) -> NSAttributedString {
        let builder = StyledStringBuilder()
        build(builder)
        return builder.result
    }

    private class StyledStringBuilder {
        let result = NSMutableAttributedString()
        private let body = DesignTokens.Typography.body
        private let boldFont = DesignTokens.Typography.rounded(style: .body, weight: .bold)
        private let color = DesignTokens.Colors.textSecondary

        private var italicFont: UIFont {
            UIFont.italicSystemFont(ofSize: body.pointSize)
        }

        private var boldItalicFont: UIFont {
            UIFont(descriptor: boldFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? boldFont.fontDescriptor, size: boldFont.pointSize)
        }

        func normal(_ text: String) {
            result.append(NSAttributedString(string: text, attributes: [.font: body, .foregroundColor: color]))
        }

        func bold(_ text: String) {
            result.append(NSAttributedString(string: text, attributes: [.font: boldFont, .foregroundColor: color]))
        }

        func italic(_ text: String) {
            result.append(NSAttributedString(string: text, attributes: [.font: italicFont, .foregroundColor: color]))
        }

        func boldItalic(_ text: String) {
            result.append(NSAttributedString(string: text, attributes: [.font: boldItalicFont, .foregroundColor: color]))
        }

        func colored(_ text: String, _ textColor: UIColor, _ font: UIFont) {
            result.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor]))
        }
    }

    private func makeVisual(for type: PageConfig.VisualType) -> (UIView & StoryAnimatable) {
        switch type {
        case .vision:
            return OnboardingVisionView()
        case .buildFade:
            return OnboardingBuildFadeView()
        case .bestWorstDays:
            return OnboardingBestWorstDaysView()
        case .wavyLine:
            return OnboardingWavyLineView()
        case .framework:
            return OnboardingFrameworkView()
        case .modesVision:
            return OnboardingModesVisionView()
        case .directiveTrial:
            return OnboardingDirectiveTrialView()
        case .weakPoints:
            return OnboardingWeakPointsView()
        case .shortcomings:
            return OnboardingShortcomingsView()
        case .systemEvolves:
            return OnboardingSystemEvolvesView()
        case .journal:
            return OnboardingJournalDemoView()
        case .aiInsights:
            return OnboardingAIInsightsView()
        case .directives:
            return OnboardingDirectiveCardsView()
        case .modes:
            return OnboardingModeCardsView()
        case .balloons:
            return OnboardingBalloonDemoView()
        case .notesFolders:
            return OnboardingNotesFoldersView()
        case .converge:
            return OnboardingConvergeView()
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
