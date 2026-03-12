import Foundation
import SwiftData

/// Manages countdown auto-resets and notification rescheduling.
@MainActor
enum CountdownService {
    /// Ensures every enabled countdown has an expiry and auto-resets any that have elapsed.
    static func refreshCountdowns(in context: ModelContext) async {
        let descriptor = FetchDescriptor<Intervention>(predicate: #Predicate { $0.countdownEnabled == true })
        let interventions = (try? context.fetch(descriptor)) ?? []
        let now = Date()

        for iv in interventions {
            if iv.countdownExpiresAt == nil {
                iv.seedCountdownIfNeeded(now: now)
            } else if let expires = iv.countdownExpiresAt, expires <= now {
                // Auto-reset: next 9am at least 24h out, then a full duration from that point.
                let resetStart = nextResetStart(after: expires)
                iv.countdownResetAt = resetStart
                iv.countdownExpiresAt = resetStart.addingTimeInterval(iv.countdownDurationSeconds)
            }

            if let expires = iv.countdownExpiresAt {
                await NotificationScheduler.scheduleDirectiveCountdown(id: iv.id,
                                                                       title: iv.title,
                                                                       expiresAt: expires,
                                                                       durationSeconds: iv.countdownDurationSeconds)
            }
        }

        try? context.save()
    }

    /// Returns the next 9am that is at least 24 hours after the provided date.
    static func nextResetStart(after date: Date, calendar: Calendar = .current) -> Date {
        let minimum = date.addingTimeInterval(86_400) // 24h later
        var comps = calendar.dateComponents([.year, .month, .day], from: minimum)
        comps.hour = 9
        comps.minute = 0
        comps.second = 0
        var candidate = calendar.date(from: comps) ?? minimum.addingTimeInterval(86_400)
        if candidate < minimum {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86_400)
        }
        return candidate
    }
}

