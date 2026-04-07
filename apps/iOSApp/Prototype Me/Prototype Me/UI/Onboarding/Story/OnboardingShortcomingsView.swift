import UIKit

/// Shows weak points split into two columns — "Generally" and "Situational" —
/// with pills animating in one by one under each header.
final class OnboardingShortcomingsView: UIView, StoryAnimatable {

    private let columnsStack = UIStackView()
    private var generalPills: [UIView] = []
    private var situationalPills: [UIView] = []

    var prefersFullWidth: Bool { true }

    private let generalProblems: [(text: String, icon: String)] = [
        ("I feel tired a lot", "zzz"),
        ("I don't drink enough water", "drop.fill"),
        ("I'm always on my phone", "iphone"),
    ]

    private let situationalProblems: [(text: String, icon: String)] = [
        ("Eyes get strained at work", "eye"),
        ("Trouble staying focused", "bolt.slash.fill"),
        ("I sit too long without moving", "figure.stand"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Build

    private func buildLayout() {
        columnsStack.axis = .horizontal
        columnsStack.spacing = DesignTokens.Spacing.md
        columnsStack.distribution = .fillEqually
        columnsStack.alignment = .top
        columnsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(columnsStack)

        NSLayoutConstraint.activate([
            columnsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            columnsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            columnsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        // General column
        let fwColor = NoteKind.framework.color
        let generalColumn = makeColumn(
            headerText: "GENERALLY",
            subheaderText: "All the time",
            emphasizeSubheader: false,
            headerIcon: "star.fill",
            headerColor: fwColor,
            problems: generalProblems,
            pillColor: fwColor,
            pillsOut: &generalPills
        )
        columnsStack.addArrangedSubview(generalColumn)

        // Situational column
        let modeColor = NoteKind.mode.color
        let situationalColumn = makeColumn(
            headerText: "SITUATIONAL",
            subheaderText: "- At work - example",
            emphasizeSubheader: true,
            headerIcon: "bolt.fill",
            headerColor: modeColor,
            problems: situationalProblems,
            pillColor: modeColor,
            pillsOut: &situationalPills
        )
        columnsStack.addArrangedSubview(situationalColumn)
    }

    private func makeColumn(
        headerText: String,
        subheaderText: String,
        emphasizeSubheader: Bool,
        headerIcon: String,
        headerColor: UIColor,
        problems: [(text: String, icon: String)],
        pillColor: UIColor,
        pillsOut: inout [UIView]
    ) -> UIView {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: headerIcon, withConfiguration: iconConfig))
        iconView.tintColor = headerColor
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let headerLabel = UILabel()
        headerLabel.text = headerText
        headerLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        headerLabel.textColor = headerColor

        let headerRow = UIStackView(arrangedSubviews: [iconView, headerLabel, UIView()])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.xs
        headerRow.alignment = .center

        // Subheader: indented to align with the header *text* (past the icon),
        // so it reads as a qualifier on the section title rather than a caption
        // floating under the icon.
        let subheaderLabel = UILabel()
        subheaderLabel.text = subheaderText
        if emphasizeSubheader {
            subheaderLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
            subheaderLabel.textColor = headerColor
        } else {
            subheaderLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .regular)
            subheaderLabel.textColor = DesignTokens.Colors.textTertiary
        }

        // Indent == icon width (12) + headerRow spacing (xs).
        let indent: CGFloat = 12 + DesignTokens.Spacing.xs
        let indentSpacer = UIView()
        indentSpacer.translatesAutoresizingMaskIntoConstraints = false
        indentSpacer.widthAnchor.constraint(equalToConstant: indent).isActive = true
        indentSpacer.setContentHuggingPriority(.required, for: .horizontal)

        let subheaderRow = UIStackView(arrangedSubviews: [indentSpacer, subheaderLabel, UIView()])
        subheaderRow.axis = .horizontal
        subheaderRow.spacing = 0
        subheaderRow.alignment = .center

        let headerGroup = UIStackView(arrangedSubviews: [headerRow, subheaderRow])
        headerGroup.axis = .vertical
        headerGroup.spacing = 2
        headerGroup.alignment = .fill

        let pillStack = UIStackView()
        pillStack.axis = .vertical
        pillStack.spacing = DesignTokens.Spacing.xs
        pillStack.alignment = .fill

        for problem in problems {
            let pill = makePill(text: problem.text, icon: problem.icon, color: pillColor)
            pill.alpha = 0
            pill.transform = CGAffineTransform(translationX: 0, y: 12)
            pillStack.addArrangedSubview(pill)
            pillsOut.append(pill)
        }

        let column = UIStackView(arrangedSubviews: [headerGroup, pillStack])
        column.axis = .vertical
        column.spacing = DesignTokens.Spacing.sm
        return column
    }

    private func makePill(text: String, icon: String, color: UIColor) -> UIView {
        let pill = UIView()
        pill.backgroundColor = color.withAlphaComponent(0.08)
        pill.layer.cornerRadius = DesignTokens.Radii.sm
        pill.layer.borderWidth = 1
        pill.layer.borderColor = color.withAlphaComponent(0.25).cgColor

        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        label.textColor = color
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        let pad = DesignTokens.Spacing.sm
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -pad),
        ])

        return pill
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        let allPills = generalPills + situationalPills
        for pill in allPills {
            pill.alpha = 0
            pill.transform = CGAffineTransform(translationX: 0, y: 12)
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            for pill in allPills { pill.alpha = 1; pill.transform = .identity }
            return
        }

        // Animate general pills, then situational pills
        for (i, pill) in generalPills.enumerated() {
            UIView.animate(
                withDuration: 0.4,
                delay: 0.15 + Double(i) * 0.2,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                pill.alpha = 1
                pill.transform = .identity
            }
        }

        let situationalStart = 0.15 + Double(generalPills.count) * 0.2 + 0.15
        for (i, pill) in situationalPills.enumerated() {
            UIView.animate(
                withDuration: 0.4,
                delay: situationalStart + Double(i) * 0.2,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                pill.alpha = 1
                pill.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for pill in generalPills + situationalPills {
            pill.layer.removeAllAnimations()
        }
        columnsStack.layer.removeAllAnimations()
    }
}
