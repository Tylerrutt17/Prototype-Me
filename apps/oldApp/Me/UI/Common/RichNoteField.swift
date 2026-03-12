import SwiftUI
import SwiftData
import Observation
import Combine
import UIKit
import RichEditorSwiftUI

/// Drop-in rich-text editor that persists markdown/plain text on change/disappear.
struct RichNoteField<Model>: View where Model: RichTextPersistable & Observable {
    @Bindable var model: Model
    @ObservedObject var editorState: RichEditorState
    @Environment(\.modelContext) private var modelContext
    @State private var pending: DispatchWorkItem?
    private let editorTheme = RichTextView.Theme(
        font: .systemFont(ofSize: 16),
        fontColor: .textColor,
        backgroundColor: ColorRepresentable(Color(.secondarySystemBackground))
    )

    init(model: Model, state: RichEditorState? = nil) {
        _model = Bindable(wrappedValue: model)
        let seeded = state ?? model.makeEditorState()
        _editorState = ObservedObject(wrappedValue: seeded)
        RichTextView.Theme.standard = editorTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RichTextEditor(context: _editorState)
                .frame(minHeight: 200, alignment: .top)
                .richTextEditorStyle(editorTheme)
                .background(Color(.secondarySystemBackground))
                .onReceive(editorState.objectWillChange) { _ in scheduleSave() }
                .onDisappear { flushSave() }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    flushSave()
                }
        }
    }

    // MARK: − Saving helpers
    private func scheduleSave() {
        pending?.cancel()
        let task = DispatchWorkItem { persist() }
        pending = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func flushSave() {
        if let p = pending, !p.isCancelled { p.perform() }
        else { persist() }
    }

    private func persist() {
        // Prefer HTML from attributed string; fallback to best-effort string.
        model.persistRichText(from: editorState)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ SwiftData error:", error)
            #endif
        }
    }
}
