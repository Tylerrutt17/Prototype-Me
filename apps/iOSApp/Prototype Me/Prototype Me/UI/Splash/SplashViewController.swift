import UIKit

final class SplashViewController: UIViewController {

    var onFinished: (() -> Void)?

    // MARK: - Background

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.06, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0).cgColor,
        ]
        layer.locations = [0.0, 0.45, 1.0]
        layer.opacity = 0
        return layer
    }()

    private let blueprintGrid: BlueprintGridView = {
        let grid = BlueprintGridView()
        grid.alpha = 0
        return grid
    }()

    // MARK: - Content

    private let glowView: UIView = {
        let v = UIView()
        v.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.15)
        v.layer.cornerRadius = 60
        v.alpha = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "SplashIcon"))
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 24
        iv.clipsToBounds = true
        iv.alpha = 0
        iv.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Prototype Me"
        label.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        label.textColor = DesignTokens.Colors.textPrimary
        label.textAlignment = .center
        label.alpha = 0
        label.transform = CGAffineTransform(translationX: 0, y: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Start pure black to match the launch screen
        view.backgroundColor = .black

        view.layer.addSublayer(gradientLayer)
        blueprintGrid.frame = view.bounds
        blueprintGrid.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blueprintGrid)

        view.addSubview(glowView)
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            iconImageView.widthAnchor.constraint(equalToConstant: 100),
            iconImageView.heightAnchor.constraint(equalToConstant: 100),

            glowView.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
            glowView.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            glowView.widthAnchor.constraint(equalToConstant: 120),
            glowView.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = view.bounds
        CATransaction.commit()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        blueprintGrid.startAnimating()
        animateEntrance()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        blueprintGrid.stopAnimating()
    }

    // MARK: - Animation

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            gradientLayer.opacity = 1
            blueprintGrid.alpha = 1
            glowView.alpha = 1
            iconImageView.alpha = 1; iconImageView.transform = .identity
            titleLabel.alpha = 1; titleLabel.transform = .identity
            scheduleExit()
            return
        }

        // Phase 1: Black → gradient + grid fades in
        let gradientAnim = CABasicAnimation(keyPath: "opacity")
        gradientAnim.fromValue = 0
        gradientAnim.toValue = 1
        gradientAnim.duration = 0.6
        gradientAnim.fillMode = .forwards
        gradientAnim.isRemovedOnCompletion = false
        gradientLayer.add(gradientAnim, forKey: "fadeIn")

        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseOut) {
            self.blueprintGrid.alpha = 1
        }

        // Phase 2: Icon springs in over the gradient
        UIView.animate(withDuration: 0.6, delay: 0.15, options: .curveEaseOut) {
            self.glowView.alpha = 1
        }

        UIView.animate(withDuration: 0.7, delay: 0.15, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.3) {
            self.iconImageView.alpha = 1
            self.iconImageView.transform = .identity
        }

        // Phase 3: Title slides up
        UIView.animate(withDuration: 0.5, delay: 0.4, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        } completion: { _ in
            self.scheduleExit()
        }
    }

    private func scheduleExit() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.animateExit()
        }
    }

    private func animateExit() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            onFinished?()
            return
        }

        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseIn, animations: {
            self.view.alpha = 0
            self.iconImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: { _ in
            self.onFinished?()
        })
    }
}
