import UIKit

final class FormTextField: UIView {

    private let label = UILabel()
    let textField = UITextField()
    var onTextChanged: ((String) -> Void)?

    init(title: String, placeholder: String = "") {
        super.init(frame: .zero)

        label.text = title
        label.font = DesignTokens.Typography.caption1
        label.textColor = DesignTokens.Colors.textSecondary

        textField.font = DesignTokens.Typography.body
        textField.textColor = DesignTokens.Colors.textPrimary
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: DesignTokens.Colors.textTertiary]
        )
        textField.backgroundColor = DesignTokens.Colors.surfaceSecondary
        textField.layer.cornerRadius = DesignTokens.Radii.sm
        textField.clipsToBounds = true
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: DesignTokens.Spacing.md, height: 0))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: DesignTokens.Spacing.md, height: 0))
        textField.rightViewMode = .always
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        textField.delegate = self

        let stack = UIStackView(arrangedSubviews: [label, textField])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func textDidChange() {
        onTextChanged?(textField.text ?? "")
    }
}

extension FormTextField: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
