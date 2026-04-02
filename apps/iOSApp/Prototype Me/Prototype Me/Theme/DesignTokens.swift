import UIKit

enum DesignTokens {

    // MARK: - Colors (Dark theme with lighter accents)

    enum Colors {
        // Backgrounds
        static let background = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        static let surfacePrimary = UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1.0)
        static let surfaceSecondary = UIColor(red: 0.15, green: 0.15, blue: 0.19, alpha: 1.0)
        static let surfaceTertiary = UIColor(red: 0.20, green: 0.20, blue: 0.24, alpha: 1.0)

        // Accent colors
        static let accent = UIColor(red: 0.40, green: 0.60, blue: 1.0, alpha: 1.0)
        static let accentSecondary = UIColor(red: 0.55, green: 0.85, blue: 0.70, alpha: 1.0)
        static let accentTertiary = UIColor(red: 0.95, green: 0.65, blue: 0.40, alpha: 1.0)

        // Text
        static let textPrimary = UIColor(white: 0.95, alpha: 1.0)
        static let textSecondary = UIColor(white: 0.60, alpha: 1.0)
        static let textTertiary = UIColor(white: 0.40, alpha: 1.0)

        // Semantic
        static let destructive = UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        static let success = UIColor(red: 0.30, green: 0.85, blue: 0.55, alpha: 1.0)
        static let warning = UIColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1.0)

        // Tab bar
        static let tabBarBackground = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 0.95)
        static let tabBarSelected = accent
        static let tabBarUnselected = UIColor(white: 0.45, alpha: 1.0)

        // Separator
        static let separator = UIColor(white: 0.20, alpha: 1.0)
    }

    // MARK: - Typography (Dynamic Type compatible)

    enum Typography {
        static let largeTitle = UIFont.preferredFont(forTextStyle: .largeTitle)
        static let title1 = UIFont.preferredFont(forTextStyle: .title1)
        static let title2 = UIFont.preferredFont(forTextStyle: .title2)
        static let title3 = UIFont.preferredFont(forTextStyle: .title3)
        static let headline = UIFont.preferredFont(forTextStyle: .headline)
        static let body = UIFont.preferredFont(forTextStyle: .body)
        static let callout = UIFont.preferredFont(forTextStyle: .callout)
        static let subheadline = UIFont.preferredFont(forTextStyle: .subheadline)
        static let footnote = UIFont.preferredFont(forTextStyle: .footnote)
        static let caption1 = UIFont.preferredFont(forTextStyle: .caption1)
        static let caption2 = UIFont.preferredFont(forTextStyle: .caption2)

        /// Rounded, weighted font that scales with Dynamic Type.
        static func rounded(style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
                .addingAttributes([
                    .traits: [UIFontDescriptor.TraitKey.weight: weight]
                ])
            let roundedDesc = desc.withDesign(.rounded) ?? desc
            return UIFont(descriptor: roundedDesc, size: 0)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radii

    enum Radii {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 9999
    }

    // MARK: - Shadows

    enum Shadows {
        static func apply(to layer: CALayer, elevation: Elevation = .low) {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = elevation.offset
            layer.shadowRadius = elevation.radius
            layer.shadowOpacity = elevation.opacity
        }

        enum Elevation {
            case low, medium, high

            var offset: CGSize {
                switch self {
                case .low: return CGSize(width: 0, height: 1)
                case .medium: return CGSize(width: 0, height: 4)
                case .high: return CGSize(width: 0, height: 8)
                }
            }
            var radius: CGFloat {
                switch self {
                case .low: return 3
                case .medium: return 8
                case .high: return 16
                }
            }
            var opacity: Float {
                switch self {
                case .low: return 0.3
                case .medium: return 0.4
                case .high: return 0.5
                }
            }
        }
    }

    // MARK: - Rating Color

    /// Smooth gradient color for journal rating 1–10 (red → yellow → green).
    static func ratingColor(for rating: Int) -> UIColor {
        let t = CGFloat(max(1, min(rating, 10)) - 1) / 9.0
        if t < 0.5 {
            let p = t / 0.5
            return UIColor(red: 1.0, green: 0.3 + 0.5 * p, blue: 0.2 * (1 - p), alpha: 1)
        } else {
            let p = (t - 0.5) / 0.5
            return UIColor(red: 1.0 - 0.6 * p, green: 0.8 + 0.2 * p, blue: 0.15 * p, alpha: 1)
        }
    }
}
