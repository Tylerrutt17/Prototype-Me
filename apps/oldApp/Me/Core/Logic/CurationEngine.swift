import Foundation
import SwiftData

struct CurationEngine {
    /// Returns tuple (interventionIDs, notePageIDs)
    static func curated(for trackables: [Trackable],
                       values: [String: Int],
                       pages: [NotePage],
                       interventions: [Intervention]) -> ([String], [String]) {
        var chosenInts: Set<String> = Set(interventions.filter { $0.isEveryDay }.map { $0.id })
        var chosenPages: Set<String> = Set(pages.filter { $0.isEveryDay }.map { $0.id })

        let allLow = values.values.allSatisfy { $0 <= 3 }

        func items(for trackableId: String, level: Int) -> ([Intervention], [NotePage]) {
            let ints = interventions.filter {
                $0.trackableId == trackableId && level >= $0.minSeverity && level <= $0.maxSeverity
            }
            let notes = pages.filter {
                $0.trackableId == trackableId && level >= $0.minSeverity && level <= $0.maxSeverity
            }
            return (ints, notes)
        }

        func basicItems(for trackableId: String) -> ([Intervention], [NotePage]) {
            let ints = interventions.filter { $0.trackableId == trackableId && $0.maxSeverity <= 3 }
            let notes = pages.filter { $0.trackableId == trackableId && $0.maxSeverity <= 3 }
            return (ints, notes)
        }

        if allLow {
            for t in trackables {
                let (ints, notes) = basicItems(for: t.id)
                chosenInts.formUnion(ints.map { $0.id })
                chosenPages.formUnion(notes.map { $0.id })
            }
        } else if let (primaryId, primaryLevel) = values.max(by: { $0.value < $1.value }) {
            let (intsPrim, notesPrim) = items(for: primaryId, level: primaryLevel)
            chosenInts.formUnion(intsPrim.map { $0.id })
            chosenPages.formUnion(notesPrim.map { $0.id })
            for t in trackables where t.id != primaryId {
                let (ints, notes) = basicItems(for: t.id)
                chosenInts.formUnion(ints.map { $0.id })
                chosenPages.formUnion(notes.map { $0.id })
            }
        }

        // Sort interventions
        let byIdInt = Dictionary(uniqueKeysWithValues: interventions.map { ($0.id, $0) })
        let sortedInt = chosenInts.compactMap { byIdInt[$0] }
            .sorted { lhs, rhs in
                if lhs.isEveryDay != rhs.isEveryDay { return lhs.isEveryDay && !rhs.isEveryDay }
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.title < rhs.title
            }
            .map { $0.id }

        // Sort pages by similar rules
        let byIdPage = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
        let sortedPage = chosenPages.compactMap { byIdPage[$0] }
            .sorted { lhs, rhs in
                if lhs.isEveryDay != rhs.isEveryDay { return lhs.isEveryDay && !rhs.isEveryDay }
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.title < rhs.title
            }
            .map { $0.id }

        return (sortedInt, sortedPage)
    }
}

