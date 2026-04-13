import UIKit

/// Gradient glow bar under the nav bar. Splashes tall when thinking, shrinks when done.
final class ThinkingBarView: UIView {

    private let gradientView = UIView()
    private let glowView = UIView()
    private let gradientLayer = CAGradientLayer()

    private let barHeight: CGFloat = 3
    private let splashHeight: CGFloat = 80
    private let thinkingHeight: CGFloat = 20
    private let restingHeight: CGFloat = 3

    private var glowHeightConstraint: NSLayoutConstraint!
    private var isThinking = false

    private let colors: [UIColor] = [
        DesignTokens.Colors.accent,
        DesignTokens.Colors.accentSecondary,
        DesignTokens.Colors.accentTertiary,
        DesignTokens.Colors.accent,
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = false
        isUserInteractionEnabled = false

        // Gradient bar (always visible, fixed height)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gradientView)

        gradientLayer.colors = colors.map { $0.withAlphaComponent(0.5).cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientView.layer.addSublayer(gradientLayer)

        // Glow view (height animates — extends below the bar)
        glowView.translatesAutoresizingMaskIntoConstraints = false
        glowView.alpha = 0
        insertSubview(glowView, belowSubview: gradientView)

        // Glow is a simple gradient from accent color to clear
        let glowGradient = CAGradientLayer()
        glowGradient.colors = [
            DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor,
        ]
        glowGradient.startPoint = CGPoint(x: 0.5, y: 0)
        glowGradient.endPoint = CGPoint(x: 0.5, y: 1)
        glowView.layer.addSublayer(glowGradient)
        self.glowGradient = glowGradient

        glowHeightConstraint = glowView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // Self height = just the bar
            heightAnchor.constraint(equalToConstant: barHeight),

            // Gradient bar fills self
            gradientView.topAnchor.constraint(equalTo: topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: barHeight),

            // Glow hangs below self (outside bounds — clipsToBounds is false)
            glowView.topAnchor.constraint(equalTo: bottomAnchor),
            glowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glowView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glowHeightConstraint,
        ])
    }

    private var glowGradient: CAGradientLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = gradientView.bounds
        glowGradient?.frame = glowView.bounds
    }

    func startAnimating() {
        guard !isThinking else { return }
        isThinking = true

        // Full brightness
        gradientLayer.colors = colors.map { $0.cgColor }

        // Show glow + splash
        glowView.alpha = 1
        glowHeightConstraint.constant = splashHeight
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.35,
            initialSpringVelocity: 1.5,
            options: []
        ) {
            self.layoutIfNeeded()
        } completion: { _ in
            guard self.isThinking else { return }

            // Settle to thinking height
            self.glowHeightConstraint.constant = self.thinkingHeight
            UIView.animate(withDuration: 0.6, delay: 0.1, options: [.curveEaseInOut]) {
                self.layoutIfNeeded()
            }

            // Start shimmer
            self.startShimmer()
        }
    }

    private func startShimmer() {
        let slide = CABasicAnimation(keyPath: "transform.translation.x")
        slide.fromValue = -bounds.width
        slide.toValue = bounds.width
        slide.duration = 1.5
        slide.repeatCount = .infinity
        slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(slide, forKey: "slide")
    }

    func stopAnimating() {
        guard isThinking else { return }
        isThinking = false

        // Shrink glow to zero
        glowHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            self.glowView.alpha = 0
            self.layoutIfNeeded()
        } completion: { _ in
            self.gradientLayer.removeAllAnimations()
            self.gradientLayer.colors = self.colors.map { $0.withAlphaComponent(0.5).cgColor }
        }
    }
}
