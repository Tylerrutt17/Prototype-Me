import {
  pgTable,
  pgEnum,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
  doublePrecision,
  jsonb,
  date,
  primaryKey,
  index,
  uniqueIndex,
} from "drizzle-orm/pg-core";

// ── Enums ───────────────────────────────────

export const subscriptionPlanEnum = pgEnum("subscription_plan", ["free", "pro"]);
export const noteKindEnum = pgEnum("note_kind", ["regular", "mode", "framework", "situation", "goal"]);
export const directiveStatusEnum = pgEnum("directive_status", ["active", "archived"]);
export const scheduleTypeEnum = pgEnum("schedule_type", ["weekly", "monthly", "oneOff"]);
export const instanceStatusEnum = pgEnum("instance_status", ["pending", "done", "skipped"]);
export const directiveHistoryActionEnum = pgEnum("directive_history_action", [
  "create", "update", "graduate", "snooze", "balloon_pump", "shrink", "split", "checklist_complete",
]);
export const friendshipStatusEnum = pgEnum("friendship_status", ["pending", "accepted", "declined"]);
export const syncOpEnum = pgEnum("sync_op_type", ["create", "update", "delete"]);

// ── Users ───────────────────────────────────
export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  appleId: text("apple_id").unique(),
  email: text("email").notNull().default(""),
  displayName: text("display_name").notNull(),
  bio: text("bio"),
  avatarSystemImage: text("avatar_system_image").notNull().default("person.circle.fill"),
  moodChips: jsonb("mood_chips").$type<string[]>().notNull().default([]),
  plan: subscriptionPlanEnum("plan").notNull().default("free"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

// ── Notes ───────────────────────────────────
export const notePage = pgTable(
  "note_page",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    body: text("body").notNull().default(""),
    kind: noteKindEnum("kind").notNull().default("regular"),
    folderId: uuid("folder_id").references(() => folder.id, { onDelete: "set null" }),
    sortIndex: integer("sort_index").notNull().default(0),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("note_page_user_idx").on(t.userId)],
);

// ── Directives ──────────────────────────────
export const directive = pgTable(
  "directive",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    body: text("body"),
    status: directiveStatusEnum("status").notNull().default("active"),
    balloonEnabled: boolean("balloon_enabled").notNull().default(false),
    balloonDurationSec: doublePrecision("balloon_duration_sec").notNull().default(0),
    balloonSnapshotSec: doublePrecision("balloon_snapshot_sec").notNull().default(0),
    snoozedUntil: timestamp("snoozed_until", { withTimezone: true }),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("directive_user_idx").on(t.userId)],
);

// ── Folders (Playbooks) ─────────────────────
export const folder = pgTable(
  "folder",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    parentFolderId: text("parent_folder_id"),
    sortIndex: integer("sort_index").notNull().default(0),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("folder_user_idx").on(t.userId)],
);

// ── Day Entries ─────────────────────────────
export const dayEntry = pgTable(
  "day_entry",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    date: date("date").notNull(),
    rating: integer("rating"),
    diary: text("diary").notNull().default(""),
    tags: jsonb("tags").$type<string[]>().notNull().default([]),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex("day_entry_user_date_idx").on(t.userId, t.date),
  ],
);

// ── Tags ────────────────────────────────────
export const tag = pgTable(
  "tag",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    color: text("color"),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [uniqueIndex("tag_user_name_idx").on(t.userId, t.name)],
);

// ── Schedule Rules ──────────────────────────
export const scheduleRule = pgTable(
  "schedule_rule",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    directiveId: uuid("directive_id").notNull().references(() => directive.id, { onDelete: "cascade" }),
    ruleType: scheduleTypeEnum("rule_type").notNull(),
    params: jsonb("params").$type<Record<string, number[]>>().notNull(),
    version: integer("version").notNull().default(1),
    lastCompletedDate: text("last_completed_date"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("schedule_rule_directive_idx").on(t.directiveId)],
);

// ── Schedule Instances ──────────────────────
export const scheduleInstance = pgTable(
  "schedule_instance",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    directiveId: uuid("directive_id").notNull().references(() => directive.id, { onDelete: "cascade" }),
    date: date("date").notNull(),
    status: instanceStatusEnum("status").notNull().default("pending"),
  },
  (t) => [
    index("schedule_instance_user_date_idx").on(t.userId, t.date),
  ],
);

