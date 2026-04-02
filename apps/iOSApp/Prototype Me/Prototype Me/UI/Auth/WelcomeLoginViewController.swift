import UIKit
import AuthenticationServices

/// First screen a new user sees. Two paths:
/// 1. "Already have an account?" → Sign in with Apple → main app (skip onboarding)
/// 2. "Get Started" → onboarding flow
final class WelcomeLoginViewController: UIViewController {

    var authService: AuthService?
    var onSignedIn: (() -> Void)?
    var onNewUser: (() -> Void)?

    private let logoView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let getStartedButton = AppButton(title: "Get Started")
    private let existingAccountButton = UIButton(type: .system)
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
    private var showingAppleLogin = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background
        buildLayout()
    }

    private func buildLayout() {
        // Logo
        let config = UIImage.SymbolConfiguration(pointSize: 70, weight: .ultraLight)
        logoView.image = UIImage(systemName: "sparkles", withConfiguration: config)
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
        subtitleLabel.text = "Figure out what works. Build your system."
        subtitleLabel.font = DesignTokens.Typography.body
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Get started button (new users)
        getStartedButton.addTarget(self, action: #selector(getStartedTapped), for: .touchUpInside)
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(getStartedButton)

        // Existing account link
        existingAccountButton.setTitle("Already have an account? Sign in", for: .normal)
        existingAccountButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        existingAccountButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        existingAccountButton.addTarget(self, action: #selector(existingAccountTapped), for: .touchUpInside)
        existingAccountButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(existingAccountButton)

        // Apple button (hidden initially, shown when "Already have an account?" is tapped)
        appleButton.cornerRadius = DesignTokens.Radii.lg
        appleButton.addTarget(self, action: #selector(appleSignInTapped), for: .touchUpInside)
        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.alpha = 0
        appleButton.isHidden = true
        view.addSubview(appleButton)

        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),

            titleLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: DesignTokens.Spacing.xl),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),

            getStartedButton.bottomAnchor.constraint(equalTo: existingAccountButton.topAnchor, constant: -DesignTokens.Spacing.lg),
            getStartedButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            getStartedButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),

            existingAccountButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.xl),
            existingAccountButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            appleButton.bottomAnchor.constraint(equalTo: existingAccountButton.topAnchor, constant: -DesignTokens.Spacing.lg),
            appleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            appleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),
            appleButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    @objc private func getStartedTapped() {
        Haptics.medium()
        onNewUser?()
    }

    @objc private func existingAccountTapped() {
        if showingAppleLogin {
            // Already showing — trigger Apple sign in directly
            appleSignInTapped()
        } else {
            // Show the Apple button
            showingAppleLogin = true
            appleButton.isHidden = false
            UIView.animate(withDuration: 0.3) {
                self.appleButton.alpha = 1
                self.existingAccountButton.setTitle("Tap above to sign in with Apple", for: .normal)
                self.existingAccountButton.setTitleColor(DesignTokens.Colors.textTertiary, for: .normal)
            }
        }
    }

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
                _ = try await authService?.handleAppleCredential(credential)
                await MainActor.run {
                    Haptics.success()
                    self.onSignedIn?()
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
