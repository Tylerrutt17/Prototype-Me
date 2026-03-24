import UIKit
import GRDB

/// Compact collection view cell for schedule rows with a tappable checkbox.
final class ScheduleInstanceRowCell: InteractiveCell {

    static let reuseID = "ScheduleInstanceRowCell"

    var dbQueue: DatabaseQueue?

    var onChevronTapped: (() -> Void)?

    private let checkboxButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let chevronButton = UIButton(type: .system)
    private var currentRule: ScheduleRule?
    private var wasCompleted = false
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        checkboxButton.setPreferredSymbolConfiguration(config, forImageIn: .normal)
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        checkboxButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkboxButton)

        titleLabel.font = DesignTokens.Typography.body
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        chevronButton.setImage(UIImage(systemName: "chevron.right", withConfiguration: chevronConfig), for: .normal)
        chevronButton.tintColor = DesignTokens.Colors.textTertiary
        chevronButton.addTarget(self, action: #selector(chevronTapped), for: .touchUpInside)
        chevronButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chevronButton)

        NSLayoutConstraint.activate([
            checkboxButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            checkboxButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxButton.widthAnchor.constraint(equalToConstant: 32),
            checkboxButton.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: DesignTokens.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: chevronButton.leadingAnchor, constant: -DesignTokens.Spacing.sm),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            chevronButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.md),
            chevronButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 32),
            chevronButton.heightAnchor.constraint(equalToConstant: 32),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.attributedText = nil
        titleLabel.text = nil
        currentRule = nil
        wasCompleted = false
        isAnimating = false
        contentView.layer.sublayers?.removeAll(where: { $0.name == "checkSweep" })
    }

    func configure(with row: ScheduleInstanceRow) {
        let previouslyCompleted = wasCompleted
        let nowCompleted = row.isCompletedToday
        let wasChecking = !previouslyCompleted && nowCompleted
        let wasUnchecking = previouslyCompleted && !nowCompleted
        currentRule = row.rule
        wasCompleted = nowCompleted
        let title = row.directiveTitle

        if nowCompleted {
            checkboxButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
            checkboxButton.tintColor = DesignTokens.Colors.success
            titleLabel.attributedText = strikethrough(title)

            if wasChecking && !isAnimating {
                playCheckAnimation()
            }
        } else {
            checkboxButton.setImage(UIImage(systemName: "circle"), for: .normal)
            checkboxButton.tintColor = DesignTokens.Colors.textSecondary
            titleLabel.attributedText = nil
            titleLabel.text = title
            titleLabel.textColor = DesignTokens.Colors.textPrimary

            if wasUnchecking && !isAnimating {
                playUncheckAnimation()
            }
        }
    }

    @objc private func chevronTapped() {
        onChevronTapped?()
    }

    func toggleStatus() {
        checkboxTapped()
    }

    @objc private func checkboxTapped() {
        guard let rule = currentRule, let dbQueue else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let todayStr = fmt.string(from: Date())
        let isCompleted = rule.lastCompletedDate == todayStr
        let newDate: String? = isCompleted ? nil : todayStr

        do {
            try dbQueue.write { db in
                guard var r = try ScheduleRule.fetchOne(db, key: rule.id) else { return }
                r.lastCompletedDate = newDate
                try r.update(db)
            }
            Haptics.selection()
        } catch {
            Haptics.error()
        }
    }

    // MARK: - Check Animation

    private func playCheckAnimation() {
        isAnimating = true

        // Checkbox spring pop
        checkboxButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 12) {
            self.checkboxButton.transform = .identity
        }

        // Green sweep left -> right
        let sweep = CAGradientLayer()
        sweep.name = "checkSweep"
        sweep.frame = contentView.bounds
        sweep.colors = [
            DesignTokens.Colors.success.withAlphaComponent(0.2).cgColor,
            DesignTokens.Colors.success.withAlphaComponent(0.08).cgColor,
            UIColor.clear.cgColor,
        ]
        sweep.startPoint = CGPoint(x: 0, y: 0.5)
        sweep.endPoint = CGPoint(x: 1, y: 0.5)
        sweep.locations = [-0.3, 0.0, 0.3]
        contentView.layer.insertSublayer(sweep, at: 0)

        let sweepAnim = CABasicAnimation(keyPath: "locations")
        sweepAnim.fromValue = [-0.3, 0.0, 0.3]
        sweepAnim.toValue = [0.7, 1.0, 1.3]
        sweepAnim.duration = 0.4
        sweepAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        sweepAnim.isRemovedOnCompletion = false
        sweepAnim.fillMode = .forwards
        sweep.add(sweepAnim, forKey: "sweep")

        // Fade out the sweep
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.duration = 0.3
        fade.beginTime = CACurrentMediaTime() + 0.3
        fade.isRemovedOnCompletion = false
        fade.fillMode = .forwards
        sweep.add(fade, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            sweep.removeFromSuperlayer()
            self?.isAnimating = false
        }
    }

    private func playUncheckAnimation() {
        isAnimating = true

        // Checkbox scale bounce
        checkboxButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 5) {
            self.checkboxButton.transform = .identity
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isAnimating = false
        }
    }

    private func strikethrough(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: DesignTokens.Colors.textTertiary,
        ])
    }
}
