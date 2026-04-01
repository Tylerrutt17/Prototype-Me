import UIKit

/// Vision page: mode pills that swap in/out with different contexts,
/// showing that your system adapts to different phases of life.
final class OnboardingModesVisionView: UIView, StoryAnimatable {

    private var modePills: [UIView] = []
    private let modeColor = NoteKind.mode.color
    private var isStopped = false
    private var cycleID = 0

    private let modes: [(name: String, icon: String)] = [
        ("Deep Work", "bolt.fill"),
        ("Recovery", "heart.fill"),
        ("Social", "person.2.fill"),
        ("Growth", "chart.line.uptrend.xyaxis"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        for mode in modes {
            let pill = makeModePill(name: mode.name, icon: mode.icon)
            stack.addArrangedSubview(pill)
            modePills.append(pill)
            pill.alpha = 0
            pill.transform = CGAffineTransform(translationX: 0, y: 15).scaledBy(x: 0.95, y: 0.95)
        }
    }

    private func makeModePill(name: String, icon: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.6)
        pill.layer.cornerRadius = DesignTokens.Radii.lg
        pill.layer.borderWidth = 1.5
        pill.layer.borderColor = DesignTokens.Colors.separator.cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
        iconView.tintColor = DesignTokens.Colors.textTertiary
        iconView.contentMode = .scaleAspectFit
        iconView.tag = 10

        let label = UILabel()
        label.text = name
        label.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary

        let row = UIStackView(arrangedSubviews: [iconView, label, UIView()])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(row)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            pill.widthAnchor.constraint(equalToConstant: 220),
            row.topAnchor.constraint(equalTo: pill.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -pad),
        ])

        return pill
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        cycleID += 1
        let currentCycle = cycleID

        guard !UIAccessibility.isReduceMotionEnabled else {
            for pill in modePills { pill.alpha = 1; pill.transform = .identity }
            highlightPill(at: 0)
            return
        }

        // Stagger pills in
        for (i, pill) in modePills.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.1 + Double(i) * 0.12,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.3
            ) {
                pill.alpha = 1
                pill.transform = .identity
            }
        }

        // Start cycling highlights
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.cycleHighlight(index: 0, cycle: currentCycle)
        }
    }

    private func cycleHighlight(index: Int, cycle: Int) {
        guard !isStopped, cycleID == cycle else { return }

        // Deselect all
        for pill in modePills {
            UIView.animate(withDuration: 0.25) {
                pill.layer.borderColor = DesignTokens.Colors.separator.cgColor
                pill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.6)
                if let icon = pill.viewWithTag(10) as? UIImageView {
                    icon.tintColor = DesignTokens.Colors.textTertiary
                }
            }
        }

        highlightPill(at: index)

        let next = (index + 1) % modePills.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.cycleHighlight(index: next, cycle: cycle)
        }
    }

    private func highlightPill(at index: Int) {
        guard index < modePills.count else { return }
        let pill = modePills[index]

        UIView.animate(withDuration: 0.3) {
            pill.layer.borderColor = self.modeColor.cgColor
            pill.backgroundColor = self.modeColor.withAlphaComponent(0.08)
            if let icon = pill.viewWithTag(10) as? UIImageView {
                icon.tintColor = self.modeColor
            }
        }

        // Scale pop
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            pill.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                pill.transform = .identity
            }
        }

        Haptics.selection()
    }

    func stopAnimations() {
        isStopped = true
        for pill in modePills { pill.layer.removeAllAnimations() }
    }
}
