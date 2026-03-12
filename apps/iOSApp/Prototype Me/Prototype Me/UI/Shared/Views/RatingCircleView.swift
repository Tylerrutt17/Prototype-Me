import UIKit

/// Circular view displaying a numeric day rating (1–10), color-coded by value.
final class RatingCircleView: UIView {

    private let label = UILabel()
    private var widthConstraint: NSLayoutConstraint!

    var diameter: CGFloat = 32 {
        didSet {
            widthConstraint.constant = diameter
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: diameter, height: diameter)
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
        clipsToBounds = true

        label.font = DesignTokens.Typography.rounded(style: .footnote, weight: .bold)
        label.textAlignment = .center
        label.textColor = DesignTokens.Colors.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        widthConstraint = widthAnchor.constraint(equalToConstant: diameter)
        NSLayoutConstraint.activate([
            widthConstraint,
            heightAnchor.constraint(equalTo: widthAnchor),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }

    func configure(rating: Int?) {
        guard let rating else {
            label.text = "–"
            backgroundColor = DesignTokens.Colors.surfaceTertiary
            return
        }
        label.text = "\(rating)"
        backgroundColor = color(for: rating).withAlphaComponent(0.25)
        label.textColor = color(for: rating)
    }

    private func color(for rating: Int) -> UIColor {
        switch rating {
        case 1...3:  return DesignTokens.Colors.destructive
        case 4...5:  return DesignTokens.Colors.warning
        case 6...7:  return UIColor(red: 1.0, green: 0.76, blue: 0.03, alpha: 1.0)
        default:     return DesignTokens.Colors.success
        }
    }
}
