import UIKit

/// Adds a gradient shimmer border animation to any view.
/// Automatically restarts the animation when the app returns from background.
enum ShimmerBorder {

    private static let layerName = "shimmerBorderLayer"

    /// Adds a continuously sweeping gradient border to the view.
    static func add(
        to view: UIView,
        color: UIColor,
        cornerRadius: CGFloat? = nil,
        borderWidth: CGFloat = 1.5,
        duration: CFTimeInterval = 2.0
    ) {
        remove(from: view)

        let radius = cornerRadius ?? view.layer.cornerRadius
        let bounds = view.bounds
        guard bounds.width > 0 else { return }

        let border = ShimmerGradientLayer()
        border.name = layerName
        border.shimmerColor = color
        border.shimmerCornerRadius = radius
        border.shimmerBorderWidth = borderWidth
        border.shimmerDuration = duration
        border.colors = [
            color.withAlphaComponent(0.6).cgColor,
            color.withAlphaComponent(0.1).cgColor,
            color.withAlphaComponent(0.6).cgColor,
        ]
        border.locations = [0.0, 0.5, 1.0]
        border.startPoint = CGPoint(x: 0, y: 0.5)
        border.endPoint = CGPoint(x: 1, y: 0.5)
        border.frame = bounds

        let mask = CAShapeLayer()
        let outerPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
        let innerPath = UIBezierPath(roundedRect: bounds.insetBy(dx: borderWidth, dy: borderWidth), cornerRadius: max(0, radius - borderWidth))
        outerPath.append(innerPath)
        outerPath.usesEvenOddFillRule = true
        mask.path = outerPath.cgPath
        mask.fillRule = .evenOdd
        border.mask = mask

        view.layer.addSublayer(border)
        border.startShimmer()
    }

    /// Updates the shimmer border frame (call from layoutSubviews).
    static func updateFrame(on view: UIView, cornerRadius: CGFloat? = nil, borderWidth: CGFloat = 1.5) {
        guard let border = view.layer.sublayers?.first(where: { $0.name == layerName }) as? ShimmerGradientLayer else { return }
        let bounds = view.bounds
        let radius = cornerRadius ?? border.shimmerCornerRadius
        border.frame = bounds

        if let mask = border.mask as? CAShapeLayer {
            let bw = border.shimmerBorderWidth
            let outerPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
            let innerPath = UIBezierPath(roundedRect: bounds.insetBy(dx: bw, dy: bw), cornerRadius: max(0, radius - bw))
            outerPath.append(innerPath)
            outerPath.usesEvenOddFillRule = true
            mask.path = outerPath.cgPath
        }
    }

    /// Restarts the shimmer animation (e.g. after a tab switch).
    static func restart(on view: UIView) {
        guard let border = view.layer.sublayers?.first(where: { $0.name == layerName }) as? ShimmerGradientLayer else { return }
        border.addShimmerAnimation()
    }

    /// Removes the shimmer border from the view.
    static func remove(from view: UIView) {
        view.layer.sublayers?
            .compactMap { $0 as? ShimmerGradientLayer }
            .forEach { $0.tearDown(); $0.removeFromSuperlayer() }
    }
}

// MARK: - ShimmerGradientLayer

/// A CAGradientLayer subclass that automatically restarts its shimmer
/// animation when the app returns from background or the view reappears.
private final class ShimmerGradientLayer: CAGradientLayer {

    var shimmerColor: UIColor = .white
    var shimmerCornerRadius: CGFloat = 0
    var shimmerBorderWidth: CGFloat = 1.5
    var shimmerDuration: CFTimeInterval = 2.0

    private var observer: NSObjectProtocol?

    func startShimmer() {
        addShimmerAnimation()

        // Auto-restart when app becomes active
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.addShimmerAnimation()
        }
    }

    func tearDown() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        removeAllAnimations()
    }

    fileprivate func addShimmerAnimation() {
        removeAnimation(forKey: "shimmer")
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-0.5, -0.25, 0.0]
        anim.toValue = [1.0, 1.25, 1.5]
        anim.duration = shimmerDuration
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        add(anim, forKey: "shimmer")
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
