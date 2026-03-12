import Foundation
import SwiftData

/// Handles importing app data from a JSON payload.
/// The JSON must be an object containing optional arrays keyed by model name, e.g.:
/// {
///   "pages": [ { ... } ],
///   "folders": [ { ... } ],
///   "trackables": [ { ... } ],
///   "interventions": [ { ... } ],
///   "situations": [ { ... } ]
/// }
/// Only the arrays present will be processed.
struct DataImporter {
    // MARK: - Codable DTOs
    struct PageDTO: Codable {
        var id: String?
        var title: String
        var bodyMarkdown: String?
        var encodedTextBase64: String?
        var folderId: String?
        var isSystem: Bool?
        var minSeverity: Int?
        var maxSeverity: Int?
        var priority: Int?
        var isEveryDay: Bool?
        var order: Int?
        var trackableId: String?
    }

    struct FolderDTO: Codable {
        var id: String?
        var name: String
    }

    struct TrackableDTO: Codable {
        var id: String?
        var name: String
        var colorName: String?
        var order: Int?
    }

    struct InterventionDTO: Codable {
        var id: String?
        var pageId: String?
        var title: String
        var detailsMarkdown: String?
        var encodedTextBase64: String?
        var trackableId: String?
        var minSeverity: Int?
        var maxSeverity: Int?
        var priority: Int?
        var isEveryDay: Bool?
        var colorName: String?
    }

    struct SituationDTO: Codable {
        var id: String?
        var title: String
        var iconSystemName: String?
        var colorName: String?
        var pageIds: [String]?
    }

    // New DTOs for Roadmap and RoadmapNode
    struct RoadmapDTO: Codable {
        var id: String?
        var name: String
        var createdAt: Date?
    }

    struct RoadmapNodeDTO: Codable {
        var id: String?
        var roadmapId: String?
        var title: String
        var bodyMarkdown: String?
        var colorName: String?
        var pageIds: [String]?
        var interventionIds: [String]?
        var x: Double?
        var y: Double?
        var parentId: String?
    }

    struct BundleDTO: Codable {
        var pages: [PageDTO]? = nil
        var folders: [FolderDTO]? = nil
        var trackables: [TrackableDTO]? = nil
        var interventions: [InterventionDTO]? = nil
        var situations: [SituationDTO]? = nil
        var roadmaps: [RoadmapDTO]? = nil
        var roadmapNodes: [RoadmapNodeDTO]? = nil
    }

    // MARK: - Public API
    static func `import`(data: Data, into context: ModelContext) throws {
        let bundle = try JSONDecoder().decode(BundleDTO.self, from: data)
        try context.transaction {
            try `import`(bundle: bundle, into: context)
        }
    }

    // MARK: - Export
    static func export(from context: ModelContext) throws -> Data {
        // Fetch all objects
        let pages = (try? context.fetch(FetchDescriptor<NotePage>())) ?? []
        let folders = (try? context.fetch(FetchDescriptor<Folder>())) ?? []
        let trackables = (try? context.fetch(FetchDescriptor<Trackable>())) ?? []
        let interventions = (try? context.fetch(FetchDescriptor<Intervention>())) ?? []
        let situations = (try? context.fetch(FetchDescriptor<Situation>())) ?? []
        let roadmaps = (try? context.fetch(FetchDescriptor<Roadmap>())) ?? []
        let roadmapNodes = (try? context.fetch(FetchDescriptor<RoadmapNode>())) ?? []

        let bundle = BundleDTO(
            pages: pages.map { p in
                PageDTO(
                    id: p.id,
                    title: p.title,
                    bodyMarkdown: p.bodyMarkdown,
                    encodedTextBase64: p.encodedText?.base64EncodedString(),
                    folderId: p.folderId,
                    isSystem: p.isSystem,
                    minSeverity: p.minSeverity,
                    maxSeverity: p.maxSeverity,
                    priority: p.priority,
                    isEveryDay: p.isEveryDay,
                    order: p.order,
                    trackableId: p.trackableId)
            },
            folders: folders.map { f in
                FolderDTO(id: f.id, name: f.name)
            },
            trackables: trackables.map { t in
                TrackableDTO(id: t.id, name: t.name, colorName: t.colorName, order: t.order)
            },
            interventions: interventions.map { iv in
                InterventionDTO(
                    id: iv.id,
                    pageId: iv.pageId,
                    title: iv.title,
                    detailsMarkdown: iv.detailsMarkdown,
                    encodedTextBase64: iv.encodedText?.base64EncodedString(),
                    trackableId: iv.trackableId,
                    minSeverity: iv.minSeverity,
                    maxSeverity: iv.maxSeverity,
                    priority: iv.priority,
                    isEveryDay: iv.isEveryDay,
                    colorName: iv.colorName)
            },
            situations: situations.map { s in
                SituationDTO(id: s.id, title: s.title, iconSystemName: s.iconSystemName, colorName: s.colorName, pageIds: s.pageIds)
            },
            roadmaps: roadmaps.map { r in
                RoadmapDTO(id: r.id, name: r.name, createdAt: r.createdAt)
            },
            roadmapNodes: roadmapNodes.map { n in
                RoadmapNodeDTO(
                    id: n.id,
                    roadmapId: n.roadmap?.id,
                    title: n.title,
                    bodyMarkdown: n.bodyMarkdown,
                    colorName: n.colorName,
                    pageIds: n.pageIds,
                    interventionIds: n.interventionIds,
                    x: n.x,
                    y: n.y,
                    parentId: n.parentId)
            })

        let data = try JSONEncoder().encode(bundle)
        return data
    }

