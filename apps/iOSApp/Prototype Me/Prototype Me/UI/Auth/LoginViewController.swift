import UIKit
import AuthenticationServices

final class LoginViewController: UIViewController {

    var authService: AuthService?
    var onLoginSuccess: (() -> Void)?

    // MARK: - Background layers

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

    private let blueprintGrid = BlueprintGridView()

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
        blueprintGrid.frame = view.bounds
        blueprintGrid.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blueprintGrid)
        buildLayout()
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
        animateEntrance()
        blueprintGrid.startAnimating()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        blueprintGrid.stopAnimating()
    }

    // MARK: - Layout

    private func buildLayout() {
        // App icon
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let lastIcon = files.last {
            logoView.image = UIImage(named: lastIcon)
        }
        logoView.contentMode = .scaleAspectFit
        logoView.layer.cornerRadius = 22
        logoView.clipsToBounds = true
        logoView.alpha = 0
        logoView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        logoView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.text = "Prototype Me"
        titleLabel.font = DesignTokens.Typography.rounded(style: .largeTitle, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        subtitleLabel.text = "Sign in with Apple to get started."
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
            logoView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -DesignTokens.Spacing.xl),
            logoView.widthAnchor.constraint(equalToConstant: 100),
            logoView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -DesignTokens.Spacing.xxl),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
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

extension LoginViewController: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        Task {
            do {
                _ = try await authService?.handleAppleCredential(credential)
                await MainActor.run {
                    Haptics.success()
                    self.onLoginSuccess?()
                }
            } catch {
                await MainActor.run {
                    Haptics.error()
                    let alert = UIAlertController(title: "Sign In Failed", message: "\(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // User cancelled — do nothing
        if (error as? ASAuthorizationError)?.code == .canceled { return }

        Haptics.error()
        let alert = UIAlertController(title: "Sign In Failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window!
    }
}
