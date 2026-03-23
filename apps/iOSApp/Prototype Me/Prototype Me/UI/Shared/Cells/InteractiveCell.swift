import UIKit

/// Base collection view cell that adds a subtle press-down animation on touch.
/// Subclass this instead of UICollectionViewCell to get the effect for free.
/// Changes nothing about appearance — just adds the hover/press interaction.
class InteractiveCell: UICollectionViewCell {

    /// Scale factor when pressed. Override to customize per cell.
    var pressScale: CGFloat { 0.97 }

    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let gr = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        gr.cancelsTouchesInView = false
        gr.delegate = self
        return gr
    }()

    private lazy var holdRecognizer: UILongPressGestureRecognizer = {
        let gr = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        gr.minimumPressDuration = 0.15
        gr.cancelsTouchesInView = false
        gr.delegate = self
        return gr
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(tapRecognizer)
        addGestureRecognizer(holdRecognizer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addGestureRecognizer(tapRecognizer)
        addGestureRecognizer(holdRecognizer)
    }

    // MARK: - Tap (quick pop)

    @objc private func handleTap() {
        transform = CGAffineTransform(scaleX: pressScale, y: pressScale)
        UIView.animate(
            withDuration: 0.45,
            delay: 0.06,
            usingSpringWithDamping: 0.45,
            initialSpringVelocity: 10,
            options: .allowUserInteraction
        ) {
            self.transform = .identity
        }
    }

    // MARK: - Hold (stay pressed, spring back on release)

    @objc private func handleHold(_ gr: UILongPressGestureRecognizer) {
        switch gr.state {
        case .began:
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0,
                options: .allowUserInteraction
            ) {
                self.transform = CGAffineTransform(scaleX: self.pressScale, y: self.pressScale)
            }
        case .ended, .cancelled, .failed:
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 8,
                options: .allowUserInteraction
            ) {
                self.transform = .identity
            }
        default:
            break
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension InteractiveCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
