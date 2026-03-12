// Copied and adapted from old Topics version
import SwiftUI
import SwiftData
import RichEditorSwiftUI

enum SeverityMode: String, CaseIterable, Identifiable {
    case atMost = "≤"
    case equal = "="
    case atLeast = "≥"
    var id: String { rawValue }
}

struct InterventionEditorView: View {
    @Bindable var intervention: Intervention
    @Query private var trackables: [Trackable]
    @Environment(\.modelContext) private var context
    @State private var mode: SeverityMode = .atLeast
    @State private var editorState: RichEditorState
    @State private var colorNames: [String] = ["red","orange","yellow","green","blue","indigo","purple","gray"]
    @State private var notificationDebounceTask: Task<Void, Never>? = nil

    init(intervention: Intervention) {
        self._intervention = Bindable(wrappedValue: intervention)
        self._editorState = State(initialValue: intervention.makeEditorState())
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $intervention.title, axis: .vertical)
                    .lineLimit(1...2)
                    .foregroundStyle(tintColor)
            }
            Section("Details") {
                RichNoteField(model: intervention, state: editorState)
                    .frame(minHeight: 250, maxHeight: .infinity, alignment: .top) // dynamic height
            }
            AudioAttachmentsSection(intervention: intervention)
            Section("Countdown Balloon") { countdownSection }
            Section("Daily Notification") { dailyNotificationSection }
            if intervention.trackableId != nil {
                Section("Severity Threshold") { severityControls }
            }
            Section("Tracker") {
                Picker("Trackable", selection: $intervention.trackableId) {
                    Text("None").tag(Optional<String>(nil))
                    ForEach(trackables, id: \.id) { t in
                        Text(t.name).tag(Optional<String>(t.id))
                    }
                }
            }
            Section("Color") {
                Picker("Color", selection: Binding(get: { intervention.colorName ?? "" }, set: { val in intervention.colorName = val.isEmpty ? nil : val })) {
                    Text("Default").tag("")
                    ForEach(colorNames, id: \.self) { name in
                        HStack {
                            Circle().fill(Color.named(name)).frame(width: 20, height: 20)
                            Text(name.capitalized)
                        }.tag(name)
                    }
                }
                Picker("Row Background", selection: Binding(get: { intervention.rowBackgroundName ?? "" }, set: { val in intervention.rowBackgroundName = val.isEmpty ? nil : val })) {
                    Text("None").tag("")
                    ForEach(colorNames, id: \.self) { name in
                        HStack {
                            Rectangle().fill(Color.named(name)).frame(width: 20, height: 20)
                            Text(name.capitalized)
                        }.tag(name)
                    }
                }
            }
            Section("Priority & Daily") { priorityControls }
        }
        .navigationTitle("Directive") // visually rename Intervention → Directive
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if intervention.maxSeverity != 10 { intervention.maxSeverity = 10 } }
        .onDisappear {
            cachePlainDetails()
            try? context.save()
        }
