//
//  MeApp.swift
//  Me
//
//  Created by Tyler Rutt on 11/2/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct MeApp: App {
    // Shared SwiftData container for the app
    private let container: ModelContainer
    private let notificationDelegate: NotificationCenterDelegate
    @StateObject private var lockManager = LockManager()
    @StateObject private var deepLinkRouter: DeepLinkRouter
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("lockOnForeground") private var lockOnForeground: Bool = true
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled: Bool = false
    @AppStorage("dailyReminderTime") private var dailyReminderTime: Double = 9 * 3600
    @State private var hasLaunched = false

    init() {
        // Configure a CloudKit-backed store that lives in the user’s private database
        // let config = ModelConfiguration("Default", cloudKitDatabase: .private("iCloud.com.prototypemeapp"))
        let config = ModelConfiguration("Default")        // local SwiftData store, no CloudKit

        // Register all models in the schema (Schema V1) and expose load errors
        let builtContainer: ModelContainer
        do {
            builtContainer = try ModelContainer(for: Trackable.self,
                                               Folder.self,
                                               NotePage.self,
                                               Intervention.self,
                                               Situation.self,
                                               DailyCuratedNote.self,
                                               Roadmap.self,
                                               RoadmapNode.self,
                                               DayLog.self,
                                               Tag.self,
                                               DayLogTag.self,
                                               AudioAttachment.self,
                                               configurations: config)
        } catch {
            print("⚠️ SwiftData failed to load: \(error)")
            fatalError("ModelContainer failed to load—see above error for details")
        }

        container = builtContainer

        // Deep links + notification handling
        let router = DeepLinkRouter()
        _deepLinkRouter = StateObject(wrappedValue: router)
        notificationDelegate = NotificationCenterDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Coordinate CloudKit merge, dedupe, and seeding in one place.
        Bootstrap.start(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppShell()
                    .modelContainer(container)
                    .preferredColorScheme(.dark)
                    .environmentObject(deepLinkRouter)
                if lockManager.isLocked {
                    LockScreen()
                        .transition(.opacity)
                }
            }
            .environmentObject(lockManager)
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    if !hasLaunched {
                        hasLaunched = true
                        if lockManager.lockEnabledPublic { lockManager.requireUnlock() }
                    } else if lockOnForeground {
                        lockManager.requireUnlock()
                    }
                    Task {
                        await NotificationScheduler.refreshDailyReminder(enabled: dailyReminderEnabled,
                                                                        time: reminderDate)
                    }
                case .background:
                    break
                default:
                    break
                }
            }
        }
    }

    private var reminderDate: Date {
        let midnight = Calendar.current.startOfDay(for: Date())
        let clamped = max(0, min(86340, dailyReminderTime))
        return midnight.addingTimeInterval(clamped)
    }
}
