import UIKit

/// Custom animated transitions between onboarding screens.
enum OnboardingTransition {

    /// Snapshot-based crossfade — particles underneath are revealed as the snapshot dissolves.
    final class Crossfade: NSObject, UIViewControllerAnimatedTransitioning {
        private let duration: TimeInterval

        init(duration: TimeInterval = 0.8) { self.duration = duration }

        func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
            duration
        }

        func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
            guard let fromView = transitionContext.view(forKey: .from),
                  let toView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }

            let container = transitionContext.containerContext
            toView.frame = container.frame
            container.insertSubview(toView, belowSubview: fromView)

            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                fromView.alpha = 0
            } completion: { _ in
                fromView.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }

    /// Slide up with slight scale — glass panel feel.
    final class SlideUp: NSObject, UIViewControllerAnimatedTransitioning {
        private let duration: TimeInterval

        init(duration: TimeInterval = 0.6) { self.duration = duration }

        func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
            duration
        }

        func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
            guard let toView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }

            let container = transitionContext.containerContext
            toView.frame = container.frame
            toView.alpha = 0
            toView.transform = CGAffineTransform(translationX: 0, y: 60)
            container.addSubview(toView)

            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.2
            ) {
                toView.alpha = 1
                toView.transform = .identity
            } completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }

    /// Brief white flash burst for celebration moments.
    final class FlashBurst: NSObject, UIViewControllerAnimatedTransitioning {
        func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
            0.4
        }

        func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
            guard let toView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }

            let container = transitionContext.containerContext
            toView.frame = container.frame
            toView.alpha = 0
            container.addSubview(toView)

            let flash = UIView(frame: container.frame)
            flash.backgroundColor = .white
            flash.alpha = 0
            container.addSubview(flash)

            // Flash up
            UIView.animate(withDuration: 0.15) {
                flash.alpha = 0.3
            } completion: { _ in
                // Flash down + reveal
                UIView.animate(withDuration: 0.25) {
                    flash.alpha = 0
                    toView.alpha = 1
                } completion: { _ in
                    flash.removeFromSuperview()
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            }
        }
    }
}

// MARK: - Container Context Helper

private extension UIViewControllerContextTransitioning {
    var containerContext: UIView { containerView }
}
