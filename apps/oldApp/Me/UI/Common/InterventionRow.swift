import SwiftUI
import SwiftData
import Foundation // for regex replacements

/// Consistent visual representation of an `Intervention`.
/// Used in curated note, history, and any other place interventions are listed.
struct InterventionRow: View {
    enum RowStyle: CaseIterable { case compact, badge, detailed, titleOnly }

    let intervention: Intervention
    var style: RowStyle = .compact

    // Access available trackables to resolve colors when Intervention has a trackableId but no explicit color
    @Query private var trackables: [Trackable]

    var body: some View {
        let tint = trackableColor(for: intervention)
        let content: AnyView = {
            switch style {
            case .badge:
                return AnyView(
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(priorityColor(intervention.priority))
                            Text("\(intervention.priority)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intervention.title)
                                .font(.headline)
                                .foregroundStyle(tint)
                                .lineLimit(2)
                            let textSource = previewText(for: intervention)
                            if !textSource.isEmpty {
                                Text(plainSnippet(from: textSource, limit: 120))
                                    .foregroundStyle(tint)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .padding(6)
                )

            case .compact:
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intervention.title)
                                .font(.headline)
                                .foregroundStyle(tint)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 6)
                        if intervention.isGoal {
                            Image(systemName: "checkmark.circle")
                                .symbolVariant(.circle)
                                .foregroundStyle(.secondary)
                        }
                        Text("P\(intervention.priority)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(priorityColor(intervention.priority))
                            .foregroundStyle(Color.white)
                            .cornerRadius(4)
                    }
                    .padding(6)
                )

            case .detailed:
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intervention.title)
                                .font(.headline)
                                .foregroundStyle(tint)
                                .lineLimit(2)
                            let textSource = previewText(for: intervention)
                            if !textSource.isEmpty {
                                Text(plainSnippet(from: textSource, limit: 120))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(6)
                )

            case .titleOnly:
                return AnyView(
                    HStack(alignment: .center, spacing: 8) {
                        Text(intervention.title)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(tint)
                            .lineLimit(2)
                    }
                    .padding(6)
                )
            }
        }()

        return VStack(alignment: .leading, spacing: 6) {
            content
            if intervention.countdownEnabled {
                CountdownStrip(intervention: intervention)
            }
        }
        .background(flashBackground)
        .listRowInsets(EdgeInsets())
        .frame(maxWidth: .infinity, alignment: .leading)
        // Background now applied by parent container
    }

    // MARK: - Helpers
    private func previewText(for iv: Intervention) -> String {
        if !iv.detailsPlain.isEmpty { return iv.detailsPlain }
        return RichNoteMarkdown.editorReadyText(from: iv.detailsMarkdown)
    }

    // rowBackgroundColor moved to InterventionList; no longer needed here

    private func priorityColor(_ value: Int) -> Color {
        let ratio = Double(max(0, min(100, value))) / 100.0 // 0..1
        // Purple (hue 0.78) to Green (hue 0.33)
        let hueStart = 0.78, hueEnd = 0.33
        let hue = hueStart + (hueEnd - hueStart) * ratio
        return Color(hue: hue, saturation: 0.8, brightness: 0.8)
    }

    private func trackableColor(for iv: Intervention) -> Color {
        // Explicit color on Intervention overrides everything
        if let cname = iv.colorName {
            return Color.named(cname)
        }
        // Use linked Trackable’s color when available
        if let tid = iv.trackableId, let t = trackables.first(where: { $0.id == tid }) {
            return Color.named(t.colorName)
        }
        // Fallback: system accent color to ensure non-white tint
        return .accentColor
    }

    /// Returns a plain string by stripping markdown and custom underline tags from the given text.
    private func plainSnippet(from markdown: String, limit: Int = 120) -> String {
        var cleaned = markdown.replacingOccurrences(of: "[[u]]", with: "").replacingOccurrences(of: "[[/u]]", with: "")
        if cleaned.count > limit { cleaned = String(cleaned.prefix(limit)) + "…" }
        if let attr = try? AttributedString(markdown: cleaned) {
            return String(attr.characters)
        }
        return cleaned
    }

    // Flashing background when countdown is empty
    private var flashBackground: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let progress = intervention.countdownProgress(reference: timeline.date) ?? 1.0
            let isEmpty = progress <= 0.01
            let baseColor = rowTint()
            let opacity = isEmpty ? flashingOpacity(at: timeline.date) : 0
            baseColor.opacity(opacity)
        }
    }

    private func rowTint() -> Color {
        if let cname = intervention.colorName {
            return Color.named(cname)
        }
        if let tid = intervention.trackableId, let t = trackables.first(where: { $0.id == tid }) {
            return Color.named(t.colorName)
        }
        return .yellow.opacity(0.8)
    }

    private func flashingOpacity(at date: Date) -> Double {
        // Smooth pulse between 0.15 and 0.4
        let t = date.timeIntervalSince1970
        let phase = (sin(t * 2 * .pi / 2) + 1) / 2 // 2s period
        return 0.15 + (0.25 * phase)
    }
}

// MARK: - Countdown UI
private struct CountdownStrip: View {
    let intervention: Intervention

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            if let progress = intervention.countdownProgress(reference: timeline.date),
               let remaining = intervention.countdownRemaining(reference: timeline.date) {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                            Capsule()
                                .fill(balloonColor(progress))
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)

                    HStack(spacing: 6) {
                        Image(systemName: remaining <= 0 ? "exclamationmark.triangle.fill" : "timer")
                            .font(.caption2)
                            .foregroundStyle(balloonColor(progress))
                        Text(label(for: remaining))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption2).bold()
                            .foregroundStyle(balloonColor(progress))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func balloonColor(_ progress: Double) -> Color {
        if progress < 0.2 { return .red }
        if progress < 0.4 { return .orange }
        if progress < 0.7 { return .yellow }
        return .green
    }

    private func label(for remaining: TimeInterval) -> String {
        if remaining <= 0 { return "Needs check-in" }
        let days = Int(remaining / 86_400)
        let hours = Int((remaining.truncatingRemainder(dividingBy: 86_400)) / 3_600)
        if days > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h left" }
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3_600)) / 60)
        return "\(minutes)m left"
    }
}

#Preview {
    let iv: Intervention = {
        var temp = Intervention(title: "Try breathing exercise")
        temp.priority = 75
        temp.detailsMarkdown = "Take 5 deep breaths."
        return temp
    }()
    VStack {
        List { InterventionRow(intervention: iv) } // default pill
        List { InterventionRow(intervention: iv, style: .badge) }
    }
}
