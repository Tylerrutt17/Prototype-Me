import UIKit

final class FormSegmentedRow: UIView {

    private let label = UILabel()
    private let infoButton = UIButton(type: .system)
    let segmentedControl: UISegmentedControl
    var onSelectionChanged: ((Int) -> Void)?
    var onInfoTapped: (() -> Void)? {
        didSet { infoButton.isHidden = onInfoTapped == nil }
    }

    init(title: String, items: [String]) {
        segmentedControl = UISegmentedControl(items: items)
        super.init(frame: .zero)

        label.text = title
        label.font = DesignTokens.Typography.caption1
        label.textColor = DesignTokens.Colors.textSecondary

        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        infoButton.setImage(UIImage(systemName: "info.circle", withConfiguration: config), for: .normal)
        infoButton.tintColor = DesignTokens.Colors.textTertiary
        infoButton.isHidden = true
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)

        let titleRow = UIStackView(arrangedSubviews: [label, infoButton, UIView()])
        titleRow.axis = .horizontal
        titleRow.spacing = DesignTokens.Spacing.xs
        titleRow.alignment = .center

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [titleRow, segmentedControl])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
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

    @objc private func selectionChanged() {
        onSelectionChanged?(segmentedControl.selectedSegmentIndex)
    }

    @objc private func infoTapped() {
        onInfoTapped?()
    }
}