// ── Active Modes ────────────────────────────
export const activeMode = pgTable(
  "active_mode",
  {
    noteId: uuid("note_id").notNull().references(() => notePage.id, { onDelete: "cascade" }),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    activatedAt: timestamp("activated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.noteId, t.userId] })],
);

// ── Directive History ───────────────────────
export const directiveHistory = pgTable(
  "directive_history",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    directiveId: uuid("directive_id").notNull().references(() => directive.id, { onDelete: "cascade" }),
    action: directiveHistoryActionEnum("action").notNull(),
    payload: text("payload").notNull().default("{}"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("directive_history_directive_idx").on(t.directiveId)],
);

// ── Join: Note ↔ Directive ──────────────────
export const noteDirective = pgTable(
  "note_directive",
  {
    noteId: uuid("note_id").notNull().references(() => notePage.id, { onDelete: "cascade" }),
    directiveId: uuid("directive_id").notNull().references(() => directive.id, { onDelete: "cascade" }),
    sortIndex: integer("sort_index").notNull().default(0),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.noteId, t.directiveId] })],
);

// ── Devices ─────────────────────────────────
export const device = pgTable(
  "device",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    platform: text("platform").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("device_user_idx").on(t.userId)],
);

// ── Sync: Tombstones ────────────────────────
export const tombstone = pgTable(
  "tombstone",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    entityType: text("entity_type").notNull(),
    entityId: text("entity_id").notNull(),
    deletedAt: timestamp("deleted_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
    deviceId: text("device_id").notNull(),
  },
  (t) => [index("tombstone_user_updated_idx").on(t.userId, t.updatedAt)],
);

// ── Sync: Operation Log (idempotency) ───────
export const syncOpLog = pgTable(
  "sync_op_log",
  {
    opId: text("op_id").primaryKey(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    entityType: text("entity_type").notNull(),
    entityId: text("entity_id").notNull(),
    processedAt: timestamp("processed_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("sync_op_log_user_idx").on(t.userId)],
);

// ── Friendships ─────────────────────────────
export const friendship = pgTable(
  "friendship",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    requesterId: uuid("requester_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    addresseeId: uuid("addressee_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    status: friendshipStatusEnum("status").notNull().default("pending"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex("friendship_pair_idx").on(t.requesterId, t.addresseeId),
  ],
);

// ── Periodic Reviews ───────────────────────
export const reviewPeriodEnum = pgEnum("review_period", ["weekly", "monthly"]);

export const periodicReview = pgTable(
  "periodic_review",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    period: reviewPeriodEnum("period").notNull(),
    periodStart: date("period_start").notNull(),
    periodEnd: date("period_end").notNull(),

    // Structured insights (source of truth for UI)
    themes: jsonb("themes").$type<Array<{ name: string; mentions: number }>>().notNull().default([]),
    directiveWins: jsonb("directive_wins").$type<Array<{ directiveTitle: string; evidence: string }>>().notNull().default([]),
    directiveFocus: jsonb("directive_focus").$type<Array<{ directiveTitle: string; reason: string }>>().notNull().default([]),
    directiveGaps: jsonb("directive_gaps").$type<Array<{ theme: string; suggestedTitle: string }>>().notNull().default([]),
    // Pure schedule math (no LLM): directives the user scheduled but skipped.
    missedScheduled: jsonb("missed_scheduled").$type<Array<{ directiveTitle: string; missedCount: number; missedDates: string[] }>>().notNull().default([]),
    suggestion: text("suggestion"),

    // Context
    summary: text("summary").notNull(),
    bestDay: date("best_day"),
    bestDayNote: text("best_day_note"),
    lowestDay: date("lowest_day"),
    lowestDayNote: text("lowest_day_note"),
    avgRating: doublePrecision("avg_rating"),
    entryCount: integer("entry_count").notNull().default(0),

    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex("periodic_review_user_period_idx").on(t.userId, t.period, t.periodStart),
    index("periodic_review_user_idx").on(t.userId),
  ],
);

// ── AI Usage ────────────────────────────────
export const aiUsage = pgTable(
  "ai_usage",
  {
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    date: date("date").notNull(),
    count: integer("count").notNull().default(0),
  },
  (t) => [primaryKey({ columns: [t.userId, t.date] })],
);
