import UIKit
import GRDB

final class DirectiveEditorViewController: BaseViewController {

    // MARK: - Public

    var directiveId: UUID?                   // nil = create, non-nil = edit
    var directiveService: DirectiveService?
    var balloonNotificationService: BalloonNotificationService?
    var onSave: (() -> Void)?
    var onAskAISuggestion: ((String) -> Void)?  // problem text → route to Speak tab
    var prefillTitle: String?                    // pre-fill from AI suggestion
    var prefillBody: String?
    var shimmerSave = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shimmerSave { navBar.shimmerRightButton() }
    }

    // MARK: - Mode Toggle

    private let modeSegment = UISegmentedControl(items: ["Wizard", "Manual"])
    private let wizardContainer = UIView()
    private let manualContainer = UIView()

    // MARK: - Wizard Controls

    var apiClient: APIClient?
    private let problemField = UITextField()
    private let suggestButton = AppButton(title: "Suggest Directives")
    private let suggestionsStack = UIStackView()
    private let suggestionsScrollView = UIScrollView()
    private var currentSuggestions: [DirectiveWizard.Suggestion] = []

    // MARK: - Manual Form Controls

    private let titleField: FormTextField = {
        let f = FormTextField(title: "TITLE", placeholder: "Directive title")
        f.maxLength = FieldLimits.Directive.title
        return f
    }()
    private let bodyField: FormTextView = {
        let f = FormTextView(title: "DESCRIPTION (OPTIONAL)", minHeight: 80)
        f.maxLength = FieldLimits.Directive.body
        return f
    }()
    private let statusPicker = DirectiveStatusPicker()
    private let scheduleSection = ScheduleEditorSection()
    private let balloonSection = BalloonEditorSection()
    private let colorPicker = DirectiveColorPicker()

    // MARK: - State

    private var selectedStatus: DirectiveStatus = .active
    private var balloonEnabled = false
    private var durationHours: Double = 24
    private var selectedColor: String?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Ensure apiClient is set — fall back to a fresh default instance
        if apiClient == nil {
            apiClient = APIClient()
        }
        let isCreate = directiveId == nil
        navBar.setTitle(isCreate ? "New Directive" : "Edit Directive", animated: false)
        navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in self?.cancelTapped() })
        navBar.setRightButtons([NavBarButton(title: "Save", prominent: true, action: { [weak self] in self?.saveTapped() })])

        if isCreate {
            buildModeToggle()
            buildWizardView()
        }
        buildManualForm()
        bindControls()
        if directiveId != nil { loadExistingDirective() }
        observeKeyboard()

        // Show wizard by default for create, manual for edit.
        // If pre-filled from a suggestion, jump straight to manual mode.
        if isCreate && prefillTitle == nil {
            modeSegment.selectedSegmentIndex = 0
            showMode(0)
        } else {
            if isCreate {
                modeSegment.selectedSegmentIndex = 1
                showMode(1)
            }
            wizardContainer.isHidden = true
            manualContainer.isHidden = false
        }

        // Apply pre-fill from AI suggestion
        if let title = prefillTitle {
            titleField.textField.text = title
        }
        if let body = prefillBody {
            bodyField.textView.text = body
        }
    }

    // MARK: - Mode Toggle

    private func buildModeToggle() {
        modeSegment.selectedSegmentTintColor = DesignTokens.Colors.accent
        modeSegment.setTitleTextAttributes([
            .foregroundColor: DesignTokens.Colors.textPrimary,
            .font: DesignTokens.Typography.rounded(style: .footnote, weight: .semibold),
        ], for: .selected)
        modeSegment.setTitleTextAttributes([
            .foregroundColor: DesignTokens.Colors.textSecondary,
            .font: DesignTokens.Typography.rounded(style: .footnote, weight: .medium),
        ], for: .normal)
        modeSegment.backgroundColor = DesignTokens.Colors.surfaceSecondary
        modeSegment.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeSegment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeSegment)

        NSLayoutConstraint.activate([
            modeSegment.topAnchor.constraint(equalTo: contentTopAnchor, constant: DesignTokens.Spacing.sm),
            modeSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            modeSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            modeSegment.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    @objc private func modeChanged() {
        showMode(modeSegment.selectedSegmentIndex)
        view.endEditing(true)
    }

    private func showMode(_ index: Int) {
        let isWizard = index == 0
        wizardContainer.isHidden = !isWizard
        manualContainer.isHidden = isWizard

        // Hide save button in wizard mode (suggestions auto-create)
        if directiveId == nil {
            navBar.setRightButtons(isWizard ? [] : [NavBarButton(title: "Save", prominent: true, action: { [weak self] in self?.saveTapped() })])
        }
    }

    // MARK: - Wizard View

    private func buildWizardView() {
        wizardContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wizardContainer)

        let topAnchor = modeSegment.bottomAnchor

        NSLayoutConstraint.activate([
            wizardContainer.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.lg),
            wizardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wizardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wizardContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Problem input
        let promptLabel = UILabel()
        promptLabel.text = "What are you struggling with?"
        promptLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        promptLabel.textColor = DesignTokens.Colors.textPrimary
        promptLabel.numberOfLines = 0

        let promptSubtitle = UILabel()
        promptSubtitle.text = "Describe the issue and we'll suggest directives to help."
        promptSubtitle.font = DesignTokens.Typography.subheadline
        promptSubtitle.textColor = DesignTokens.Colors.textSecondary
        promptSubtitle.numberOfLines = 0

        problemField.placeholder = "e.g. I can't focus at work, I stay up too late..."
        problemField.font = DesignTokens.Typography.body
        problemField.textColor = DesignTokens.Colors.textPrimary
        problemField.tintColor = DesignTokens.Colors.accent
        problemField.backgroundColor = DesignTokens.Colors.surfacePrimary
        problemField.layer.cornerRadius = DesignTokens.Radii.md
        problemField.layer.borderWidth = 1
        problemField.layer.borderColor = DesignTokens.Colors.separator.cgColor
        problemField.returnKeyType = .done
        problemField.delegate = self
        problemField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        problemField.leftViewMode = .always
        problemField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        problemField.rightViewMode = .always
        problemField.attributedPlaceholder = NSAttributedString(
            string: "e.g. I can't focus at work, I stay up too late...",
            attributes: [.foregroundColor: DesignTokens.Colors.textTertiary]
        )
        problemField.addTarget(self, action: #selector(problemTextChanged), for: .editingChanged)

        suggestButton.addTarget(self, action: #selector(suggestTapped), for: .touchUpInside)
        suggestButton.isEnabled = false
        suggestButton.alpha = 0.5

        // Suggestions scroll area
        suggestionsScrollView.showsVerticalScrollIndicator = false
        suggestionsScrollView.keyboardDismissMode = .onDrag
        suggestionsScrollView.translatesAutoresizingMaskIntoConstraints = false

        suggestionsStack.axis = .vertical
        suggestionsStack.spacing = DesignTokens.Spacing.sm
        suggestionsStack.alignment = .fill
        suggestionsStack.translatesAutoresizingMaskIntoConstraints = false
        suggestionsScrollView.addSubview(suggestionsStack)

        // Layout
        let padding = DesignTokens.Spacing.lg

        for v in [promptLabel, promptSubtitle, problemField, suggestButton, suggestionsScrollView] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            wizardContainer.addSubview(v)
        }

        NSLayoutConstraint.activate([
            promptLabel.topAnchor.constraint(equalTo: wizardContainer.topAnchor, constant: DesignTokens.Spacing.sm),
            promptLabel.leadingAnchor.constraint(equalTo: wizardContainer.leadingAnchor, constant: padding),
            promptLabel.trailingAnchor.constraint(equalTo: wizardContainer.trailingAnchor, constant: -padding),

            promptSubtitle.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            promptSubtitle.leadingAnchor.constraint(equalTo: wizardContainer.leadingAnchor, constant: padding),
            promptSubtitle.trailingAnchor.constraint(equalTo: wizardContainer.trailingAnchor, constant: -padding),

            problemField.topAnchor.constraint(equalTo: promptSubtitle.bottomAnchor, constant: DesignTokens.Spacing.lg),
            problemField.leadingAnchor.constraint(equalTo: wizardContainer.leadingAnchor, constant: padding),
            problemField.trailingAnchor.constraint(equalTo: wizardContainer.trailingAnchor, constant: -padding),
            problemField.heightAnchor.constraint(equalToConstant: 48),

            suggestButton.topAnchor.constraint(equalTo: problemField.bottomAnchor, constant: DesignTokens.Spacing.md),
            suggestButton.leadingAnchor.constraint(equalTo: wizardContainer.leadingAnchor, constant: padding),
            suggestButton.trailingAnchor.constraint(equalTo: wizardContainer.trailingAnchor, constant: -padding),

            suggestionsScrollView.topAnchor.constraint(equalTo: suggestButton.bottomAnchor, constant: DesignTokens.Spacing.xl),
            suggestionsScrollView.leadingAnchor.constraint(equalTo: wizardContainer.leadingAnchor),
            suggestionsScrollView.trailingAnchor.constraint(equalTo: wizardContainer.trailingAnchor),
            suggestionsScrollView.bottomAnchor.constraint(equalTo: wizardContainer.bottomAnchor),

            suggestionsStack.topAnchor.constraint(equalTo: suggestionsScrollView.topAnchor),
            suggestionsStack.leadingAnchor.constraint(equalTo: suggestionsScrollView.leadingAnchor, constant: padding),
            suggestionsStack.trailingAnchor.constraint(equalTo: suggestionsScrollView.trailingAnchor, constant: -padding),
            suggestionsStack.bottomAnchor.constraint(equalTo: suggestionsScrollView.bottomAnchor, constant: -padding),
            suggestionsStack.widthAnchor.constraint(equalTo: suggestionsScrollView.widthAnchor, constant: -padding * 2),
        ])
    }

    @objc private func problemTextChanged() {
        let hasText = !(problemField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        suggestButton.isEnabled = hasText
        UIView.animate(withDuration: 0.2) {
            self.suggestButton.alpha = hasText ? 1.0 : 0.5
        }
    }

    @objc private func suggestTapped() {
        guard let text = problemField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        view.endEditing(true)
        Haptics.light()

        // Route to the Speak tab — dismiss the editor and send the problem as a message
        if let callback = onAskAISuggestion {
            callback(text)
        } else {
            print("[DirectiveEditor] onAskAISuggestion not set — cannot route to Speak tab")
        }
    }

    private func showSuggestions(_ suggestions: [DirectiveWizard.Suggestion]) {
        currentSuggestions = suggestions
        suggestButton.isEnabled = true
        suggestButton.setTitle("Suggest Directives", for: .normal)

        if suggestions.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No suggestions for that. Try describing a specific problem — like \"I can't focus\" or \"I stay up too late.\""
            emptyLabel.font = DesignTokens.Typography.subheadline
            emptyLabel.textColor = DesignTokens.Colors.textTertiary
            emptyLabel.textAlignment = .center
            emptyLabel.numberOfLines = 0
            suggestionsStack.addArrangedSubview(emptyLabel)
            return
        }

        for (i, suggestion) in suggestions.enumerated() {
            let card = makeSuggestionCard(suggestion, index: i)
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 15)
            suggestionsStack.addArrangedSubview(card)

            UIView.animate(
                withDuration: 0.4,
                delay: 0.1 + Double(i) * 0.1,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                card.alpha = 1
                card.transform = .identity
            }
        }
    }

    // MARK: - API Types

    private struct WizardAPIRequest: Encodable {
        let problem: String
    }

    private struct WizardAPIResponse: Decodable {
        let suggestions: [WizardSuggestion]
    }

    private struct WizardSuggestion: Decodable {
        let id: String
        let title: String
        let body: String
    }

    private func makeSuggestionCard(_ suggestion: DirectiveWizard.Suggestion, index: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.layer.borderWidth = 1
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor

        let titleLabel = UILabel()
        titleLabel.text = suggestion.title
        titleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.text = suggestion.body
        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0

        let addIcon = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
        addIcon.tintColor = DesignTokens.Colors.accent
        addIcon.contentMode = .scaleAspectFit
        addIcon.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xs

        let rowStack = UIStackView(arrangedSubviews: [textStack, addIcon])
        rowStack.axis = .horizontal
        rowStack.spacing = DesignTokens.Spacing.md
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rowStack)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            addIcon.widthAnchor.constraint(equalToConstant: 28),
            addIcon.heightAnchor.constraint(equalToConstant: 28),
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])

        // Tap gesture
        card.tag = index
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(suggestionTapped(_:))))

        return card
    }

    @objc private func suggestionTapped(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view, card.tag < currentSuggestions.count else { return }
        let suggestion = currentSuggestions[card.tag]

        // Flash the card
        UIView.animate(withDuration: 0.1, animations: {
            card.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.1)
            card.layer.borderColor = DesignTokens.Colors.accent.cgColor
            card.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                card.transform = .identity
            }
        }

        Haptics.success()

        // Create the directive
        Task {
            do {
                _ = try await directiveService?.create(
                    title: suggestion.title,
                    body: suggestion.body
                )
                await MainActor.run {
                    self.onSave?()
                }
            } catch {
                Haptics.error()
            }
        }
    }

    // MARK: - Manual Form

    private func buildManualForm() {
        manualContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(manualContainer)

        let topAnchor: NSLayoutYAxisAnchor
        if directiveId == nil {
            topAnchor = modeSegment.bottomAnchor
        } else {
            topAnchor = contentTopAnchor
        }

        NSLayoutConstraint.activate([
            manualContainer.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.sm),
            manualContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            manualContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            manualContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        manualContainer.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = DesignTokens.Spacing.xl
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(titleField)
        stackView.addArrangedSubview(bodyField)
        stackView.addArrangedSubview(colorPicker)
        stackView.addArrangedSubview(statusPicker)
        stackView.addArrangedSubview(balloonSection)
        stackView.addArrangedSubview(scheduleSection)

        let padding = DesignTokens.Spacing.lg

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: manualContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: manualContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: manualContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: manualContainer.bottomAnchor),

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
        colorPicker.onColorChanged = { [weak self] hex in
            self?.selectedColor = hex
        }
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
            selectedColor = directive.color

            statusPicker.setStatus(directive.status)
            colorPicker.setColor(directive.color)
            durationHours = directive.balloonDurationSec / 3600
            balloonSection.configure(isEnabled: directive.balloonEnabled, durationHours: durationHours)

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
                    existing.color = selectedColor
                    existing.status = selectedStatus
                    existing.balloonEnabled = balloonEnabled
                    if existing.balloonDurationSec != durationSec || (!existing.balloonEnabled && balloonEnabled) {
                        existing.balloonSnapshotSec = durationSec
                    }
                    existing.balloonDurationSec = durationSec
                    try await directiveService?.update(existing)
                } else {
                    let newDir = try await directiveService?.create(
                        title: title, body: body,
                        color: selectedColor,
                        balloonEnabled: balloonEnabled,
                        balloonDurationSec: durationSec
                    )
                    newDirectiveId = newDir?.id
                }
                let dirId = directiveId ?? newDirectiveId
                if let dirId {
                    try? self.saveScheduleRule(directiveId: dirId)

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

        guard !params.isEmpty else {
            if let existing = existingScheduleRule {
                try dbQueue.write { db in
                    _ = try ScheduleRule.deleteOne(db, key: existing.id)
                    try OutboxOp.enqueueDelete(entityType: "scheduleRule", entityId: existing.id.uuidString, in: db)
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
                try OutboxOp.enqueue(entityType: "scheduleRule", entityId: existing.id.uuidString, op: "update", patch: existing.syncPatch(), baseUpdatedAt: existing.updatedAt, in: db)
            } else {
                let now = Date()
                let rule = ScheduleRule(
                    id: UUID(), directiveId: directiveId,
                    ruleType: ruleType, params: params,
                    version: 1, createdAt: now, updatedAt: now
                )
                try rule.insert(db)
                try OutboxOp.enqueue(entityType: "scheduleRule", entityId: rule.id.uuidString, op: "create", patch: rule.syncPatch(), in: db)
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
        suggestionsScrollView.contentInset.bottom = frame.height
        suggestionsScrollView.verticalScrollIndicatorInsets.bottom = frame.height
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
        suggestionsScrollView.contentInset.bottom = 0
        suggestionsScrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}

// MARK: - UITextFieldDelegate

extension DirectiveEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == problemField {
            suggestTapped()
        }
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == problemField else { return true }
        let current = textField.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: r, with: string).count <= FieldLimits.AI.prompt
    }
}
