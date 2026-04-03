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

    private let blueprintGrid = BlueprintGridView()

    // MARK: - Content

    private let logoView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let appleButton = ASAuthorizationAppleIDButton(type: .continue, style: .white)
    private let arrowHint = UIImageView()
    private let legalStack = UIStackView()

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
        let titleFont = DesignTokens.Typography.rounded(style: .largeTitle, weight: .bold)
        let welcomeAttr: [NSAttributedString.Key: Any] = [
            .font: DesignTokens.Typography.rounded(style: .title2, weight: .medium),
            .foregroundColor: DesignTokens.Colors.accentTertiary,
        ]
        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: DesignTokens.Colors.textPrimary,
        ]
        let attributed = NSMutableAttributedString(string: "Welcome to\n", attributes: welcomeAttr)
        attributed.append(NSAttributedString(string: "Prototype Me", attributes: nameAttr))
        titleLabel.attributedText = attributed
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        subtitleLabel.text = "Optimize Your Life through Trial & Error. See What Works Best For You!"
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

        // Bouncing arrow hint
        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        arrowHint.image = UIImage(systemName: "chevron.down", withConfiguration: arrowConfig)
        arrowHint.tintColor = DesignTokens.Colors.textTertiary
        arrowHint.contentMode = .scaleAspectFit
        arrowHint.alpha = 0
        arrowHint.translatesAutoresizingMaskIntoConstraints = false

        // Legal disclaimer
        let font = DesignTokens.Typography.rounded(style: .caption2, weight: .regular)
        let linkFont = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)

        let preLabel = UILabel()
        preLabel.text = "By continuing, you agree to our"
        preLabel.font = font
        preLabel.textColor = DesignTokens.Colors.textTertiary
        preLabel.textAlignment = .center

        let tosButton = UIButton(type: .system)
        tosButton.setTitle("Terms of Service", for: .normal)
        tosButton.titleLabel?.font = linkFont
        tosButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        tosButton.addTarget(self, action: #selector(tosTapped), for: .touchUpInside)

        let andLabel = UILabel()
        andLabel.text = "and"
        andLabel.font = font
        andLabel.textColor = DesignTokens.Colors.textTertiary

        let privacyButton = UIButton(type: .system)
        privacyButton.setTitle("Privacy Policy", for: .normal)
        privacyButton.titleLabel?.font = linkFont
        privacyButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        privacyButton.addTarget(self, action: #selector(privacyTapped), for: .touchUpInside)

        let linksRow = UIStackView(arrangedSubviews: [tosButton, andLabel, privacyButton])
        linksRow.axis = .horizontal
        linksRow.spacing = 4
        linksRow.alignment = .center

        legalStack.axis = .vertical
        legalStack.spacing = 2
        legalStack.alignment = .center
        legalStack.addArrangedSubview(preLabel)
        legalStack.addArrangedSubview(linksRow)
        legalStack.alpha = 0
        legalStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(logoView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(arrowHint)
        view.addSubview(appleButton)
        view.addSubview(legalStack)

        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            logoView.widthAnchor.constraint(equalToConstant: 100),
            logoView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: DesignTokens.Spacing.xl),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),

            arrowHint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            arrowHint.bottomAnchor.constraint(equalTo: appleButton.topAnchor, constant: -DesignTokens.Spacing.md),

            appleButton.bottomAnchor.constraint(equalTo: legalStack.topAnchor, constant: -DesignTokens.Spacing.md),
            appleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            appleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),
            appleButton.heightAnchor.constraint(equalToConstant: 54),

            legalStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.md),
            legalStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            legalStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])
    }

    // MARK: - Entrance Animation

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            logoView.alpha = 1; logoView.transform = .identity
            titleLabel.alpha = 1; titleLabel.transform = .identity
            subtitleLabel.alpha = 1; subtitleLabel.transform = .identity
            appleButton.alpha = 1; appleButton.transform = .identity
            arrowHint.alpha = 1
            legalStack.alpha = 1
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

        // Arrow hint fades in and starts bouncing
        UIView.animate(withDuration: 0.4, delay: 0.7, options: .curveEaseOut) {
            self.arrowHint.alpha = 1
        } completion: { _ in
            self.startArrowBounce()
        }

        // Apple button slides up
        UIView.animate(withDuration: 0.5, delay: 0.75, options: .curveEaseOut) {
            self.appleButton.alpha = 1
            self.appleButton.transform = .identity
        }

        // Legal text fades in
        UIView.animate(withDuration: 0.4, delay: 0.9, options: .curveEaseOut) {
            self.legalStack.alpha = 1
        }
    }

    private func startArrowBounce() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(withDuration: 0.8, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.arrowHint.transform = CGAffineTransform(translationX: 0, y: 6)
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

// MARK: - Legal

extension WelcomeLoginViewController {
    @objc fileprivate func tosTapped() { presentLegal(title: "Terms of Service") }
    @objc fileprivate func privacyTapped() { presentLegal(title: "Privacy Policy") }

    private func presentLegal(title: String) {
        let vc = LegalViewController()
        vc.documentTitle = title
        let nav = UINavigationController(rootViewController: vc)
        nav.isNavigationBarHidden = true
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
}
