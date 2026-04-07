import UIKit
import SpriteKit

/// Full-screen animated story that introduces the app's purpose, features, and philosophy.
/// Replaces the basic IntroPageViewController with a rich, multi-page experience.
final class OnboardingStoryViewController: UIViewController {

    var onFinished: (() -> Void)?

    // MARK: - Page Config

    private struct PageConfig {
        let title: String
        /// Plain-text subtitle. Only used for pages WITHOUT a styled entry in
        /// `attributedSubtitles`. Pages that have a styled entry should set this
        /// to nil — the styled map is the single source of truth for those pages.
        let subtitle: String?
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
            case counterWeakPoints
            case directiveRefine
            case voiceAssistant
            case captureThoughts
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
            case becomesNatural
        }
    }

    private let pages: [PageConfig] = [
        // ── Act I — The Problem ────────────────────
        // 1. Hook (styled in map[0])
        PageConfig(
            title: "You've done this before",
            subtitle: nil,
            visualType: .vision,
            particleIntensity: 0.4
        ),
        // 2. The Gap (styled in map[1])
        PageConfig(
            title: "Why? The hard part isn't starting",
            subtitle: nil,
            visualType: .buildFade,
            particleIntensity: 0.4
        ),

        // ── Act II — The Insight ───────────────────
        // 3. Need to track (styled in map[2])
        PageConfig(
            title: "You need a way to track it",
            subtitle: nil,
            visualType: .captureThoughts,
            particleIntensity: 0.4
        ),
        // 4. Pattern exists (styled in map[3])
        PageConfig(
            title: "Your best days aren't random",
            subtitle: nil,
            visualType: .bestWorstDays,
            particleIntensity: 0.4
        ),
        // 5. Weak points (styled in map[4])
        PageConfig(
            title: "Find the weak points.",
            subtitle: nil,
            visualType: .shortcomings,
            particleIntensity: 0.6
        ),
        // 6. Turn weak points into modes (styled in map[5])
        PageConfig(
            title: "Turn those weak points into \"modes\"",
            subtitle: nil,
            visualType: .modes,
            particleIntensity: 0.6
        ),
        // 7. Counter through trial and error (styled in map[6])
        PageConfig(
            title: "Figure Out What Works Best.",
            subtitle: nil,
            visualType: .directiveRefine,
            particleIntensity: 0.6
        ),
        // Context bridge — REPLACED by counterWeakPoints slide above
        // PageConfig(
        //     title: "Different parts of your life need different things",
        //     subtitle: "What keeps you sharp at the desk isn't what helps you switch off at night. What gets you through a training week isn't what gets you through a rough one.",
        //     visualType: .framework,
        //     particleIntensity: 0.5
        // ),
        // 8. Over time, it becomes second nature (styled in map[7])
        PageConfig(
            title: "Over time, modes become second nature",
            subtitle: nil,
            visualType: .becomesNatural,
            particleIntensity: 0.6
        ),


        // ── Act III — The Method ───────────────────
        // 9. Additional features — transitional beat
        PageConfig(
            title: "Other Main Features",
            subtitle: "Some other features to mention.",
            visualType: nil,
            particleIntensity: 0.4
        ),
        // 9. Trial and error
        // PageConfig(
        //     title: "Try things. See what sticks.",
        //     subtitle: "Find what keeps you steady in each mode. Track what works, drop what doesn't. No one can figure this out for you.",
        //     visualType: .wavyLine,
        //     particleIntensity: 0.8
        // ),
        // 10. Directives
        // PageConfig(
        //     title: "Directives — the building blocks",
        //     subtitle: "Small experiments you run inside a mode. Try one, keep it if it helps, drop it if not.",
        //     visualType: .directiveTrial,
        //     particleIntensity: 0.8
        // ),
        // 11. The loop
        // PageConfig(
        //     title: "Keep what works, drop what doesn't",
        //     subtitle: "Some things will help, some won't. Swap what doesn't land, double down on what does. Over time you learn exactly what keeps you steady in each mode.",
        //     visualType: .systemEvolves,
        //     particleIntensity: 0.8
        // ),
        // 10. Track (styled in map[9])
        PageConfig(
            title: "Journaling.",
            subtitle: nil,
            visualType: .journal,
            particleIntensity: 0.8
        ),
        // 11. Voice / AI assistant (styled in map[10])
        PageConfig(
            title: "Talk or type — it adapts",
            subtitle: nil,
            visualType: .voiceAssistant,
            particleIntensity: 0.6
        ),

        // ── Act IV — The Frame + CTA ───────────────
        // 13. App's role — external memory (folder structure)
        PageConfig(
            title: "Organize with Folders",
            subtitle: nil,
            visualType: .notesFolders,
            particleIntensity: 0.5
        ),
        // 14. Philosophy — not a rulebook
        PageConfig(
            title: "This isn't a rulebook",
            subtitle: nil,
            visualType: .relaxed,
            particleIntensity: 0.5
        ),
        // 15. CTA
        PageConfig(
            title: "Let's get started",
            subtitle: "We'll ask a few questions and build you a starter plan. Skip days, change your mind, swap anything — it all adapts to how you actually live.",
            visualType: .hero,
            particleIntensity: 2.5
        ),

        // ── Commented out (not used in current arc) ─
        // Transition beat — absorbed into the Act II → Act III handoff.
        // PageConfig(
        //     title: "So how does it work?",
        //     subtitle: "",
        //     visualType: nil,
        //     particleIntensity: 0.4
        // ),
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
        vc.subtitleText = config.subtitle ?? ""
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
            $0.normal(". You try building better habits, it works, then life gets in the way and ")
            $0.bold("you forget. ")
            $0.italic("Every time.")
        }

        // 2 - Need a way to track it
        map[2] = styled {
            $0.normal("Write down what worked, what didn't. That way you can ")
            $0.bold("Improve over time")
            $0.normal(" — ")
            $0.italic("without having to remember it all.")
        }

        // 3 - Pattern exists
        map[3] = styled {
            $0.normal("There's patterns — the things you did, the things you skipped. ")
            $0.bold("Find the weaknesses, ")
            $0.normal("and use them to your advantage.")
        }

        // 4 - Weak points
        map[4] = styled {
            $0.normal("Eye strain at the computer. Can't switch off at night?")
            $0.normal(" If you've never listed them out, ")
            $0.italic("how would you know what to fix?")
        }

        // 5 - Turn weak points into modes
        map[5] = styled {
            $0.bold("Winding Down, Recovery, Computer Work")
            $0.normal(" — each one its own mode. ")
            $0.italic("Gamify building better habits.")
        }

        // 6 - Counter weak points
        map[6] = styled {
            $0.bold("It's all trial and error. ")
            $0.normal("Try things, ")
            $0.italic("see what works, ")
            $0.normal("toss out what doesn't and ")
            $0.bold("better systems over time.")
        }

        // 7 - Becomes second nature
        map[7] = styled {
            $0.normal("Be consistent with it enough and it ")
            $0.bold("will start to come naturally.")
        }

        // 8 - Additional features is title-only (transitional), no styled subtitle

        // 9 - Track
        map[9] = styled {
            $0.normal("Rate your day. Write what happened. The app finds ")
            $0.bold("patterns")
            $0.normal(" — So you can see what makes your best and worst days.")
        }

        // 10 - Voice / AI assistant
        map[10] = styled {
            $0.normal("Swap a directive, add a note, or ")
            $0.bold("ask what's working")
            $0.normal(". The app knows your setup, so ")
            $0.italic("one sentence is enough.")
        }

        // 11 - App's role (folder structure)
        map[11] = styled {
            $0.normal("Organize your thoughts into ")
            $0.bold("folders and notes")
            $0.normal(" — including ")
            $0.bold("modes")
            $0.normal(", which are just notes that filter your Focus.")
        }

        // 12 - Philosophy (not a rulebook)
        map[12] = styled {
            $0.bold("Don't worry about perfection")
            $0.normal(" - otherwise you'll get burned out trying to follow a bunch of ")
            $0.italic("\"Rules.\"")
            $0.normal(" You'll get ")
            $0.bold("as much ")
            $0.normal("or ")
            $0.bold("as little")
            $0.bold(" as you put into this.")
        }

        // 13 - CTA
        map[13] = styled {
            $0.normal("We'll ask a few questions and build you a starter plan. Skip days, change your mind, swap anything — ")
            $0.italic("it all adapts to how you actually live.")
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
        case .counterWeakPoints:
            return OnboardingCounterWeakPointsView()
        case .directiveRefine:
            return OnboardingDirectiveRefineView()
        case .voiceAssistant:
            return OnboardingVoiceAssistantView()
        case .captureThoughts:
            return OnboardingCaptureThoughtsView()
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
        case .becomesNatural:
            return OnboardingBecomesNaturalView()
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
