import SwiftUI
import RichTextKit

/// Keyboard toolbar that waits one run-loop after appearance before building the toolbar,
/// ensuring the underlying UIKit views are already in a window. This avoids
/// `UITargetedPreview` assertions that occur when the toolbar is instantiated too early
/// in SwiftUI previews or complex hierarchies.
struct LazyKeyboardToolbar: View {
    @ObservedObject var context: RichTextContext
    @State private var ready = false

    var body: some View {
        Group {
            if ready {
                RichTextKeyboardToolbar(
                    context: context,
                    leadingButtons: { $0 },
                    trailingButtons: { $0 },
                    formatSheet: { $0 }
                )
            }
        }
        .onAppear {
            // Defer creation until next run-loop so the SwiftUI hierarchy
            // has already been attached to a UIWindow.
            DispatchQueue.main.async { ready = true }
        }
    }
}
