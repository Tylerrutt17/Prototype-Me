import Foundation
import SwiftData

@Model
public final class DailyCuratedNote {
    @Attribute public var id: String = "" // yyyy-MM-dd
    public var date: Date = Date()
    @Attribute public var metricLevels: [String: Int] = [:]
    public var interventionIDs: [String] = []
    /// IDs of goal interventions the user has completed for this day.
    public var completedGoalIDs: [String] = []
    /// IDs of NotePages selected for this curated note.
    public var notePageIDs: [String] = []

    public init(id: String = "", date: Date = Date(), metricLevels: [String: Int] = [:], interventionIDs: [String] = [], notePageIDs: [String] = []) {
        self.id = id
        self.date = date
        self.metricLevels = metricLevels
        self.interventionIDs = interventionIDs
        self.notePageIDs = notePageIDs
    }
}
