import Foundation

/// Field length limits. Mirrored on the backend in packages/api/src/validation/limits.ts —
/// keep these two files in sync when changing a value.
enum FieldLimits {

    enum Directive {
        static let title = 120
        static let body = 1_000
    }

    enum Note {
        static let title = 120
        static let body = 10_000
    }

    enum Folder {
        static let name = 60
    }

    enum Journal {
        static let diary = 10_000
        static let tag = 40
        static let tagCount = 20
    }

    enum Schedule {
        /// Comma-separated day numbers like "1, 15, 20"
        static let monthlyDays = 80
    }

    enum AI {
        /// Generic user prompt to any AI feature (wizard, signup goals, panel query)
        static let prompt = 1_000
        /// Per-message limit for Speak tab (typed or voice-transcribed).
        /// Generous upper bound — ~3 minutes of continuous speech.
        static let speakMessage = 3_000
    }
}
