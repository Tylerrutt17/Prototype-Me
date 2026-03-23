import UIKit

// MARK: - TappableCardView

final class TappableCardView: UIView {

    private let onTap: () -> Void

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: .zero)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() {
        UIView.animate(withDuration: 0.08) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        } completion: { _ in
            UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 5) {
                self.transform = .identity
            }
            self.onTap()
        }
    }
}

// MARK: - BlockTapGesture

final class BlockTapGesture: UITapGestureRecognizer {
    private let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(fired))
    }
    @objc private func fired() { action() }
}
