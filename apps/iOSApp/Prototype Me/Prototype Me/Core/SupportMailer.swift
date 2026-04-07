import UIKit
import MessageUI

/// Shared utility for presenting a pre-filled support email.
/// Used by both the Settings "Contact Support" row and the database recovery screen.
enum SupportMailer {

    static let supportEmail = "tyler@taptwicedigital.com"

    // MARK: - Mail App Definitions

    private struct MailApp {
        let name: String
        let icon: String          // SF Symbol
        let urlScheme: String     // used to check if installed
        let composeURL: (_ to: String, _ subject: String, _ body: String) -> URL?
    }

    private static let mailApps: [MailApp] = [
        MailApp(
            name: "Apple Mail",
            icon: "envelope.fill",
            urlScheme: "mailto:",
            composeURL: { to, subject, body in
                var c = URLComponents()
                c.scheme = "mailto"
                c.path = to
                c.queryItems = [
                    URLQueryItem(name: "subject", value: subject),
                    URLQueryItem(name: "body", value: body),
                ]
                return c.url
            }
        ),
        MailApp(
            name: "Gmail",
            icon: "envelope.badge.fill",
            urlScheme: "googlegmail://",
            composeURL: { to, subject, body in
                var c = URLComponents(string: "googlegmail:///co")!
                c.queryItems = [
                    URLQueryItem(name: "to", value: to),
                    URLQueryItem(name: "subject", value: subject),
                    URLQueryItem(name: "body", value: body),
                ]
                return c.url
            }
        ),
        MailApp(
            name: "Outlook",
            icon: "envelope.open.fill",
            urlScheme: "ms-outlook://",
            composeURL: { to, subject, body in
                var c = URLComponents(string: "ms-outlook://compose")!
                c.queryItems = [
                    URLQueryItem(name: "to", value: to),
                    URLQueryItem(name: "subject", value: subject),
                    URLQueryItem(name: "body", value: body),
                ]
                return c.url
            }
        ),
        MailApp(
            name: "Yahoo Mail",
            icon: "envelope.arrow.triangle.branch.fill",
            urlScheme: "ymail://",
            composeURL: { to, subject, body in
                var c = URLComponents(string: "ymail://mail/compose")!
                c.queryItems = [
                    URLQueryItem(name: "to", value: to),
                    URLQueryItem(name: "subject", value: subject),
                    URLQueryItem(name: "body", value: body),
                ]
                return c.url
            }
        ),
    ]

    // MARK: - Public API

    /// Shows an action sheet letting the user pick their mail app, then opens
    /// the compose screen with the email pre-filled.
    static func present(
        from viewController: UIViewController,
        subject: String = "Prototype Me — Support",
        body: String = ""
    ) {
        let available = mailApps.filter { app in
            guard let url = URL(string: app.urlScheme) else { return false }
            return UIApplication.shared.canOpenURL(url)
        }

        // If only one app available (or none), skip the picker
        if available.count <= 1 {
            openMailApp(available.first ?? mailApps[0], subject: subject, body: body, from: viewController)
            return
        }

        let sheet = UIAlertController(title: "Open with", message: nil, preferredStyle: .actionSheet)

        for app in available {
            let action = UIAlertAction(title: app.name, style: .default) { _ in
                openMailApp(app, subject: subject, body: body, from: viewController)
            }
            action.setValue(UIImage(systemName: app.icon), forKey: "image")
            sheet.addAction(action)
        }

        sheet.addAction(UIAlertAction(title: "Copy Email Address", style: .default) { _ in
            UIPasteboard.general.string = supportEmail
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad popover anchor
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(sheet, animated: true)
    }

    /// Convenience for error reports (pre-fills device + app info).
    static func presentErrorReport(
        from viewController: UIViewController,
        error: Error
    ) {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let systemVersion = "\(device.systemName) \(device.systemVersion)"
        let deviceModel = device.model

        let body = """
        --- Please describe what happened ---


        --- Error Details (do not edit below) ---
        Error: \(error.localizedDescription)
        Detail: \(error)
        App: \(appVersion) (\(buildNumber))
        OS: \(systemVersion)
        Device: \(deviceModel)
        Storage: \(StorageMonitor.availableMB) MB free
        """

        present(
            from: viewController,
            subject: "Prototype Me — Error Report (v\(appVersion))",
            body: body
        )
    }

    // MARK: - Private

    private static func openMailApp(
        _ app: MailApp,
        subject: String,
        body: String,
        from viewController: UIViewController
    ) {
        // For Apple Mail, prefer the native in-app composer if available
        if app.urlScheme == "mailto:" && MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = MailDismisser.shared
            mail.setToRecipients([supportEmail])
            mail.setSubject(subject)
            mail.setMessageBody(body, isHTML: false)
            viewController.present(mail, animated: true)
            return
        }

        if let url = app.composeURL(supportEmail, subject, body) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Mail Dismiss Handler

private final class MailDismisser: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = MailDismisser()

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true)
    }
}
