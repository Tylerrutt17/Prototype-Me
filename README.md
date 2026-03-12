# Daily Check-In (PrototypeMe)

A **local-first** iOS application that helps you reflect on how you’re feeling each day and instantly surfaces the most relevant coping strategies and notes you’ve written for yourself.

---

## ✨ Elevator Pitch

1. **Rate how you feel** on a handful of sliders (e.g. *Anxiety*, *Brain Fog*).
2. Tap **Generate Curated Note** and the app assembles a tailor-made list of interventions from your personal knowledge base—mixing always-helpful tips with items that match today’s severity levels.
3. Browse & edit all of your topics and free-form notes at any time. A "Situations" carousel offers quick entry points like *Giving a presentation* or *Before bed*.
4. Everything is stored **100 % on-device** with SwiftData—no accounts, no cloud, complete privacy.

---

## 🎯 Core Goals

* Friction-free daily check-in → curated recommendations.
* Rich-text notes with lightweight Markdown (**bold, italics, lists, color spans**).
* Severity-gated and "Every day" interventions.
* Per-day history with auto-reset at midnight.
* Quick context search via Situations.
* Offline-only; data never leaves the device.

---

## 🗄️ Domain Model (SwiftData)

| Entity | Purpose |
| ------ | ------- |
| `Trackable` | Slider on Home (e.g. Anxiety) with 0-10 range & color. |
| `NotePage` | Editable note (topic or free note) that can link to a `Trackable`. Holds many `Intervention`s. |
| `Intervention` | A single actionable item inside a note; carries severity range, priority & flags like *Every day*. |
| `Situation` | Quick-access bubble (*Driving*, *Before bed*) that links to notes. |
| `DailyCuratedNote` | Saved record of each day’s generated list (stores IDs, not copies). |
| `Folder` | Nested hierarchy for organizing notes. |
| `Roadmap` / `RoadmapNode` | Optional mind-map style planning feature. |
| `DayLog` | Simple daily journal entry with rating & tags. |

---

## 🏗️ Architecture & Tech

* **SwiftUI** UI, **Swift 5.9**, **iOS 17+** (SDK 26).
* **SwiftData** (Schema V1) for persistence.
* Minimal dependencies—Markdown rendering handled by either **MarkdownUI** or a custom parser.
* Logic lives in `Core/Logic` (e.g. **CurationEngine**, **ColorSpanParser**).
* UI grouped by feature area under `UI/` (Home, Curated, Notes, Situations, History, Common components).

Project entry-point:

```swift
@main
struct MeApp: App {
    // Loads SwiftData container, seeds data, shows AppShell
}
```

---

## 🤖 Curation Algorithm (High-Level)

1. Always include interventions flagged **Every day**.
2. If **all slider values ≤ 3** → include each topic’s *basic* items (`maxSeverity ≤ 3`).
3. Otherwise:
   * Find the highest slider (the *primary* trackable) and include **all** items whose severity range contains its value.
   * For all other sliders, still include their basic items.
4. Sort by *(Every day desc, priority desc, title asc)* and store the resulting IDs in `DailyCuratedNote` for today.

---

## 📐 UI Overview

* **Home** – sliders, Generate button, curated preview, Situations carousel.
* **Curated Note** – ordered list for today, editable live.
* **Topics & Free Notes** – browse & edit pages; interventions are created inside topics.
* **Situations** – search & bubble list leading to connected notes.
* **History** – open any prior day’s curated set.
* **Settings** – theme preview, data import/export, security lock.

Navigation uses `NavigationSplitView` on iPad / landscape and `NavigationStack` on phones, with a reusable `AppShell` sidebar.

---

## 📁 Repository Layout (excerpt)

```
apps/iOSApp/Me/
  ├─ Core/
  │   ├─ Models/           # SwiftData entities
  │   ├─ Persistence/      # SeedData, migrations
  │   └─ Logic/            # CurationEngine, utilities
  ├─ UI/
  │   ├─ Home/
  │   ├─ Curated/
  │   ├─ Notes/
  │   ├─ Situations/
  │   ├─ History/
  │   └─ Common/
  ├─ Assets.xcassets/
  └─ MeApp.swift
```

---

## 🚀 Getting Started

1. Open `apps/iOSApp/Me/Me.xcodeproj` in Xcode 15+.
2. Build & run on iOS 17+ simulator or device.
3. On first launch the app seeds example Trackables, Topics, Interventions & Situations so you can explore immediately.

---

## 🔒 Privacy by Design

* All content is stored locally using SwiftData.
* iCloud sync is **disabled** by default—no data leaves your device.
* Optional app-lock on foreground via `LockManager`.

---

## 📜 License

```
MIT License – see LICENSE file for details.
```
# Prototype-Me
# Prototype-Me
