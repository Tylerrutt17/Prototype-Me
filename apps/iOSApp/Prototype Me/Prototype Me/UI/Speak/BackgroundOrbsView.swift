import UIKit

/// Ambient background: soft colored orbs that drift slowly. Used behind the
/// Speak tab's empty state for a living, breathing feel.
final class BackgroundOrbsView: UIView {

    private var orbs: [UIView] = []
    private var hasSetUp = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasSetUp, bounds.width > 0, bounds.height > 0 else { return }
        hasSetUp = true
        setupOrbs()
    }

    private func setupOrbs() {
        // (color, xRatio, yRatio, size, driftX, driftY, duration)
        let configs: [(UIColor, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, TimeInterval)] = [
            (.systemPurple,   0.15, 0.18, 200,  40, -30, 7.5),
            (.systemOrange,   0.88, 0.30, 170, -45,  35, 8.5),
            (.systemTeal,     0.25, 0.82, 220,  50,  40, 9.0),
            (.systemPink,     0.80, 0.72, 180, -35, -45, 7.0),
            (DesignTokens.Colors.accent, 0.50, 0.50, 150,  30,  25, 6.5),
        ]

        for (index, config) in configs.enumerated() {
            let (color, xRatio, yRatio, size, driftX, driftY, duration) = config

            let orb = UIView(frame: CGRect(
                x: bounds.width * xRatio - size / 2,
                y: bounds.height * yRatio - size / 2,
                width: size,
                height: size
            ))
            orb.backgroundColor = color.withAlphaComponent(0.22)
            orb.layer.cornerRadius = size / 2
            orb.layer.shadowColor = color.cgColor
            orb.layer.shadowRadius = 60
            orb.layer.shadowOpacity = 0.55
            orb.layer.shadowOffset = .zero
            addSubview(orb)
            orbs.append(orb)

            // Stagger starts so the motion feels uncorrelated
            let delay = TimeInterval(index) * 0.6
            UIView.animate(
                withDuration: duration,
                delay: delay,
                options: [.repeat, .autoreverse, .curveEaseInOut],
                animations: {
                    orb.transform = CGAffineTransform(translationX: driftX, y: driftY)
                }
            )
        }
    }
}
