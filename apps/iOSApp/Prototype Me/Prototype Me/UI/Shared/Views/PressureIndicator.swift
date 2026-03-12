import UIKit

/// Small colored circle indicating balloon pressure level.
final class PressureIndicator: UIView {

    private let dot = UIView()

    var size: CGFloat = 12 {
        didSet { invalidateIntrinsicContentSize(); setNeedsLayout() }
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
        addSubview(dot)

        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: size),
            dot.heightAnchor.constraint(equalToConstant: size),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dot.layer.cornerRadius = size / 2
    }

    func configure(level: PressureLevel?) {
        guard let level else {
            dot.backgroundColor = .clear
            return
        }
        dot.backgroundColor = color(for: level)
    }

    private func color(for level: PressureLevel) -> UIColor {
        switch level {
        case .green:  return DesignTokens.Colors.success
        case .yellow: return DesignTokens.Colors.warning
        case .red:    return DesignTokens.Colors.destructive
        }
    }
}
