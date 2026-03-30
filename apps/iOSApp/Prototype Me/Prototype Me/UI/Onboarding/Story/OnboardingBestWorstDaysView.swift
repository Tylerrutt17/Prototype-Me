import UIKit

/// Screen 3: Two big rating circles (great day vs rough day) with a "?" between them.
/// Simple, visual question: what made these different?
final class OnboardingBestWorstDaysView: UIView, StoryAnimatable {

    private let bestCircle = UIView()
    private let bestLabel = UILabel()
    private let bestDayLabel = UILabel()

    private let worstCircle = UIView()
    private let worstLabel = UILabel()
    private let worstDayLabel = UILabel()

    private let questionLabel = UILabel()
    private let vsLabel = UILabel()

    private var hasBuilt = false

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildVisual()
        }
    }

    private func buildVisual() {
        let circleSize: CGFloat = 80

        // Best day circle
        bestCircle.backgroundColor = DesignTokens.Colors.success.withAlphaComponent(0.2)
        bestCircle.layer.cornerRadius = circleSize / 2
        bestCircle.layer.borderWidth = 2
        bestCircle.layer.borderColor = DesignTokens.Colors.success.withAlphaComponent(0.4).cgColor
        bestCircle.translatesAutoresizingMaskIntoConstraints = false

        bestLabel.text = "9"
        bestLabel.font = DesignTokens.Typography.rounded(style: .largeTitle, weight: .bold)
        bestLabel.textColor = DesignTokens.Colors.success
        bestLabel.textAlignment = .center
        bestLabel.translatesAutoresizingMaskIntoConstraints = false
        bestCircle.addSubview(bestLabel)

        bestDayLabel.text = "Best day"
        bestDayLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        bestDayLabel.textColor = DesignTokens.Colors.success
        bestDayLabel.textAlignment = .center
        bestDayLabel.translatesAutoresizingMaskIntoConstraints = false

        // Worst day circle
        worstCircle.backgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.2)
        worstCircle.layer.cornerRadius = circleSize / 2
        worstCircle.layer.borderWidth = 2
        worstCircle.layer.borderColor = DesignTokens.Colors.destructive.withAlphaComponent(0.4).cgColor
        worstCircle.translatesAutoresizingMaskIntoConstraints = false

        worstLabel.text = "3"
        worstLabel.font = DesignTokens.Typography.rounded(style: .largeTitle, weight: .bold)
        worstLabel.textColor = DesignTokens.Colors.destructive
        worstLabel.textAlignment = .center
        worstLabel.translatesAutoresizingMaskIntoConstraints = false
        worstCircle.addSubview(worstLabel)

        worstDayLabel.text = "Worst day"
        worstDayLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        worstDayLabel.textColor = DesignTokens.Colors.destructive
        worstDayLabel.textAlignment = .center
        worstDayLabel.translatesAutoresizingMaskIntoConstraints = false

        // Question mark
        questionLabel.text = "?"
        questionLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        questionLabel.textColor = DesignTokens.Colors.accent
        questionLabel.textAlignment = .center
        questionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Layout: best circle ... ? ... worst circle (horizontal, centered)
        let bestStack = UIStackView(arrangedSubviews: [bestCircle, bestDayLabel])
        bestStack.axis = .vertical
        bestStack.spacing = DesignTokens.Spacing.sm
        bestStack.alignment = .center

        let worstStack = UIStackView(arrangedSubviews: [worstCircle, worstDayLabel])
        worstStack.axis = .vertical
        worstStack.spacing = DesignTokens.Spacing.sm
        worstStack.alignment = .center

        let mainRow = UIStackView(arrangedSubviews: [bestStack, questionLabel, worstStack])
        mainRow.axis = .horizontal
        mainRow.spacing = DesignTokens.Spacing.xxl
        mainRow.alignment = .center
        mainRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainRow)

        NSLayoutConstraint.activate([
            bestCircle.widthAnchor.constraint(equalToConstant: circleSize),
            bestCircle.heightAnchor.constraint(equalToConstant: circleSize),
            bestLabel.centerXAnchor.constraint(equalTo: bestCircle.centerXAnchor),
            bestLabel.centerYAnchor.constraint(equalTo: bestCircle.centerYAnchor),

            worstCircle.widthAnchor.constraint(equalToConstant: circleSize),
            worstCircle.heightAnchor.constraint(equalToConstant: circleSize),
            worstLabel.centerXAnchor.constraint(equalTo: worstCircle.centerXAnchor),
            worstLabel.centerYAnchor.constraint(equalTo: worstCircle.centerYAnchor),

            mainRow.centerXAnchor.constraint(equalTo: centerXAnchor),
            mainRow.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Start hidden
        bestStack.alpha = 0
        bestStack.transform = CGAffineTransform(translationX: -20, y: 0)
        worstStack.alpha = 0
        worstStack.transform = CGAffineTransform(translationX: 20, y: 0)
        questionLabel.alpha = 0
        questionLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for v in subviews.flatMap({ ($0 as? UIStackView)?.arrangedSubviews ?? [$0] }) {
                v.alpha = 1; v.transform = .identity
            }
            return
        }

        guard let mainRow = subviews.first(where: { $0 is UIStackView }) as? UIStackView,
              mainRow.arrangedSubviews.count == 3 else { return }

        let bestStack = mainRow.arrangedSubviews[0]
        let worstStack = mainRow.arrangedSubviews[2]

        // Best slides in from left
        UIView.animate(withDuration: 0.5, delay: 0.2, options: .curveEaseOut) {
            bestStack.alpha = 1
            bestStack.transform = .identity
        }

        // Worst slides in from right
        UIView.animate(withDuration: 0.5, delay: 0.5, options: .curveEaseOut) {
            worstStack.alpha = 1
            worstStack.transform = .identity
        }

        // "?" pops in
        UIView.animate(withDuration: 0.4, delay: 0.9, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.questionLabel.alpha = 1
            self.questionLabel.transform = .identity
        }
    }

    func stopAnimations() {
        layer.removeAllAnimations()
        for v in subviews { v.layer.removeAllAnimations() }
    }
}
