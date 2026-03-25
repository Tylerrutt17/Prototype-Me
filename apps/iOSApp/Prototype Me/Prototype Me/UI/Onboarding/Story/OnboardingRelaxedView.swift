import UIKit

/// Page 8: Relaxed icon with gentle feel — "Not a rulebook."
final class OnboardingRelaxedView: UIView, StoryAnimatable {

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .ultraLight)
        let iv = UIImageView(image: UIImage(systemName: "leaf.fill", withConfiguration: config))
        iv.tintColor = DesignTokens.Colors.accentSecondary.withAlphaComponent(0.6)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 100),
            iconView.heightAnchor.constraint(equalToConstant: 100),
        ])
        iconView.alpha = 0
        iconView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            iconView.alpha = 1; iconView.transform = .identity
            return
        }

        UIView.animate(withDuration: 1.0, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.2) {
            self.iconView.alpha = 1
            self.iconView.transform = .identity
        }

        // Gentle continuous float
        UIView.animate(withDuration: 3.0, delay: 1.0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.iconView.transform = CGAffineTransform(translationX: 0, y: -8)
        }
    }

    func stopAnimations() {
        iconView.layer.removeAllAnimations()
    }
}
