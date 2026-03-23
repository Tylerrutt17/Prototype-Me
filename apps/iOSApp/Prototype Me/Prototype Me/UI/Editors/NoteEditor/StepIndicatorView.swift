import UIKit

final class StepIndicatorView: UIView {

    var onStepTapped: ((Int) -> Void)?
    private var dots: [UIView] = []
    private var connectors: [UIView] = []
    private var labels: [UILabel] = []
    private let count: Int
    private var activeStep = 0
    private let stepNames = ["Content", "Type", "Priority", "Folder"]

    init(count: Int) {
        self.count = count
        super.init(frame: .zero)
        buildIndicator()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildIndicator() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for i in 0..<count {
            if i > 0 {
                let connector = UIView()
                connector.backgroundColor = DesignTokens.Colors.separator
                connector.translatesAutoresizingMaskIntoConstraints = false
                connector.heightAnchor.constraint(equalToConstant: 2).isActive = true
                connectors.append(connector)
                stack.addArrangedSubview(connector)
            }

            let dotContainer = UIView()
            dotContainer.translatesAutoresizingMaskIntoConstraints = false

            let dot = UIView()
            dot.layer.cornerRadius = 12
            dot.translatesAutoresizingMaskIntoConstraints = false
            dotContainer.addSubview(dot)

            let numberLabel = UILabel()
            numberLabel.text = "\(i + 1)"
            numberLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            numberLabel.textAlignment = .center
            numberLabel.translatesAutoresizingMaskIntoConstraints = false
            dotContainer.addSubview(numberLabel)

            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 24),
                dot.heightAnchor.constraint(equalToConstant: 24),
                dot.centerXAnchor.constraint(equalTo: dotContainer.centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: dotContainer.centerYAnchor),
                numberLabel.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                numberLabel.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
                dotContainer.widthAnchor.constraint(equalToConstant: 24),
                dotContainer.heightAnchor.constraint(equalToConstant: 24),
            ])

            dots.append(dot)
            labels.append(numberLabel)

            let tap = UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:)))
            dotContainer.addGestureRecognizer(tap)
            dotContainer.tag = i

            stack.addArrangedSubview(dotContainer)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // Make connectors expand to fill space
        for connector in connectors {
            connector.widthAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        }
    }

    func setActiveStep(_ step: Int) {
        activeStep = step

        for i in 0..<count {
            let dot = dots[i]
            let label = labels[i]

            if i == step {
                dot.backgroundColor = DesignTokens.Colors.accent
                label.textColor = .white
            } else if i < step {
                dot.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.3)
                label.textColor = DesignTokens.Colors.accent
            } else {
                dot.backgroundColor = DesignTokens.Colors.surfaceSecondary
                label.textColor = DesignTokens.Colors.textTertiary
            }
        }

        for (i, connector) in connectors.enumerated() {
            connector.backgroundColor = i < step
                ? DesignTokens.Colors.accent.withAlphaComponent(0.3)
                : DesignTokens.Colors.separator
        }
    }

    @objc private func dotTapped(_ gesture: UITapGestureRecognizer) {
        guard let step = gesture.view?.tag else { return }
        onStepTapped?(step)
    }
}
