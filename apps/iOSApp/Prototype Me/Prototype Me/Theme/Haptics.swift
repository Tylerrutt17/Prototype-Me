import UIKit

enum Haptics {

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// User preference — persisted in UserDefaults
    static var isEnabled: Bool {
        get { !UserDefaults.standard.bool(forKey: "hapticsDisabled") }
        set { UserDefaults.standard.set(!newValue, forKey: "hapticsDisabled") }
    }

    private static var canFire: Bool {
        isEnabled && !UIAccessibility.isReduceMotionEnabled
    }

    static func light() {
        guard canFire else { return }
        lightImpact.impactOccurred()
    }

    static func medium() {
        guard canFire else { return }
        mediumImpact.impactOccurred()
    }

    static func heavy() {
        guard canFire else { return }
        heavyImpact.impactOccurred()
    }

    static func selection() {
        guard canFire else { return }
        selectionGenerator.selectionChanged()
    }

    static func success() {
        guard canFire else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    static func warning() {
        guard canFire else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    static func error() {
        guard canFire else { return }
        notificationGenerator.notificationOccurred(.error)
    }
}
