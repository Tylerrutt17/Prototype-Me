import UIKit

enum Haptics {

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func light() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        lightImpact.impactOccurred()
    }

    static func medium() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        mediumImpact.impactOccurred()
    }

    static func heavy() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        heavyImpact.impactOccurred()
    }

    static func selection() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    static func success() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    static func warning() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    static func error() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }
}
