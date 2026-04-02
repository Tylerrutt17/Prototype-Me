import UIKit
import AuthenticationServices

/// First screen a new user sees. Two paths:
/// 1. "Already have an account?" → Sign in with Apple → main app (skip onboarding)
/// 2. "Get Started" → onboarding flow
final class WelcomeLoginViewController: UIViewController {

    var authService: AuthService?
    var onSignedIn: ((_ isNewUser: Bool) -> Void)?

    // MARK: - Background

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.06, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0).cgColor,
        ]
        layer.locations = [0.0, 0.45, 1.0]
        return layer
    }()

    private var waveLayers: [CAShapeLayer] = []

    // MARK: - Content

    private let logoView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .white)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background

        view.layer.addSublayer(gradientLayer)
        setupWaves()
        buildLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = view.bounds
        CATransaction.commit()
        layoutWaves()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateEntrance()
        animateWaves()
    }

    // MARK: - Wavy Lines

    private func setupWaves() {
        let colors: [(UIColor, CGFloat)] = [
            (DesignTokens.Colors.accent, 0.12),
            (DesignTokens.Colors.accentSecondary, 0.10),
            (DesignTokens.Colors.accentTertiary, 0.08),
            (DesignTokens.Colors.accent, 0.06),
            (DesignTokens.Colors.accentSecondary, 0.05),
        ]

        for (color, alpha) in colors {
            let layer = CAShapeLayer()
            layer.strokeColor = color.withAlphaComponent(alpha).cgColor
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = 2
            layer.lineCap = .round
            view.layer.insertSublayer(layer, above: gradientLayer)
            waveLayers.append(layer)
        }
    }

    private func layoutWaves() {
        let w = view.bounds.width
        let h = view.bounds.height
        guard w > 0 else { return }

        let configs: [(yCenter: CGFloat, amplitude: CGFloat, frequency: CGFloat, phase: CGFloat, lineWidth: CGFloat)] = [
            (h * 0.20, 40, 1.5, 0.0, 2.5),
            (h * 0.30, 55, 1.0, 0.8, 2.0),
            (h * 0.45, 35, 2.0, 1.6, 1.5),
            (h * 0.65, 50, 1.2, 2.4, 2.0),
            (h * 0.78, 30, 1.8, 3.2, 1.5),
        ]

        for (i, layer) in waveLayers.enumerated() {
            guard i < configs.count else { break }
            let c = configs[i]
            layer.lineWidth = c.lineWidth
            layer.path = wavePath(width: w, yCenter: c.yCenter, amplitude: c.amplitude, frequency: c.frequency, phase: c.phase).cgPath
        }
    }

    private func wavePath(width: CGFloat, yCenter: CGFloat, amplitude: CGFloat, frequency: CGFloat, phase: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let steps = 120
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = t * width
            let y = yCenter + sin(t * frequency * 2 * .pi + phase) * amplitude
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private func animateWaves() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let durations: [CFTimeInterval] = [7.0, 9.0, 6.0, 8.0, 10.0]
        let amplitudes: [CGFloat] = [40, 55, 35, 50, 30]
        let frequencies: [CGFloat] = [1.5, 1.0, 2.0, 1.2, 1.8]
        let phases: [CGFloat] = [0.0, 0.8, 1.6, 2.4, 3.2]
        let yCenters: [CGFloat] = [0.20, 0.30, 0.45, 0.65, 0.78]

        let w = view.bounds.width
        let h = view.bounds.height

        for (i, layer) in waveLayers.enumerated() {
            guard i < durations.count else { break }

            let fromPath = wavePath(
                width: w,
                yCenter: h * yCenters[i],
                amplitude: amplitudes[i],
                frequency: frequencies[i],
                phase: phases[i]
            ).cgPath

            let toPath = wavePath(
                width: w,
                yCenter: h * yCenters[i],
                amplitude: amplitudes[i] * 0.7,
                frequency: frequencies[i],
                phase: phases[i] + .pi
            ).cgPath

            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = fromPath
            anim.toValue = toPath
            anim.duration = durations[i]
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(anim, forKey: "waveShift")
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        // Logo
        let config = UIImage.SymbolConfiguration(pointSize: 70, weight: .ultraLight)
        logoView.image = UIImage(systemName: "sparkles", withConfiguration: config)
        logoView.tintColor = DesignTokens.Colors.accent
        logoView.contentMode = .scaleAspectFit
        logoView.alpha = 0
        logoView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        logoView.translatesAutoresizingMaskIntoConstraints = false

        // Glow behind logo
        logoView.layer.shadowColor = DesignTokens.Colors.accent.cgColor
        logoView.layer.shadowRadius = 30
        logoView.layer.shadowOpacity = 0.5
        logoView.layer.shadowOffset = .zero

        // Title
        titleLabel.text = "Prototype Me"
        titleLabel.font = DesignTokens.Typography.rounded(style: .largeTitle, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        subtitleLabel.text = "Figure out what works. Build your system."
        subtitleLabel.font = DesignTokens.Typography.rounded(style: .body, weight: .regular)
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Apple sign in button
        appleButton.cornerRadius = DesignTokens.Radii.lg
        appleButton.addTarget(self, action: #selector(appleSignInTapped), for: .touchUpInside)
        appleButton.alpha = 0
        appleButton.transform = CGAffineTransform(translationX: 0, y: 20)
        appleButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(logoView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(appleButton)

        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),

            titleLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: DesignTokens.Spacing.xl),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),

            appleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.xxxl),
            appleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            appleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),
            appleButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: - Entrance Animation

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            logoView.alpha = 1; logoView.transform = .identity
            titleLabel.alpha = 1; titleLabel.transform = .identity
            subtitleLabel.alpha = 1; subtitleLabel.transform = .identity
            appleButton.alpha = 1; appleButton.transform = .identity
            return
        }

        // Logo: spring scale-in
        UIView.animate(withDuration: 0.7, delay: 0.2, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.3) {
            self.logoView.alpha = 1
            self.logoView.transform = .identity
        }

        // Title slides up
        UIView.animate(withDuration: 0.5, delay: 0.45, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }

        // Subtitle slides up
        UIView.animate(withDuration: 0.5, delay: 0.6, options: .curveEaseOut) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }

        // Apple button slides up
        UIView.animate(withDuration: 0.5, delay: 0.75, options: .curveEaseOut) {
            self.appleButton.alpha = 1
            self.appleButton.transform = .identity
        }
    }

    // MARK: - Actions

    @objc private func appleSignInTapped() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension WelcomeLoginViewController: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        Task {
            do {
                let response = try await authService?.handleAppleCredential(credential)
                let isNew = response?.isNewUser ?? true
                await MainActor.run {
                    Haptics.success()
                    self.onSignedIn?(isNew)
                }
            } catch {
                print("[Auth] Sign in failed: \(error)")
                await MainActor.run {
                    Haptics.error()
                    let message: String
                    if let apiError = error as? APIClient.APIError {
                        message = "\(apiError)"
                    } else {
                        message = "\(error)"
                    }
                    let alert = UIAlertController(title: "Sign In Failed", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as? ASAuthorizationError)?.code == .canceled { return }
        Haptics.error()
        let alert = UIAlertController(title: "Sign In Failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension WelcomeLoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window!
    }
}
