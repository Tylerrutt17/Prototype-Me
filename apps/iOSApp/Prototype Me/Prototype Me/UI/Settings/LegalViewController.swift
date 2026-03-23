import UIKit

/// Scrollable legal text presented as a sheet. Handles both Terms of Service and Privacy Policy.
class LegalViewController: BaseViewController {

    var documentTitle: String = "Legal"

    private let scrollView = UIScrollView()
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle(documentTitle, animated: false)
        navBar.setLeftButton(title: "Done", systemImage: nil) { [weak self] in
            self?.dismiss(animated: true)
        }
        setupLayout()
        loadContent()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(
            top: DesignTokens.Spacing.lg,
            left: DesignTokens.Spacing.lg,
            bottom: DesignTokens.Spacing.xxxl,
            right: DesignTokens.Spacing.lg
        )
        textView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(textView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            textView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            textView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Content

    private func loadContent() {
        let body: String = documentTitle == "Privacy Policy" ? Self.privacyPolicy : Self.termsOfService

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6

        let attributed = NSMutableAttributedString(string: body, attributes: [
            .font: DesignTokens.Typography.body,
            .foregroundColor: DesignTokens.Colors.textPrimary,
            .paragraphStyle: style,
        ])

        // Style headings (lines starting with ##)
        let lines = body.components(separatedBy: "\n")
        var location = 0
        for line in lines {
            if line.hasPrefix("## ") {
                let headingRange = NSRange(location: location, length: line.count)
                attributed.addAttributes([
                    .font: DesignTokens.Typography.rounded(style: .headline, weight: .bold),
                    .foregroundColor: DesignTokens.Colors.textPrimary,
                ], range: headingRange)
            }
            location += line.count + 1  // +1 for newline
        }

        textView.attributedText = attributed
    }

    // MARK: - Legal Text

    private static let termsOfService = """
    ## Terms of Service

    Last updated: March 2026

    Welcome to Prototype Me. By using our app, you agree to these Terms of Service. Please read them carefully.

    ## 1. Acceptance of Terms

    By accessing or using Prototype Me ("the App"), you agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree, do not use the App.

    ## 2. Description of Service

    Prototype Me is a personal development app that helps you build habits, track directives, journal daily, and receive AI-powered suggestions. The App stores data locally on your device and optionally syncs with our servers.

    ## 3. User Accounts

    You may use the App anonymously or create an account. If you create an account, you are responsible for maintaining the security of your credentials. You must not share your account with others.

    ## 4. Acceptable Use

    You agree not to:
    • Use the App for any illegal purpose
    • Attempt to reverse-engineer, decompile, or disassemble the App
    • Interfere with or disrupt the App's servers or networks
    • Upload malicious content or attempt to gain unauthorized access
    • Use the App to harass, abuse, or harm others

    ## 5. AI Features

    The App includes AI-powered suggestions. These are generated for informational purposes only and should not be considered professional advice (medical, legal, financial, or otherwise). You are responsible for any decisions you make based on AI suggestions.

    ## 6. Subscription & Payments

    Some features require a Pro subscription. Subscriptions are billed through the Apple App Store. You can manage or cancel your subscription in your device's Settings. Refunds are subject to Apple's refund policies.

    ## 7. Intellectual Property

    The App and its content (excluding your personal data) are owned by TapTwice Digital. You retain ownership of all content you create within the App.

    ## 8. Data & Privacy

    Your data is handled as described in our Privacy Policy. We take your privacy seriously and do not sell your personal information.

    ## 9. Disclaimer of Warranties

    The App is provided "as is" without warranties of any kind. We do not guarantee that the App will be uninterrupted, error-free, or free of harmful components.

    ## 10. Limitation of Liability

    To the fullest extent permitted by law, TapTwice Digital shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App.

    ## 11. Changes to Terms

    We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the new Terms. We will notify you of significant changes through the App.

    ## 12. Termination

    We reserve the right to suspend or terminate your access to the App at any time for violation of these Terms.

    ## 13. Contact

    If you have questions about these Terms, contact us at support@prototypeme.app.
    """

    private static let privacyPolicy = """
    ## Privacy Policy

    Last updated: March 2026

    TapTwice Digital ("we", "our", "us") operates Prototype Me. This Privacy Policy explains how we collect, use, and protect your information.

    ## 1. Information We Collect

    Local Data: The App stores your notes, directives, diary entries, schedules, and preferences locally on your device using an encrypted SQLite database.

    Synced Data: If you enable sync, your data is transmitted to our servers over encrypted connections (TLS 1.3) and stored in an encrypted database.

    Account Data: If you create an account, we store your email address, display name, and authentication tokens.

    Usage Analytics: We collect anonymous usage metrics (feature usage, crash reports) to improve the App. No personally identifiable information is included.

    AI Interactions: When you use AI features, your prompts and relevant context (directive titles, diary excerpts) are sent to our servers for processing. We do not store AI conversation history beyond what is needed to generate a response.

    ## 2. How We Use Your Information

    • To provide and improve the App's features
    • To sync your data across devices (when enabled)
    • To generate AI-powered suggestions
    • To send you notifications you've opted into
    • To diagnose technical issues and prevent abuse

    ## 3. Data Sharing

    We do not sell your personal information. We may share data with:

    • AI Processing Partners: We use third-party AI services to generate suggestions. Only the minimum necessary context is shared, and these partners are contractually bound to protect your data.
    • Infrastructure Providers: Our servers run on cloud infrastructure. Data is encrypted at rest and in transit.
    • Legal Requirements: We may disclose information if required by law or to protect our rights.

    ## 4. Data Retention

    Your local data remains on your device until you delete it. Synced data is retained on our servers as long as you have an active account. If you delete your account, all server-side data is permanently deleted within 30 days.

    ## 5. Security

    We implement industry-standard security measures:
    • End-to-end encryption for data in transit (TLS 1.3)
    • Encryption at rest for server-stored data
    • Secure token-based authentication
    • Regular security audits

    ## 6. Your Rights

    You have the right to:
    • Access your data (available through the App's export feature)
    • Correct inaccurate data
    • Delete your data and account
    • Opt out of analytics collection
    • Restrict AI feature usage

    ## 7. Children's Privacy

    The App is not intended for children under 13. We do not knowingly collect information from children under 13. If you believe a child has provided us with personal information, please contact us.

    ## 8. Third-Party Links

    The App may contain links to third-party services. We are not responsible for the privacy practices of these services.

    ## 9. Changes to This Policy

    We may update this Privacy Policy from time to time. We will notify you of significant changes through the App. Continued use after changes constitutes acceptance.

    ## 10. Contact

    For privacy-related questions or requests, contact us at privacy@prototypeme.app.
    """
}
