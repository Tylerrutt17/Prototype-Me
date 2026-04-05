import UIKit

/// Preset palette of user-selectable directive colors (hex strings).
enum DirectivePalette {
    static let swatches: [String] = [
        "#FF5959",  // red
        "#F2A640",  // orange
        "#FFCC4D",  // yellow
        "#4CD98C",  // green
        "#5ACCCC",  // teal
        "#6699FF",  // blue
        "#B780F5",  // purple
        "#FF7AB6",  // pink
    ]
}

extension UIColor {
    /// Initialize from a 6-digit hex string (with or without leading `#`).
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8)  & 0xFF) / 255.0,
            blue:  CGFloat( v        & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

/// Small filled circle showing a user-chosen directive color.
final class ColorDotView: UIView {

    private let dot = UIView()
    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!

    var size: CGFloat = 14 {
        didSet {
            widthConstraint.constant = size
            heightConstraint.constant = size
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: size, height: size)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.clipsToBounds = true
        addSubview(dot)

        widthConstraint = dot.widthAnchor.constraint(equalToConstant: size)
        heightConstraint = dot.heightAnchor.constraint(equalToConstant: size)

        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthConstraint,
            heightConstraint,
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dot.layer.cornerRadius = dot.bounds.width / 2
    }

    func configure(hex: String?) {
        if let hex, let color = UIColor(hex: hex) {
            dot.backgroundColor = color
        } else {
            dot.backgroundColor = .clear
        }
    }
}

/// Horizontal row of selectable color swatches (+ a "none" option) for directive color.
final class DirectiveColorPicker: UIView {

    var onColorChanged: ((String?) -> Void)?

    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    private var swatchButtons: [UIButton] = []
    private var noneButton = UIButton(type: .custom)

    private(set) var selectedColor: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        titleLabel.text = "COLOR (OPTIONAL)"
        titleLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textSecondary

        stackView.axis = .horizontal
        stackView.spacing = DesignTokens.Spacing.sm
        stackView.alignment = .center
        stackView.distribution = .fillEqually

        // "None" button: empty circle with a slash
        noneButton = makeSwatchButton(hex: nil)
        stackView.addArrangedSubview(noneButton)

        for hex in DirectivePalette.swatches {
            let btn = makeSwatchButton(hex: hex)
            swatchButtons.append(btn)
            stackView.addArrangedSubview(btn)
        }

        let vstack = UIStackView(arrangedSubviews: [titleLabel, stackView])
        vstack.axis = .vertical
        vstack.spacing = DesignTokens.Spacing.sm
        vstack.alignment = .fill
        vstack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vstack)

        NSLayoutConstraint.activate([
            vstack.topAnchor.constraint(equalTo: topAnchor),
            vstack.leadingAnchor.constraint(equalTo: leadingAnchor),
            vstack.trailingAnchor.constraint(equalTo: trailingAnchor),
            vstack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateSelection()
    }

    private func makeSwatchButton(hex: String?) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.layer.cornerRadius = 14
        btn.layer.borderWidth = 2
        btn.clipsToBounds = false

        if let hex, let color = UIColor(hex: hex) {
            btn.backgroundColor = color
            btn.accessibilityLabel = hex
        } else {
            // "None" swatch — empty surface with diagonal slash
            btn.backgroundColor = DesignTokens.Colors.surfaceSecondary
            btn.setImage(UIImage(systemName: "slash.circle"), for: .normal)
            btn.tintColor = DesignTokens.Colors.textTertiary
            btn.accessibilityLabel = "None"
        }

        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 28),
            btn.heightAnchor.constraint(equalToConstant: 28),
        ])

        btn.addAction(UIAction { [weak self, hex] _ in
            self?.selectColor(hex)
        }, for: .touchUpInside)

        return btn
    }

    func setColor(_ hex: String?) {
        selectedColor = hex
        updateSelection()
    }

    private func selectColor(_ hex: String?) {
        selectedColor = hex
        updateSelection()
        onColorChanged?(hex)
    }

    private func updateSelection() {
        let ringColor = DesignTokens.Colors.textPrimary.cgColor
        let clearColor = UIColor.clear.cgColor

        noneButton.layer.borderColor = (selectedColor == nil) ? ringColor : clearColor
        for (i, hex) in DirectivePalette.swatches.enumerated() {
            swatchButtons[i].layer.borderColor = (selectedColor == hex) ? ringColor : clearColor
        }
    }
}
