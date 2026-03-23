import UIKit

final class FormTextView: UIView, UITextViewDelegate {

    private let label = UILabel()
    let textView = UITextView()
    var onTextChanged: ((String) -> Void)?

    init(title: String, minHeight: CGFloat = 120) {
        super.init(frame: .zero)

        label.text = title
        label.font = DesignTokens.Typography.caption1
        label.textColor = DesignTokens.Colors.textSecondary

        textView.font = DesignTokens.Typography.body
        textView.textColor = DesignTokens.Colors.textPrimary
        textView.backgroundColor = DesignTokens.Colors.surfaceSecondary
        textView.layer.cornerRadius = DesignTokens.Radii.sm
        textView.clipsToBounds = true
        textView.textContainerInset = UIEdgeInsets(
            top: DesignTokens.Spacing.md,
            left: DesignTokens.Spacing.sm,
            bottom: DesignTokens.Spacing.md,
            right: DesignTokens.Spacing.sm
        )
        textView.isScrollEnabled = false
        textView.delegate = self

        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard)),
        ]
        toolbar.tintColor = DesignTokens.Colors.accent
        textView.inputAccessoryView = toolbar

        let stack = UIStackView(arrangedSubviews: [label, textView])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    func textViewDidChange(_ textView: UITextView) {
        onTextChanged?(textView.text)
    }
}
