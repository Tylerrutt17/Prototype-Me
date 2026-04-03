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

    Last updated: April 2026

    Welcome to Prototype Me. By using our app, you agree to these Terms of Service. Please read them carefully.

    ## 1. Acceptance of Terms

    By accessing, downloading, installing, or using Prototype Me ("the App"), you acknowledge that you have read, understood, and agree to be bound by these Terms of Service ("Terms") and our Privacy Policy. If you do not agree to all of these Terms, do not access or use the App. Your continued use of the App following the posting of any changes to these Terms constitutes acceptance of those changes.

    ## 2. Description of Service

    Prototype Me is a personal development and self-optimization platform that helps you build habits, track directives, journal daily, set goals, and receive AI-powered analysis, suggestions, and recommendations. The App stores data locally on your device and syncs with our cloud servers when you are signed in. Features, functionality, and availability may change at any time without prior notice.

    ## 3. Eligibility

    You must be at least 13 years of age to use the App. By using the App, you represent and warrant that you meet this requirement. If you are under 18, you represent that your parent or legal guardian has reviewed and agreed to these Terms on your behalf.

    ## 4. User Accounts

    An Apple ID is required to use the App. You are responsible for maintaining the confidentiality and security of your account credentials and for all activities that occur under your account. You agree to notify us immediately of any unauthorized use of your account. We are not liable for any loss or damage arising from your failure to protect your account.

    ## 5. User Content & License Grant

    You retain ownership of all content you create within the App ("User Content"), including notes, directives, journal entries, tags, schedules, and any other data you input. By using the App, you grant TapTwice LLC a worldwide, non-exclusive, royalty-free, sublicensable, and transferable license to use, process, store, reproduce, modify, adapt, and display your User Content solely for the purposes of:
    • Operating, maintaining, and improving the App and its features
    • Providing AI-powered analysis, suggestions, recommendations, and insights
    • Training and improving our AI models and algorithms using anonymized and aggregated data
    • Generating analytics and insights for you and for improving our services
    • Syncing your data across your devices

    This license persists for as long as your User Content is stored on our servers and for a reasonable period thereafter to complete any processing in progress.

    ## 6. AI-Powered Features

    The App includes AI-powered features including but not limited to: personalized suggestions, behavioral analysis, pattern recognition, check-in analysis, mood tracking insights, directive recommendations, and automated coaching ("AI Features"). By using the App, you acknowledge and agree that:

    a) AI Features process your User Content, including personal reflections, journal entries, ratings, behavioral patterns, and any other data you provide, using third-party AI services and our own algorithms.

    b) AI-generated outputs are provided for informational and entertainment purposes only. They do not constitute professional advice of any kind, including but not limited to medical, psychological, psychiatric, therapeutic, legal, financial, or fitness advice.

    c) You are solely responsible for any decisions, actions, or lifestyle changes you make based on AI-generated suggestions. TapTwice LLC expressly disclaims all liability for any outcomes, consequences, or damages resulting from your reliance on AI outputs.

    d) AI outputs may be inaccurate, incomplete, biased, or inappropriate. We make no representations or warranties regarding the accuracy, reliability, completeness, or suitability of any AI-generated content.

    e) We may use third-party AI service providers (including but not limited to Anthropic, OpenAI, and others) to process your data and generate outputs. These providers have their own terms and privacy policies. We are not responsible for the practices or outputs of these third-party providers.

    f) We reserve the right to modify, limit, or discontinue AI Features at any time, with or without notice, for any reason including but not limited to changes in third-party API availability, cost considerations, or regulatory requirements.

    g) You agree not to use AI Features to generate content that is harmful, illegal, threatening, abusive, defamatory, or otherwise objectionable.

    ## 7. Acceptable Use

    You agree not to:
    • Use the App for any illegal, harmful, or fraudulent purpose
    • Attempt to reverse-engineer, decompile, disassemble, or derive source code from the App
    • Interfere with or disrupt the App's servers, networks, or infrastructure
    • Upload malicious content, viruses, or attempt to gain unauthorized access to any systems
    • Use the App to harass, abuse, stalk, threaten, or harm others
    • Use automated systems, bots, or scripts to access the App
    • Circumvent any access controls, rate limits, or security measures
    • Resell, redistribute, or commercially exploit any part of the App or its outputs
    • Use the App in any manner that could damage, disable, or impair our services
    • Misrepresent your identity or impersonate any person or entity

    ## 8. Subscription, Payments & Pricing

    Some features require a paid subscription ("Pro"). Subscriptions are billed through the Apple App Store and are subject to Apple's terms and conditions. You can manage or cancel your subscription in your device's Settings at any time. Refunds are subject to Apple's refund policies. We reserve the right to change subscription pricing at any time. Price changes will not affect your current billing period but will apply upon renewal. Free features may be moved to paid tiers at our discretion.

    ## 9. Intellectual Property

    The App, its design, code, features, branding, documentation, and all related intellectual property are owned by TapTwice LLC and are protected by copyright, trademark, and other intellectual property laws. You may not copy, modify, distribute, sell, or lease any part of the App. All rights not expressly granted in these Terms are reserved.

    ## 10. Data & Privacy

    Your data is handled as described in our Privacy Policy, which is incorporated into these Terms by reference. By using the App, you consent to the collection, use, processing, and sharing of your data as described in the Privacy Policy.

    ## 11. Disclaimer of Warranties

    THE APP AND ALL CONTENT, FEATURES, AND SERVICES ARE PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, SECURE, OR FREE OF VIRUSES OR OTHER HARMFUL COMPONENTS. WE DO NOT WARRANT THE ACCURACY OR COMPLETENESS OF ANY INFORMATION, AI-GENERATED CONTENT, OR SUGGESTIONS PROVIDED THROUGH THE APP. YOUR USE OF THE APP IS AT YOUR SOLE RISK.

    ## 12. Limitation of Liability

    TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL TAPTTWICE DIGITAL, ITS OFFICERS, DIRECTORS, EMPLOYEES, AGENTS, AFFILIATES, SUCCESSORS, OR ASSIGNS BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO DAMAGES FOR LOSS OF PROFITS, GOODWILL, USE, DATA, OR OTHER INTANGIBLE LOSSES, ARISING OUT OF OR IN CONNECTION WITH YOUR USE OF OR INABILITY TO USE THE APP, REGARDLESS OF THE THEORY OF LIABILITY (CONTRACT, TORT, STRICT LIABILITY, OR OTHERWISE), EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. OUR TOTAL AGGREGATE LIABILITY FOR ALL CLAIMS ARISING OUT OF OR RELATING TO THESE TERMS OR THE APP SHALL NOT EXCEED THE AMOUNT YOU PAID US IN THE TWELVE (12) MONTHS PRECEDING THE CLAIM, OR FIFTY DOLLARS ($50), WHICHEVER IS GREATER.

    ## 13. Indemnification

    You agree to indemnify, defend, and hold harmless TapTwice LLC, its officers, directors, employees, agents, and affiliates from and against any and all claims, damages, obligations, losses, liabilities, costs, and expenses (including reasonable attorneys' fees) arising from: (a) your use of the App; (b) your violation of these Terms; (c) your violation of any third-party rights; (d) your User Content; or (e) any actions you take based on AI-generated suggestions or outputs.

    ## 14. Dispute Resolution

    Any dispute arising out of or relating to these Terms or the App shall first be attempted to be resolved through good-faith negotiation. If the dispute cannot be resolved within 30 days, it shall be resolved by binding arbitration in accordance with the rules of the American Arbitration Association, conducted in the English language. The arbitration shall take place in the United States. You agree that any dispute resolution proceedings will be conducted on an individual basis and not as part of any class, consolidated, or representative action. The arbitrator's decision shall be final and binding.

    ## 15. Governing Law

    These Terms shall be governed by and construed in accordance with the laws of the United States and the State of Delaware, without regard to conflict of law principles.

    ## 16. Modifications to Terms

    We reserve the right to modify these Terms at any time. We will notify you of material changes through the App or via email. Your continued use of the App after such modifications constitutes your acceptance of the updated Terms. If you do not agree to the modified Terms, you must stop using the App.

    ## 17. Termination

    We reserve the right to suspend or terminate your access to the App at any time, with or without cause, with or without notice. Upon termination, your right to use the App ceases immediately. Sections that by their nature should survive termination (including but not limited to Sections 5, 6, 11, 12, 13, 14, and 15) shall survive.

    ## 18. Severability

    If any provision of these Terms is found to be unenforceable or invalid, that provision shall be limited or eliminated to the minimum extent necessary so that these Terms shall otherwise remain in full force and effect.

    ## 19. Entire Agreement

    These Terms, together with the Privacy Policy, constitute the entire agreement between you and TapTwice LLC regarding the App and supersede all prior agreements and understandings.

    ## 20. Contact

    If you have questions about these Terms, contact us at support@prototypeme.app.
    """

    private static let privacyPolicy = """
    ## Privacy Policy

    Last updated: April 2026

    TapTwice LLC ("we", "our", "us") operates Prototype Me ("the App"). This Privacy Policy explains how we collect, use, store, share, and protect your information. By using the App, you consent to the practices described in this policy.

    ## 1. Information We Collect

    We collect the following categories of information:

    Account Information: When you sign in with Apple, we receive and store your Apple user identifier, email address (if provided), and display name. We also generate and store authentication tokens for your sessions.

    User Content: All content you create within the App, including but not limited to: notes, directives, journal entries, daily ratings, tags, schedules, modes, goals, check-in responses, and any other data you input or generate through your use of the App.

    Device Information: Device type, operating system version, app version, unique device identifiers, and timezone.

    Usage Data: How you interact with the App, including features used, frequency of use, session duration, tap patterns, navigation paths, and performance metrics.

    AI Interaction Data: When you use AI-powered features, we collect and process your prompts, the context provided to AI models (which may include your User Content such as directive titles, journal entries, ratings, behavioral patterns, check-in responses, and historical data), and the AI-generated outputs.

    Sync Data: When signed in, all User Content is transmitted to and stored on our cloud servers to enable cross-device synchronization.

    Crash & Diagnostic Data: Crash logs, error reports, and diagnostic information to help us identify and fix technical issues.

    ## 2. How We Use Your Information

    We use your information for the following purposes:

    • To provide, operate, and maintain the App and all its features
    • To sync your data across your devices
    • To process your data through AI models and generate personalized suggestions, analysis, recommendations, insights, and coaching
    • To train, improve, and develop our AI models, algorithms, and features using anonymized and aggregated data derived from your usage
    • To analyze usage patterns and trends to improve the App's functionality and user experience
    • To send you notifications, reminders, and updates you have opted into
    • To diagnose technical issues, monitor performance, and prevent abuse or fraud
    • To comply with legal obligations and enforce our Terms of Service
    • To develop new features, products, and services
    • To conduct research and analytics using anonymized and aggregated data

    ## 3. AI Data Processing

    Our AI features are central to the App's functionality. By using the App, you acknowledge and consent to the following AI data processing:

    a) Your User Content — including personal reflections, journal entries, ratings, behavioral data, check-in responses, and usage patterns — is processed by AI models to generate personalized outputs.

    b) We use third-party AI service providers, including but not limited to Anthropic (Claude), OpenAI, and others, to process your data. When using these services, relevant portions of your User Content are transmitted to these providers' servers for processing.

    c) Third-party AI providers have their own terms of service and privacy policies. While we contractually require these providers to protect your data, we cannot guarantee their compliance and are not responsible for their data handling practices.

    d) We may use anonymized and aggregated data derived from your interactions with AI features to train, improve, and develop our own AI models and algorithms. Individual User Content is not used for third-party model training without explicit consent.

    e) AI-processed data may be cached temporarily on our servers to improve response times and reduce costs. Cached data is automatically purged periodically.

    ## 4. Data Sharing

    We do not sell your personal information. We may share your data with the following categories of recipients:

    AI Service Providers: Third-party AI companies that process your data to generate suggestions and insights. These include Anthropic, OpenAI, and any future providers we may engage.

    Cloud Infrastructure Providers: Our servers and databases run on third-party cloud platforms. Your data is encrypted at rest and in transit on these platforms.

    Analytics Providers: We may use third-party analytics services to collect and analyze anonymized usage data.

    Legal & Safety: We may disclose your information if required to do so by law, regulation, legal process, or governmental request, or if we believe disclosure is necessary to protect our rights, property, or safety, or the rights, property, or safety of others.

    Business Transfers: In the event of a merger, acquisition, bankruptcy, reorganization, or sale of assets, your information may be transferred as part of that transaction. We will notify you of any such change.

    With Your Consent: We may share your information with other third parties when you give us explicit consent to do so.

    ## 5. Data Retention

    Local Data: Data stored locally on your device remains until you delete the App or clear its data.

    Server Data: Your synced data is retained on our servers for as long as you maintain an active account. If you delete your account, all personally identifiable server-side data is scheduled for permanent deletion within 30 days. Anonymized and aggregated data derived from your usage may be retained indefinitely for research and improvement purposes.

    AI Interaction Logs: AI processing logs are retained for up to 90 days for debugging and quality improvement, then automatically purged.

    Backups: Server backups containing your data may persist for up to 90 days after deletion of your account.

    ## 6. Security

    We implement commercially reasonable security measures to protect your information, including:
    • Encryption in transit using TLS 1.3 for all data transmissions
    • Encryption at rest for all server-stored data
    • Secure token-based authentication with automatic token rotation
    • Access controls limiting employee access to user data
    • Regular security assessments and monitoring

    However, no method of electronic transmission or storage is 100% secure. We cannot guarantee absolute security of your data. You acknowledge and accept this inherent risk.

    ## 7. Your Rights & Choices

    Depending on your jurisdiction, you may have the following rights:
    • Access: Request a copy of the personal data we hold about you
    • Correction: Request correction of inaccurate personal data
    • Deletion: Request deletion of your account and associated data
    • Portability: Request your data in a structured, machine-readable format
    • Opt-Out of Analytics: Disable analytics collection in the App's settings
    • Restrict AI Processing: You may stop using AI features at any time, though this may limit the App's functionality

    To exercise these rights, contact us at privacy@prototypeme.app. We will respond within 30 days.

    ## 8. International Data Transfers

    Your data may be transferred to and processed in countries other than your country of residence, including the United States. These countries may have different data protection laws. By using the App, you consent to the transfer of your data to these countries.

    ## 9. Children's Privacy

    The App is not intended for children under 13. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information promptly.

    ## 10. California Privacy Rights (CCPA)

    If you are a California resident, you have additional rights under the California Consumer Privacy Act, including the right to know what personal information we collect, the right to delete your personal information, and the right to opt out of the sale of your personal information. We do not sell personal information.

    ## 11. European Privacy Rights (GDPR)

    If you are located in the European Economic Area, you have additional rights under the General Data Protection Regulation, including the right to access, rectify, erase, restrict processing, data portability, and object to processing. Our legal basis for processing your data is your consent (provided when you agree to these terms) and our legitimate interests in operating and improving the App.

    ## 12. Third-Party Services & Links

    The App may integrate with or contain links to third-party services, websites, or platforms. We are not responsible for the privacy practices, content, or data handling of any third-party services. We encourage you to review the privacy policies of any third-party services you interact with.

    ## 13. Changes to This Policy

    We reserve the right to modify this Privacy Policy at any time. We will notify you of material changes through the App or via the email address associated with your account. Your continued use of the App after such modifications constitutes your acceptance of the updated Privacy Policy.

    ## 14. Contact

    For privacy-related questions, data requests, or concerns, contact us at privacy@prototypeme.app.
    """
}
