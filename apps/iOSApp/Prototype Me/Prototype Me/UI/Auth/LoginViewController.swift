import UIKit
import AuthenticationServices

final class LoginViewController: UIViewController {

    var authService: AuthService?
    var onLoginSuccess: (() -> Void)?
    var onSkip: (() -> Void)?

    private let logoView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
    private let skipButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background
        buildLayout()
    }

    private func buildLayout() {
        // App icon / logo
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        logoView.image = UIImage(systemName: "person.crop.circle.badge.checkmark", withConfiguration: config)
        logoView.tintColor = DesignTokens.Colors.accent
        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoView)

        // Title
        titleLabel.text = "Prototype Me"
        titleLabel.font = DesignTokens.Typography.rounded(style: .largeTitle, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text = "Sign in to sync your data across devices and unlock all features."
        subtitleLabel.font = DesignTokens.Typography.body
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Apple sign in button
        appleButton.cornerRadius = DesignTokens.Radii.lg
        appleButton.addTarget(self, action: #selector(appleSignInTapped), for: .touchUpInside)
        appleButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appleButton)

        // Skip button
        skipButton.setTitle("Continue without an account", for: .normal)
        skipButton.titleLabel?.font = DesignTokens.Typography.subheadline
        skipButton.setTitleColor(DesignTokens.Colors.textTertiary, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -DesignTokens.Spacing.xl),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -DesignTokens.Spacing.xxxl),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),

            appleButton.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -DesignTokens.Spacing.lg),
            appleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            appleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),
            appleButton.heightAnchor.constraint(equalToConstant: 50),

            skipButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.xl),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func appleSignInTapped() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    @objc private func skipTapped() {
        onSkip?()
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
