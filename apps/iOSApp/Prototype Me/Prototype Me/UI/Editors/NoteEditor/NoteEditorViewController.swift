import UIKit
import GRDB

final class NoteEditorViewController: BaseViewController {

    // MARK: - Public

    var noteId: UUID?                        // nil = create, non-nil = edit
    var preselectedFolderId: UUID?           // when creating inside a folder
    var preselectedKind: NoteKind?           // when creating from a specific context (e.g. mode picker)
    var noteService: NoteService?
    var onSave: (() -> Void)?
    var onCreated: ((UUID, NoteKind) -> Void)?
    // Pre-fill from AI suggestion
    var prefillTitle: String?
    var prefillBody: String?
    /// Called when user picks Framework but one already exists — coordinator should open it for edit instead.
    var onEditExistingFramework: ((UUID) -> Void)?

    // MARK: - State (internal for extension access)

    var selectedKind: NoteKind = .regular
    var selectedFolderId: UUID?
    var enteredTitle = ""
    var enteredBody = ""

    var isCreateMode: Bool { noteId == nil }
    /// When editing an existing framework note, the type can't be changed (there can only be one framework per account).
    var isFrameworkEdit: Bool { !isCreateMode && selectedKind == .framework }
    var currentStep = 0
    let stepLabels = ["Content", "Type"]
    var kindPageDebounce: Timer?
    var kindDS: UICollectionViewDiffableDataSource<Int, Int>?

    // MARK: - UI

    let stepIndicator = StepIndicatorView(count: 2)
    let stepContainer = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        selectedFolderId = preselectedFolderId
        if let preselectedKind { selectedKind = preselectedKind }

