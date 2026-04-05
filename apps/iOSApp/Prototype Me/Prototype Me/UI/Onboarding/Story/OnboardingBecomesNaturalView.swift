import UIKit

/// Dots that start at jittery Y offsets then settle into a smooth wave —
/// a visual metaphor for habits becoming rhythmic and natural over time.
final class OnboardingBecomesNaturalView: UIView, StoryAnimatable {

    private var dots: [UIView] = []
    private let dotCount = 7
    private let dotSize: CGFloat = 12
    private let spacing: CGFloat = 18

    private var displayLink: CADisplayLink?
    private var waveStartTime: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildDots()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        displayLink?.invalidate()
    }

    private func buildDots() {
        for _ in 0..<dotCount {
            let dot = UIView()
            dot.backgroundColor = DesignTokens.Colors.accent
            dot.layer.cornerRadius = dotSize / 2
            dot.alpha = 0
            addSubview(dot)
            dots.append(dot)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let totalWidth = CGFloat(dotCount - 1) * (dotSize + spacing) + dotSize
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2
        for (i, dot) in dots.enumerated() {
            let x = startX + CGFloat(i) * (dotSize + spacing)
            dot.frame = CGRect(x: x, y: centerY - dotSize / 2, width: dotSize, height: dotSize)
        }
    }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            dots.forEach { $0.alpha = 1; $0.transform = .identity }
            return
        }

        // Phase 1: dots appear with jittery Y offsets — irregular, effortful
        let jitters: [CGFloat] = [-22, 14, -8, 20, -18, 6, -14]
        for (i, dot) in dots.enumerated() {
            dot.transform = CGAffineTransform(translationX: 0, y: jitters[i])
            UIView.animate(
                withDuration: 0.4,
                delay: Double(i) * 0.08,
                options: [.curveEaseOut]
            ) {
                dot.alpha = 1
            }
        }

        // Phase 2: settle into a straight line — effort becomes routine
        // Damping 0.95 keeps the spring from oscillating past identity, so
        // there's no snap at the end of the animation.
        UIView.animate(
            withDuration: 0.9,
            delay: 1.1,
            usingSpringWithDamping: 0.95,
            initialSpringVelocity: 0,
            options: []
        ) {
            self.dots.forEach { $0.transform = .identity }
        }

        // Phase 3: continuous smooth wave — rhythmic, second nature
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { [weak self] in
            self?.startWave()
        }
    }

    private func startWave() {
        // Clear any lingering animations so the display-link transform is authoritative.
        dots.forEach { $0.layer.removeAllAnimations() }
        waveStartTime = CACurrentMediaTime()
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(updateWave(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func updateWave(_ link: CADisplayLink) {
        let t = CACurrentMediaTime() - waveStartTime
        let amplitude: CGFloat = 14
        let period: Double = 3.0
        let phaseStep: Double = 0.55 // radians between adjacent dots
        let blendIn: Double = 0.8
        let linear = min(1.0, t / blendIn)
        let blend = CGFloat(linear * linear * (3 - 2 * linear)) // smoothstep

        let angularBase = 2 * .pi * (t / period)
        for (i, dot) in dots.enumerated() {
            let angle = angularBase + Double(i) * phaseStep
            let y = amplitude * CGFloat(sin(angle)) * blend
            dot.transform = CGAffineTransform(translationX: 0, y: y)
        }
    }

    func stopAnimations() {
        displayLink?.invalidate()
        displayLink = nil
        dots.forEach { $0.layer.removeAllAnimations() }
    }
}
