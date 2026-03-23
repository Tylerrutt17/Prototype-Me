import UIKit

final class FormToggleRow: UIView {

    private let label = UILabel()
    private let subtitleLabel = UILabel()
    let toggle = UISwitch()
    var onToggleChanged: ((Bool) -> Void)?

    init(title: String, subtitle: String? = nil) {
        super.init(frame: .zero)

        label.text = title
        label.font = DesignTokens.Typography.body
        label.textColor = DesignTokens.Colors.textPrimary

        subtitleLabel.text = subtitle
        subtitleLabel.font = DesignTokens.Typography.caption1
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isHidden = subtitle == nil

        let textStack = UIStackView(arrangedSubviews: [label, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        toggle.onTintColor = DesignTokens.Colors.accent
        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [textStack, toggle])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func toggled() {
        onToggleChanged?(toggle.isOn)
    }
}