        navBar.setTitle(isCreateMode ? "New Note or Mode" : "Edit Note", animated: false)
        navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in self?.dismiss(animated: true) })

        setupLayout()
        if !isCreateMode { loadExistingNote() }

        // Apply AI prefills after loading (so they override for updates)
        if let title = prefillTitle { enteredTitle = title }
        if let body = prefillBody { enteredBody = body }

        if isFrameworkEdit { stepIndicator.isHidden = true }
        showStep(0, animated: false)
        observeKeyboard()
    }

    // MARK: - Layout

    private func setupLayout() {
        stepIndicator.translatesAutoresizingMaskIntoConstraints = false
        stepIndicator.onStepTapped = { [weak self] step in
            guard let self else { return }
            if step <= self.currentStep {
                self.view.endEditing(true)
                self.showStep(step, animated: true)
            }
        }
        view.addSubview(stepIndicator)

        stepContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stepContainer)

        NSLayoutConstraint.activate([
            stepIndicator.topAnchor.constraint(equalTo: contentTopAnchor, constant: DesignTokens.Spacing.sm),
            stepIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            stepIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            stepIndicator.heightAnchor.constraint(equalToConstant: 40),

            stepContainer.topAnchor.constraint(equalTo: stepIndicator.bottomAnchor),
            stepContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stepContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stepContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Step Navigation

    func showStep(_ step: Int, animated: Bool) {
        let direction: CGFloat = step >= currentStep ? 1 : -1
        currentStep = step
        stepIndicator.setActiveStep(step)

        if step > 0 {
            navBar.setLeftButton(title: "Back", systemImage: nil, action: { [weak self] in
                guard let self else { return }
                self.view.endEditing(true)
                self.showStep(self.currentStep - 1, animated: true)
            })
        } else {
            navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in
                self?.dismiss(animated: true)
            })
        }

        // Right nav button: Next on step 0, nothing on step 1 (has its own Save button).
        // Framework edit is single-step: Save directly from step 0.
        if step == 0 {
            let title = isFrameworkEdit ? "Save" : "Next"
            navBar.setRightButtons([NavBarButton(title: title, prominent: true, action: { [weak self] in self?.step1Next() })])
        } else {
            navBar.setRightButtons([])
        }

        let stepView: UIView
        switch step {
        case 0: stepView = buildTitleBodyStep()
        case 1: stepView = buildKindStep()
        default: return
        }

        let oldViews = stepContainer.subviews
        stepView.translatesAutoresizingMaskIntoConstraints = false
        stepContainer.addSubview(stepView)

        NSLayoutConstraint.activate([
            stepView.topAnchor.constraint(equalTo: stepContainer.topAnchor),
            stepView.leadingAnchor.constraint(equalTo: stepContainer.leadingAnchor),
            stepView.trailingAnchor.constraint(equalTo: stepContainer.trailingAnchor),
            stepView.bottomAnchor.constraint(equalTo: stepContainer.bottomAnchor),
        ])

        if animated {
            stepView.alpha = 0
            stepView.transform = CGAffineTransform(translationX: 40 * direction, y: 0)
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                stepView.alpha = 1
                stepView.transform = .identity
            }
            UIView.animate(withDuration: 0.15) {
                oldViews.forEach { $0.alpha = 0 }
            } completion: { _ in
                oldViews.forEach { $0.removeFromSuperview() }
            }
        } else {
            oldViews.forEach { $0.removeFromSuperview() }
        }
    }

    // MARK: - Actions

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc func titleFieldChanged(_ field: UITextField) {
        enteredTitle = field.text ?? ""
    }

    @objc func step1Next() {
        if let bodyView = stepContainer.viewWithTag(101) as? UITextView {
            enteredBody = bodyView.text ?? ""
        }
        guard !enteredTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Haptics.warning()
            return
        }
        view.endEditing(true)
        // Framework notes can't change type — save directly from step 0.
        if isFrameworkEdit {
            saveNote()
            return
        }
        showStep(1, animated: true)
    }

    // MARK: - Save

    func saveNote() {
        let title = enteredTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            Haptics.warning()
            return
        }

        Task {
            do {
                if let noteId, var existing = try await noteService?.fetch(id: noteId) {
                    existing.title = title
                    existing.body = enteredBody
                    existing.kind = selectedKind
                    existing.folderId = selectedFolderId
                    try await noteService?.update(existing)
                } else {
                    let newNote = try await noteService?.create(
                        title: title, body: enteredBody,
                        kind: selectedKind,
                        folderId: selectedFolderId
                    )
                    if let newNote {
                        onCreated?(newNote.id, newNote.kind)
                    }
                }
                Haptics.success()
                onSave?()
            } catch {
                Haptics.error()
            }
        }
    }

    // MARK: - Data Loading

    private func loadExistingNote() {
        guard let noteId else { return }
        guard let note = try? dbQueue.read({ db in try NotePage.fetchOne(db, key: noteId) }) else { return }
        enteredTitle = note.title
        enteredBody = note.body
        selectedKind = note.kind
        selectedFolderId = note.folderId
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    private func findScrollView() -> UIScrollView? {
        func find(in view: UIView) -> UIScrollView? {
            if let sv = view as? UIScrollView { return sv }
            for sub in view.subviews {
                if let found = find(in: sub) { return found }
            }
            return nil
        }
        return find(in: stepContainer)
    }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let scroll = findScrollView() else { return }
        let inset = frame.height - view.safeAreaInsets.bottom
        scroll.contentInset.bottom = inset
        scroll.verticalScrollIndicatorInsets.bottom = inset
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        guard let scroll = findScrollView() else { return }
        scroll.contentInset.bottom = 0
        scroll.verticalScrollIndicatorInsets.bottom = 0
    }
}

// MARK: - UITextViewDelegate

extension NoteEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView.tag == 101 {
            enteredBody = textView.text ?? ""
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // tag 101 = body field
        guard textView.tag == 101 else { return true }
        let current = textView.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: r, with: text).count <= FieldLimits.Note.body
    }
}

// MARK: - UITextFieldDelegate

extension NoteEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // tag 100 = title field
        guard textField.tag == 100 else { return true }
        let current = textField.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: r, with: string).count <= FieldLimits.Note.title
    }
}
