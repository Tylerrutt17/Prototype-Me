import UIKit
import GRDB

/// Editor for creating/editing folders. Replaces the old PlaybookEditor.
final class PlaybookEditorViewController: BaseViewController {

    // MARK: - Public

    var folderId: UUID?                      // nil = create, non-nil = edit
    var parentFolderId: UUID?                // parent folder for new folders
    var folderService: FolderService?
    var onSave: (() -> Void)?

    // MARK: - Form Controls

    private let nameField: FormTextField = {
        let f = FormTextField(title: "NAME", placeholder: "Folder name")
        f.maxLength = FieldLimits.Folder.name
        return f
    }()

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle(folderId == nil ? "New Folder" : "Edit Folder", animated: false)
        navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in self?.cancelTapped() })
        navBar.setRightButtons([NavBarButton(title: "Save", prominent: true, action: { [weak self] in self?.saveTapped() })])

        buildForm()
        if folderId != nil { loadExistingFolder() }
        observeKeyboard()
    }

    // MARK: - Build Form

    private func buildForm() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = DesignTokens.Spacing.xl
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(nameField)

        let padding = DesignTokens.Spacing.lg

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -padding),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -padding * 2),
        ])
    }

    // MARK: - Data Loading

    private func loadExistingFolder() {
        guard let folderId else { return }
        do {
            let folder = try dbQueue.read { db in
                try Folder.fetchOne(db, key: folderId)
            }
            guard let folder else { return }
            nameField.textField.text = folder.name
        } catch {}
    }

    // MARK: - Actions

    private func saveTapped() {
        let name = (nameField.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            Haptics.warning()
            nameField.textField.layer.borderColor = DesignTokens.Colors.destructive.cgColor
            nameField.textField.layer.borderWidth = 1
            return
        }

        Task {
            do {
                if let folderId, var existing = try await folderService?.fetch(id: folderId) {
                    existing.name = name
                    try await folderService?.update(existing)
                } else {
                    _ = try await folderService?.create(name: name, parentFolderId: parentFolderId)
                }
                Haptics.success()
                onSave?()
            } catch {
                Haptics.error()
            }
        }
    }

    private func cancelTapped() {
        dismiss(animated: true)
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        scrollView.contentInset.bottom = frame.height
        scrollView.verticalScrollIndicatorInsets.bottom = frame.height
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}