    // MARK: - Internals
    private static func `import`(bundle: BundleDTO, into context: ModelContext) throws {
        if let folders = bundle.folders {
            for dto in folders {
                let id = dto.id ?? UUID().uuidString
                let folder: Folder = context.findOrCreate(id: id) {
                    Folder(name: dto.name)
                }
                folder.name = dto.name
            }
        }

        if let pages = bundle.pages {
            for dto in pages {
                let id = dto.id ?? UUID().uuidString
                let page: NotePage = context.findOrCreate(id: id) {
                    NotePage(id: id, title: dto.title)
                }
                page.title = dto.title
                page.bodyMarkdown = dto.bodyMarkdown ?? ""
                page.folderId = dto.folderId
                page.isSystem = dto.isSystem ?? false
                page.minSeverity = dto.minSeverity ?? 0
                page.maxSeverity = dto.maxSeverity ?? 10
                page.priority = dto.priority ?? 0
                page.isEveryDay = dto.isEveryDay ?? false
                page.order = dto.order ?? 0
                page.trackableId = dto.trackableId
                if let b64 = dto.encodedTextBase64, let data = Data(base64Encoded: b64) {
                    page.encodedText = data
                }
            }
        }

        if let trackables = bundle.trackables {
            for dto in trackables {
                let id = dto.id ?? UUID().uuidString
                let t: Trackable = context.findOrCreate(id: id) {
                    Trackable(name: dto.name)
                }
                t.name = dto.name
                t.colorName = dto.colorName ?? "blue"
                t.order = dto.order ?? 0
            }
        }

        if let interventions = bundle.interventions {
            for dto in interventions {
                let id = dto.id ?? UUID().uuidString
                let iv: Intervention = context.findOrCreate(id: id) {
                    if let page = dto.pageId { return Intervention(pageId: page, title: dto.title) }
                    else { return Intervention(title: dto.title) }
                }
                iv.pageId = dto.pageId ?? ""
                iv.title = dto.title
                iv.detailsMarkdown = dto.detailsMarkdown ?? ""
                iv.trackableId = dto.trackableId
                iv.minSeverity = dto.minSeverity ?? 0
                iv.maxSeverity = dto.maxSeverity ?? 10
                iv.priority = dto.priority ?? 0
                iv.isEveryDay = dto.isEveryDay ?? false
                iv.colorName = dto.colorName
                if let b64 = dto.encodedTextBase64, let data = Data(base64Encoded: b64) {
                    iv.encodedText = data
                }
            }
        }

        if let situations = bundle.situations {
            for dto in situations {
                let id = dto.id ?? UUID().uuidString
                let s: Situation = context.findOrCreate(id: id) {
                    Situation(title: dto.title)
                }
                s.title = dto.title
                s.iconSystemName = dto.iconSystemName ?? "square"
                s.colorName = dto.colorName ?? "blue"
                s.pageIds = dto.pageIds ?? []
            }
        }

        // Import Roadmaps before nodes so nodes can link to them
        if let roadmaps = bundle.roadmaps {
            for dto in roadmaps {
                let id = dto.id ?? UUID().uuidString
                let r: Roadmap = context.findOrCreate(id: id) {
                    Roadmap(name: dto.name)
                }
                r.name = dto.name
                if let createdAt = dto.createdAt { r.createdAt = createdAt }
            }
        }

        if let nodes = bundle.roadmapNodes {
            for dto in nodes {
                let id = dto.id ?? UUID().uuidString
                let n: RoadmapNode = context.findOrCreate(id: id) {
                    RoadmapNode(title: dto.title)
                }
                n.title = dto.title
                n.bodyMarkdown = dto.bodyMarkdown ?? ""
                n.colorName = dto.colorName ?? "yellow"
                n.pageIds = dto.pageIds ?? []
                n.interventionIds = dto.interventionIds ?? []
                n.x = dto.x ?? 0
                n.y = dto.y ?? 0
                n.parentId = dto.parentId

                if let roadmapId = dto.roadmapId {
                    let roadmap: Roadmap = context.findOrCreate(id: roadmapId) {
                        Roadmap(name: "")
                    }
                    n.roadmap = roadmap
                }
            }
        }
    }
}
