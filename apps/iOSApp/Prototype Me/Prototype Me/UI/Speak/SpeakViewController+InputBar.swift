import UIKit

// MARK: - Free Tier Input Bar, Keyboard, Text View Delegate

extension SpeakViewController {

    // MARK: - Input Bar Setup

    func setupFreeInputBar() {
        inputBar.backgroundColor = DesignTokens.Colors.background.withAlphaComponent(0.4)
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)

        let separator = UIView()
        separator.backgroundColor = DesignTokens.Colors.separator.withAlphaComponent(0.3)
        separator.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(separator)

        // Clear button
        var clearConfig = UIButton.Configuration.plain()
        clearConfig.image = UIImage(systemName: "xmark.circle.fill")
        clearConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        clearConfig.baseForegroundColor = DesignTokens.Colors.textTertiary
        clearConfig.contentInsets = .zero
        clearButton.configuration = clearConfig
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.isHidden = true
        clearButton.setContentHuggingPriority(.required, for: .horizontal)
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        // Field container
        fieldContainer.backgroundColor = DesignTokens.Colors.surfacePrimary
        fieldContainer.layer.cornerRadius = DesignTokens.Radii.xl
        fieldContainer.layer.borderWidth = 1.5
        fieldContainer.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.2).cgColor
        fieldContainer.clipsToBounds = true
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(fieldContainer)
        fieldContainer.addSubview(clearButton)

        // Text view
        textView.font = DesignTokens.Typography.body
        textView.textColor = DesignTokens.Colors.textPrimary
        textView.tintColor = DesignTokens.Colors.accent
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.returnKeyType = .done
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(textView)

        // Placeholder
        placeholderLabel.text = "Ask about something..."
        placeholderLabel.font = DesignTokens.Typography.body
        placeholderLabel.textColor = DesignTokens.Colors.textTertiary
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(placeholderLabel)

        // Send button
        var sendConfig = UIButton.Configuration.filled()
        sendConfig.image = UIImage(systemName: "arrow.up.circle.fill")
        sendConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 28)
        sendConfig.baseBackgroundColor = .clear
        sendConfig.baseForegroundColor = DesignTokens.Colors.accent
        sendConfig.contentInsets = .zero
        sendButton.configuration = sendConfig
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.alpha = 0.3
        fieldContainer.addSubview(sendButton)

        inputBarBottom = inputBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        responseBottomConstraint = responseScrollView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        fieldContainerHeight = fieldContainer.heightAnchor.constraint(equalToConstant: 48)

        textViewLeadingDefault = textView.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: DesignTokens.Spacing.lg)
        textViewLeadingWithClear = textView.leadingAnchor.constraint(equalTo: clearButton.trailingAnchor, constant: DesignTokens.Spacing.xs)
        textViewLeadingDefault.isActive = true

        NSLayoutConstraint.activate([
            responseBottomConstraint,

            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBarBottom,

            separator.topAnchor.constraint(equalTo: inputBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            fieldContainer.topAnchor.constraint(equalTo: inputBar.topAnchor, constant: DesignTokens.Spacing.sm),
            fieldContainer.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: DesignTokens.Spacing.md),
            fieldContainer.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -DesignTokens.Spacing.md),
            fieldContainer.bottomAnchor.constraint(equalTo: inputBar.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            fieldContainerHeight,

            clearButton.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: DesignTokens.Spacing.sm),
            clearButton.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 28),
            clearButton.heightAnchor.constraint(equalToConstant: 28),

            textView.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            textView.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),
            textView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -DesignTokens.Spacing.sm),

            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: -DesignTokens.Spacing.sm),
            sendButton.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalToConstant: 34),
        ])

        inputAreaTopAnchor = inputBar.topAnchor
        view.bringSubviewToFront(inputBar)
    }

    // MARK: - Keyboard

    func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        isKeyboardVisible = true
        inputBarBottom.constant = -frame.height
        if isPro {
            responseBottomConstraint.isActive = false
            responseBottomConstraint = responseScrollView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
            responseBottomConstraint.isActive = true
        }
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
            if self.isPro {
                self.proMicButton.alpha = 0
                self.proStatusLabel.alpha = 0
                self.proWaveformView.alpha = 0
                self.proStopButton.alpha = 0
            }
        }
    }

    @objc func keyboardWillHide(_ note: Notification) {
        guard let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        isKeyboardVisible = false
        inputBarBottom.constant = 0
        if isPro {
            responseBottomConstraint.isActive = false
            responseBottomConstraint = responseScrollView.bottomAnchor.constraint(equalTo: proMicButton.topAnchor, constant: -DesignTokens.Spacing.md)
            responseBottomConstraint.isActive = true
        }
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
            if self.isPro && !self.isProcessing && !self.isRecording {
                self.proMicButton.alpha = 1
                self.proStatusLabel.alpha = 1
            }
        }
    }

    // MARK: - Actions

    @objc func sendTapped() {
        guard !isProcessing else { return }
        let text = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        textView.text = ""
        placeholderLabel.isHidden = false
        updateTextViewHeight()
        textView.resignFirstResponder()
        hideThinkingContext(animated: false)
        sendMessage(text)
    }

    @objc func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    @objc func clearTapped() {
        textView.text = ""
        placeholderLabel.isHidden = false
        updateTextViewHeight()
        clearButton.isHidden = true
        textViewLeadingWithClear.isActive = false
        textViewLeadingDefault.isActive = true
        sendButton.alpha = 0.3
        UIView.animate(withDuration: 0.15) {
            self.view.layoutIfNeeded()
        }
    }

    func updateClearButton() {
        let hasText = !textView.text.isEmpty
        clearButton.isHidden = !hasText
        textViewLeadingDefault.isActive = !hasText
        textViewLeadingWithClear.isActive = hasText
        UIView.animate(withDuration: 0.15) {
            self.view.layoutIfNeeded()
        }
    }

    func updateTextViewHeight() {
        let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
        let newHeight = min(max(44, size.height), maxTextViewHeight)
        if fieldContainerHeight.constant != newHeight {
            fieldContainerHeight.constant = newHeight
            textView.isScrollEnabled = size.height > maxTextViewHeight
            UIView.animate(withDuration: 0.15) {
                self.view.layoutIfNeeded()
            }
        }
    }
}

// MARK: - UITextViewDelegate

extension SpeakViewController: UITextViewDelegate {
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        let current = textView.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: r, with: text).count <= FieldLimits.AI.speakMessage
    }

    public func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateTextViewHeight()
        updateClearButton()

        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        UIView.animate(withDuration: 0.15) {
            self.sendButton.alpha = hasText ? 1.0 : 0.3
        }
    }
}
