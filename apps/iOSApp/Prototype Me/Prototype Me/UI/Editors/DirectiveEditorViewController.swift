import UIKit
import GRDB

final class DirectiveEditorViewController: BaseViewController {

    // MARK: - Public

    var directiveId: UUID?                   // nil = create, non-nil = edit
    var directiveService: DirectiveService?
    var balloonNotificationService: BalloonNotificationService?
    var onSave: (() -> Void)?

    // MARK: - Form Controls

    private let titleField = FormTextField(title: "TITLE", placeholder: "Directive title")
    private let bodyField = FormTextView(title: "DESCRIPTION (OPTIONAL)", minHeight: 80)
    private let statusPicker = DirectiveStatusPicker()
    private let scheduleSection = ScheduleEditorSection()
    private let balloonSection = BalloonEditorSection()

    // MARK: - State

    private var selectedStatus: DirectiveStatus = .active
    private var balloonEnabled = false
    private var durationHours: Double = 24

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle(directiveId == nil ? "New Directive" : "Edit Directive", animated: false)
        navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in self?.cancelTapped() })
        navBar.setRightButtons([NavBarButton(title: "Save", action: { [weak self] in self?.saveTapped() })])

        buildForm()
        bindControls()
        if directiveId != nil { loadExistingDirective() }
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


        stackView.addArrangedSubview(titleField)
        stackView.addArrangedSubview(bodyField)
        stackView.addArrangedSubview(statusPicker)
        stackView.addArrangedSubview(balloonSection)
        stackView.addArrangedSubview(scheduleSection)

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

    // MARK: - Bindings

    private func bindControls() {
        statusPicker.onStatusChanged = { [weak self] status in
            self?.selectedStatus = status
        }
        balloonSection.onToggleChanged = { [weak self] isOn in
            self?.balloonEnabled = isOn
            if isOn {
                self?.balloonNotificationService?.requestPermissionIfNeeded()
            }
        }
        balloonSection.onDurationChanged = { [weak self] hours in
            self?.durationHours = hours
        }
    }

    private func showInfo(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Data Loading

    private func loadExistingDirective() {
        guard let directiveId else { return }
        do {
            let directive = try dbQueue.read { db in
                try Directive.fetchOne(db, key: directiveId)
            }
            guard let directive else { return }
            titleField.textField.text = directive.title
            bodyField.textView.text = directive.body
            selectedStatus = directive.status
            balloonEnabled = directive.balloonEnabled

            statusPicker.setStatus(directive.status)
            durationHours = directive.balloonDurationSec / 3600
            balloonSection.configure(isEnabled: directive.balloonEnabled, durationHours: durationHours)

            // Load existing schedule rule
            existingScheduleRule = try dbQueue.read { db in
                try ScheduleRule
                    .filter(Column("directiveId") == directiveId)
                    .fetchOne(db)
            }
            if let rule = existingScheduleRule {
                scheduleSection.loadFromRule(rule)
            }
        } catch {}
    }

    // MARK: - Actions

    private func saveTapped() {
        let title = (titleField.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            Haptics.warning()
            titleField.textField.layer.borderColor = DesignTokens.Colors.destructive.cgColor
            titleField.textField.layer.borderWidth = 1
            return
        }

        let body = bodyField.textView.text
        let durationSec = durationHours * 3600

        Task {
            do {
                if let directiveId, var existing = try await directiveService?.fetch(id: directiveId) {
                    existing.title = title
                    existing.body = body
                    existing.status = selectedStatus
                    existing.balloonEnabled = balloonEnabled
                    // Only reset remaining if duration changed or balloon just enabled
                    if existing.balloonDurationSec != durationSec || (!existing.balloonEnabled && balloonEnabled) {
                        existing.balloonSnapshotSec = durationSec
                    }
                    existing.balloonDurationSec = durationSec
                    try await directiveService?.update(existing)
                } else {
                    let newDir = try await directiveService?.create(
                        title: title, body: body,
                        balloonEnabled: balloonEnabled,
                        balloonDurationSec: durationSec
                    )
                    newDirectiveId = newDir?.id
                }
                // Save schedule rule
                let dirId = directiveId ?? newDirectiveId
                if let dirId {
                    try? self.saveScheduleRule(directiveId: dirId)

                    // Schedule or cancel balloon notification
                    if self.balloonEnabled {
                        if let saved = try? await self.directiveService?.fetch(id: dirId) {
                            self.balloonNotificationService?.scheduleBalloonNotification(for: saved)
                        }
                    } else {
                        self.balloonNotificationService?.cancelBalloonNotification(directiveId: dirId)
                    }
                }

                Haptics.success()
                onSave?()
            } catch {
                Haptics.error()
            }
        }
    }

    private var newDirectiveId: UUID?
    private var existingScheduleRule: ScheduleRule?

    private func saveScheduleRule(directiveId: UUID) throws {
        let params = scheduleSection.buildParams()

        // If no schedule types enabled, delete existing rule
        guard !params.isEmpty else {
            if let existing = existingScheduleRule {
                try dbQueue.write { db in
                    _ = try ScheduleRule.deleteOne(db, key: existing.id)
                }
            }
            return
        }

        let ruleType: ScheduleType = params["weekdays"] != nil ? .weekly : params["monthDays"] != nil ? .monthly : .oneOff

        try dbQueue.write { db in
            if var existing = self.existingScheduleRule {
                existing.ruleType = ruleType
                existing.params = params
                existing.version += 1
                existing.updatedAt = Date()
                try existing.update(db)
            } else {
                let now = Date()
                let rule = ScheduleRule(
                    id: UUID(), directiveId: directiveId,
                    ruleType: ruleType, params: params,
                    version: 1, createdAt: now, updatedAt: now
                )
                try rule.insert(db)
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