#if os(iOS)
        .safeAreaInset(edge: .bottom, alignment: .center) {
            RichTextKeyboardToolbar(
                context: editorState,
                leadingButtons: { $0 },
                trailingButtons: { $0 },
                formatSheet: { $0 }
            )
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
#endif
    }

    // MARK: Subviews
    private var severityControls: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Mode", selection: $mode) {
                    ForEach(SeverityMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented).frame(width: 120)
                Spacer()
                Text(thresholdLabel())
            }
            Slider(value: Binding(get: { Double(thresholdValue()) }, set: { updateThreshold(Int($0)) }), in: 0...10, step: 1)
                .tint(severityColor(thresholdValue()))
            Text(explanationText()).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
        }
    }

    private var priorityControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Priority: \(intervention.priority)")
                Spacer()
                Text(priorityLabel(intervention.priority))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { Double(intervention.priority) },
                                  set: { intervention.priority = Int($0) }),
                   in: 0...100, step: 1)
                .tint(priorityColor(intervention.priority))
            Toggle("Every day", isOn: $intervention.isEveryDay)
            Toggle("Goal", isOn: $intervention.isGoal)
            Text("Higher priority shows earlier in the daily list. 0 = lowest, 100 = highest.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Helpers
    private func severityColor(_ value: Int) -> Color {
        let ratio = Double(value) / 10.0
        let hue = 0.33 - 0.33 * ratio
        return Color(hue: hue, saturation: 0.9, brightness: 0.9)
    }
    private func priorityColor(_ value: Int) -> Color {
        let ratio = Double(value) / 100.0
        let hue = 0.33 - 0.33 * ratio
        return Color(hue: hue, saturation: 0.9, brightness: 0.9)
    }
    private func priorityLabel(_ value: Int) -> String {
        switch value { case 0...25: return "Low"; case 26...60: return "Medium"; case 61...85: return "High"; default: return "Critical" }
    }
    private func thresholdValue() -> Int {
        switch mode { case .atLeast: return intervention.minSeverity; case .atMost: return intervention.maxSeverity; case .equal: return intervention.minSeverity }
    }
    private func updateThreshold(_ value: Int) {
        switch mode {
        case .atLeast: intervention.minSeverity = value; intervention.maxSeverity = 10
        case .atMost: intervention.minSeverity = 0; intervention.maxSeverity = value
        case .equal: intervention.minSeverity = value; intervention.maxSeverity = value
        }
    }
    private func thresholdLabel() -> String { "Level \(thresholdValue())" }
    private func explanationText() -> String {
        switch mode { case .atLeast: return "Appears when level is ≥ \(thresholdValue())."; case .atMost: return "Appears when level is ≤ \(thresholdValue())."; case .equal: return "Appears only when level is exactly \(thresholdValue()).." }
    }

    /// Saves a plain-text version of the details for fast list rendering.
    private func cachePlainDetails() {
        // If we already captured plain text during rich save, keep it.
        guard intervention.detailsPlain.isEmpty else { return }
        // Otherwise derive from markdown/HTML best-effort.
        intervention.detailsPlain = RichNoteMarkdown.editorReadyText(from: intervention.detailsMarkdown)
    }

    // MARK: Countdown
    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable countdown", isOn: Binding(get: {
                intervention.countdownEnabled
            }, set: { val in
                intervention.countdownEnabled = val
                handleCountdownToggle(val)
            }))

            if intervention.countdownEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: countdownDurationBinding, in: 60...10_080, step: 15) {
                        Text("Length")
                    } minimumValueLabel: {
                        Text("1h")
                    } maximumValueLabel: {
                        Text("7d")
                    }
                    Text("Balloon length: \(formatDuration(intervention.countdownDurationMinutes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                CountdownBalloonView(intervention: intervention, pumpAction: pumpBalloon)
            } else {
                Text("Turn this on to add a playful “balloon” that slowly deflates over time until you check in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Daily Notification
    private var dailyNotificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable daily notification", isOn: Binding(get: {
                intervention.dailyNotificationEnabled
            }, set: { val in
                intervention.dailyNotificationEnabled = val
                handleDailyNotificationToggle(val)
            }))

            if intervention.dailyNotificationEnabled {
                DatePicker("Time", selection: dailyNotificationTimeBinding, displayedComponents: .hourAndMinute)
                Text("Get a push notification for this directive every day at this time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Set a daily reminder to check in on this directive at a specific time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dailyNotificationTimeBinding: Binding<Date> {
        Binding(get: {
            let midnight = Calendar.current.startOfDay(for: Date())
            return midnight.addingTimeInterval(max(0, min(86340, intervention.dailyNotificationTime)))
        }, set: { newDate in
            let midnight = Calendar.current.startOfDay(for: newDate)
            intervention.dailyNotificationTime = newDate.timeIntervalSince(midnight)
            scheduleDailyNotificationDebounced()
        })
    }

    private func handleDailyNotificationToggle(_ enabled: Bool) {
        if enabled {
            Task {
                await NotificationScheduler.scheduleDirectiveDailyNotification(
                    id: intervention.id,
                    title: intervention.title,
                    timeSeconds: intervention.dailyNotificationTime)
            }
        } else {
            Task { await NotificationScheduler.cancelDirectiveDailyNotification(id: intervention.id) }
        }
        try? context.save()
    }

    private func scheduleDailyNotificationDebounced() {
        notificationDebounceTask?.cancel()
        notificationDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await NotificationScheduler.scheduleDirectiveDailyNotification(
                id: intervention.id,
                title: intervention.title,
                timeSeconds: intervention.dailyNotificationTime)
        }
    }

    private func handleCountdownToggle(_ enabled: Bool) {
        if enabled {
            intervention.seedCountdownIfNeeded()
            Task { await scheduleCountdownNotification() }
        } else {
            intervention.countdownExpiresAt = nil
            Task { await NotificationScheduler.cancelDirectiveCountdown(id: intervention.id) }
        }
        try? context.save()
    }

    private func handleDurationChange(_ days: Int) {
        let minutes = Double(days) * 1_440
        intervention.rescaleCountdownDuration(toMinutes: minutes)
        intervention.seedCountdownIfNeeded()
        try? context.save()
        scheduleCountdownNotificationDebounced()
    }

    private func handleDurationChangeMinutes(_ minutes: Double) {
        intervention.rescaleCountdownDuration(toMinutes: minutes)
        intervention.seedCountdownIfNeeded()
        try? context.save()
        scheduleCountdownNotificationDebounced()
    }

    private func pumpBalloon() {
        intervention.seedCountdownIfNeeded()
        _ = intervention.pumpCountdown()
        try? context.save()
        Task { await scheduleCountdownNotification() }
    }

    private func scheduleCountdownNotification() async {
        guard intervention.countdownEnabled, let expires = intervention.countdownExpiresAt else {
            await NotificationScheduler.cancelDirectiveCountdown(id: intervention.id)
            return
        }
        await NotificationScheduler.scheduleDirectiveCountdown(id: intervention.id,
                                                               title: intervention.title,
                                                               expiresAt: expires,
                                                               durationSeconds: intervention.countdownDurationSeconds)
    }

    private func scheduleCountdownNotificationDebounced() {
        notificationDebounceTask?.cancel()
        notificationDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // 350ms debounce
            if Task.isCancelled { return }
            await scheduleCountdownNotification()
        }
    }

    // MARK: Tint helper
    private var tintColor: Color {
        if let name = intervention.colorName {
            return Color.named(name)
        }
        return .primary
    }

    private var countdownDurationBinding: Binding<Double> {
        Binding(get: {
            max(60, intervention.countdownDurationMinutes)
        }, set: { newVal in
            handleDurationChangeMinutes(newVal)
        })
    }

    private func formatDuration(_ minutes: Double) -> String {
        let total = max(1, Int(minutes.rounded()))
        let days = total / 1_440
        let hours = (total % 1_440) / 60
        let mins = total % 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if mins > 0 && days == 0 { parts.append("\(mins)m") }
        return parts.isEmpty ? "1m" : parts.joined(separator: " ")
    }
}

