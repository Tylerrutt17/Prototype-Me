import UIKit

/// Page 3 visual: example balloon labels that appear one at a time with staggered animations.
final class StoryExamplesView: UIView, StoryAnimatable {

    private var rows: [UIView] = []

    private let examples: [(color: UIColor, text: String)] = [
        (DesignTokens.Colors.success, "Drink more water"),
        (DesignTokens.Colors.accent, "Have better posture"),
        (DesignTokens.Colors.accentTertiary, "Practice gratitude"),
        (DesignTokens.Colors.accentSecondary, "Be more patient"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildRows()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildRows() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        for example in examples {
            let row = makeExampleRow(color: example.color, text: example.text)
            stack.addArrangedSubview(row)
            rows.append(row)

            // Start invisible
            row.alpha = 0
            row.transform = CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.9, y: 0.9)
        }
    }

    private func makeExampleRow(color: UIColor, text: String) -> UIView {
        // Mini balloon shape
        let balloonSize: CGFloat = 28
        let balloonView = UIView(frame: CGRect(x: 0, y: 0, width: balloonSize, height: balloonSize * 1.2))
        balloonView.translatesAutoresizingMaskIntoConstraints = false

        let balloon = CAShapeLayer()
        let bW = balloonSize, bH = balloonSize * 1.2
        balloon.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: bW, height: bH)).cgPath
        balloon.fillColor = color.withAlphaComponent(0.85).cgColor
        balloonView.layer.addSublayer(balloon)

        // Highlight
        let hl = CAShapeLayer()
        hl.path = UIBezierPath(ovalIn: CGRect(x: bW * 0.2, y: bH * 0.15, width: bW * 0.25, height: bH * 0.2)).cgPath
        hl.fillColor = UIColor.white.withAlphaComponent(0.35).cgColor
        balloonView.layer.addSublayer(hl)

        // Knot
        let knot = UIBezierPath()
        knot.move(to: CGPoint(x: bW / 2 - 2, y: bH))
        knot.addLine(to: CGPoint(x: bW / 2, y: bH + 3))
        knot.addLine(to: CGPoint(x: bW / 2 + 2, y: bH))
        knot.close()
        let knotLayer = CAShapeLayer()
        knotLayer.path = knot.cgPath
        knotLayer.fillColor = color.withAlphaComponent(0.7).cgColor
        balloonView.layer.addSublayer(knotLayer)

        NSLayoutConstraint.activate([
            balloonView.widthAnchor.constraint(equalToConstant: bW),
            balloonView.heightAnchor.constraint(equalToConstant: bH + 4),
        ])

        // Label
        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .body, weight: .medium)
        label.textColor = DesignTokens.Colors.textPrimary

        // Row container
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.6)
        pill.layer.cornerRadius = DesignTokens.Radii.lg
        pill.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = UIStackView(arrangedSubviews: [balloonView, label])
        rowStack.axis = .horizontal
        rowStack.spacing = DesignTokens.Spacing.md
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(rowStack)

        let inset = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: pill.topAnchor, constant: inset),
            rowStack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -inset),
            rowStack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: DesignTokens.Spacing.lg),
            rowStack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return pill
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for row in rows { row.alpha = 1; row.transform = .identity }
            return
        }

        for (i, row) in rows.enumerated() {
            let delay = 0.15 + Double(i) * 0.2

            UIView.animate(
                withDuration: 0.5,
                delay: delay,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.3
            ) {
                row.alpha = 1
                row.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for row in rows {
            row.layer.removeAllAnimations()
        }
    }
}
