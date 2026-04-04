import UIKit
import GRDB

/// Dependency container for the app.
struct AppEnvironment {
    let db: DatabaseManager

    // Services
    let noteService: NoteService
    let directiveService: DirectiveService
    let folderService: FolderService
    let dayEntryService: DayEntryService
    let scheduleService: ScheduleService
    let modeService: ModeService
    let tagService: TagService
    let periodicReviewService: PeriodicReviewService

    // Networking + Sync
    let apiClient: APIClient
    let syncEngine: SyncEngine
    let reachability: ReachabilityMonitor

    // Auth
    let authService: AuthService

    // Purchases
    let purchaseService: PurchaseService

    // Notifications
    let balloonNotificationService: BalloonNotificationService

    /// Production environment backed by an on-disk SQLite database.
    static func live() throws -> AppEnvironment {
        let db = try DatabaseManager()
        return AppEnvironment(db: db)
    }

    /// In-memory environment for previews / tests.
    static func inMemory() throws -> AppEnvironment {
        let db = try DatabaseManager(inMemory: true)
        return AppEnvironment(db: db)
    }

    private init(db: DatabaseManager) {
        self.db = db

        // Services
        self.noteService = NoteService(db: db)
        self.directiveService = DirectiveService(db: db)
        self.folderService = FolderService(db: db)
        self.dayEntryService = DayEntryService(db: db)
        self.scheduleService = ScheduleService(db: db)
        self.modeService = ModeService(db: db)
        self.tagService = TagService(db: db)

        // Networking + Sync
        self.apiClient = APIClient()
        self.periodicReviewService = PeriodicReviewService(db: db, apiClient: apiClient)
        self.reachability = ReachabilityMonitor()
        self.syncEngine = SyncEngine(db: db, api: apiClient, reachability: reachability)

        // Auth
        self.authService = AuthService(apiClient: apiClient)

        // Purchases
        self.purchaseService = PurchaseService(apiClient: apiClient)
        self.purchaseService.configure()

        // Notifications
        self.balloonNotificationService = BalloonNotificationService()
    }
}