// MARK: - Countdown visuals
private struct CountdownBalloonView: View {
    let intervention: Intervention
    let pumpAction: () -> Void
    @State private var pumpScale: CGFloat = 1.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(alignment: .leading, spacing: 8) {
                if let progress = intervention.countdownProgress(reference: timeline.date),
                   let remaining = intervention.countdownRemaining(reference: timeline.date) {
                    HStack {
                        ZStack {
                            Circle()
                                .stroke(lineWidth: 10)
                                .foregroundStyle(Color(.tertiarySystemFill))
                            Circle()
                                .trim(from: 0, to: progress)
                                .rotation(.degrees(-90))
                                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .foregroundStyle(balloonColor(progress))
                            VStack(spacing: 2) {
                                Text("\(Int(progress * 100))%")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                Text(label(for: remaining))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 8)
                            }
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        .frame(width: 90, height: 90)
                        .scaleEffect(pumpScale)
                        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: pumpScale)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(progress < 0.2 ? "Needs air soon" : "Balloon health")
                                .font(.subheadline)
                                .foregroundStyle(balloonColor(progress))
                            ProgressView(value: progress)
                                .tint(balloonColor(progress))
                            Text("Tap to pump +\(Int(Intervention.countdownPumpStep * 100))% per press.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Countdown is off.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    pumpWithHaptics()
                } label: {
                    Label("Pump balloon", systemImage: "hand.tap.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func balloonColor(_ progress: Double) -> Color {
        if progress < 0.2 { return .red }
        if progress < 0.4 { return .orange }
        if progress < 0.7 { return .yellow }
        return .green
    }

    private func label(for remaining: TimeInterval) -> String {
        if remaining <= 0 { return "Expired" }
        let totalSeconds = Int(remaining.rounded())
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 || days > 0 { parts.append("\(hours)h") }
        if minutes > 0 || hours > 0 || days > 0 { parts.append("\(minutes)m") }
        parts.append("\(seconds)s")
        return parts.joined(separator: " ") + " left"
    }

    private func pumpWithHaptics() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        pumpAction()
        pumpScale = 1.15
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            pumpScale = 1.0
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Intervention.self)
    let ctx = ModelContext(container)
    let i = Intervention(pageId: "tmp", title: "Breathing")
    ctx.insert(i)
    return NavigationStack { InterventionEditorView(intervention: i).modelContainer(container) }
}
