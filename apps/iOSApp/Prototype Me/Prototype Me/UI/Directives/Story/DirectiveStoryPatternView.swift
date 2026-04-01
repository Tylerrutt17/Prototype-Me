import UIKit

/// Page 6 visual: scattered dots that converge into an organized grid pattern,
/// representing patterns emerging from experimentation.
final class DirectiveStoryPatternView: UIView, StoryAnimatable {

    private var dots: [UIView] = []
    private var targetPositions: [CGPoint] = []
    private var hasAnimated = false

    private let dotCount = 12
    private let dotColors: [UIColor] = [
        DesignTokens.Colors.success,
        DesignTokens.Colors.accent,
        DesignTokens.Colors.accentSecondary,
        DesignTokens.Colors.accentTertiary,
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        buildDots()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildDots() {
        for i in 0..<dotCount {
            let size: CGFloat = CGFloat.random(in: 10...18)
            let dot = UIView()
            dot.backgroundColor = dotColors[i % dotColors.count].withAlphaComponent(0.7)
            dot.layer.cornerRadius = size / 2
            dot.frame = CGRect(x: 0, y: 0, width: size, height: size)
            dot.alpha = 0
            addSubview(dot)
            dots.append(dot)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasAnimated, bounds.width > 0 else { return }

        let centerX = bounds.midX
        let centerY = bounds.midY

        // Scatter dots randomly
        for dot in dots {
            dot.center = CGPoint(
                x: CGFloat.random(in: bounds.width * 0.1...bounds.width * 0.9),
                y: CGFloat.random(in: bounds.height * 0.1...bounds.height * 0.9)
            )
        }

        // Calculate target grid positions (3x4 grid, centered)
        targetPositions = []
        let cols = 4
        let rows = 3
        let spacingX: CGFloat = 40
        let spacingY: CGFloat = 40
        let gridW = CGFloat(cols - 1) * spacingX
        let gridH = CGFloat(rows - 1) * spacingY
        let startX = centerX - gridW / 2
        let startY = centerY - gridH / 2

        for row in 0..<rows {
            for col in 0..<cols {
                targetPositions.append(CGPoint(
                    x: startX + CGFloat(col) * spacingX,
                    y: startY + CGFloat(row) * spacingY
                ))
            }
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        hasAnimated = true

        guard !UIAccessibility.isReduceMotionEnabled else {
            for (i, dot) in dots.enumerated() where i < targetPositions.count {
                dot.alpha = 1
                dot.center = targetPositions[i]
            }
            return
        }

        // Phase 1: Fade in scattered
        for (i, dot) in dots.enumerated() {
            UIView.animate(withDuration: 0.3, delay: Double(i) * 0.04) {
                dot.alpha = 1
            }
        }

        // Phase 2: Converge to grid
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            for (i, dot) in self.dots.enumerated() where i < self.targetPositions.count {
                UIView.animate(
                    withDuration: 0.7,
                    delay: Double(i) * 0.05,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0.3
                ) {
                    dot.center = self.targetPositions[i]
                    // Normalize sizes as they converge
                    let uniformSize: CGFloat = 12
                    dot.bounds = CGRect(x: 0, y: 0, width: uniformSize, height: uniformSize)
                    dot.layer.cornerRadius = uniformSize / 2
                    dot.alpha = 1
                }
            }
        }

        // Phase 3: Subtle glow on the whole grid
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            for dot in self.dots {
                UIView.animate(withDuration: 0.4) {
                    dot.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.8)
                }
            }
        }
    }

    func stopAnimations() {
        for dot in dots { dot.layer.removeAllAnimations() }
    }
}
