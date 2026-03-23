import UIKit

/// Three-dot sequential pulse animation for "AI is thinking" state.
final class ThinkingAnimationView: UIView {

    private let dots: [UIView] = {
        let colors: [UIColor] = [
            DesignTokens.Colors.accent,
            DesignTokens.Colors.accentSecondary,
            DesignTokens.Colors.accentTertiary,
        ]
        return colors.map { color in
            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = 5
            dot.translatesAutoresizingMaskIntoConstraints = false
            return dot
        }
    }()

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for dot in dots {
            stack.addArrangedSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 10),
                dot.heightAnchor.constraint(equalToConstant: 10),
            ])
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    // MARK: - Animation

    func startAnimating() {
        for (index, dot) in dots.enumerated() {
            let delay = 0.15 * Double(index)
            UIView.animate(
                withDuration: 0.4,
                delay: delay,
                options: [.repeat, .autoreverse, .curveEaseInOut]
            ) {
                dot.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
            }
        }
    }

    func stopAnimating() {
        for dot in dots {
            dot.layer.removeAllAnimations()
            dot.transform = .identity
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 50, height: 20)
    }
}
