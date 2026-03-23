import {
  pgTable,
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

// ── Users (Cognito-backed) ──────────────────
export const users = pgTable("users", {
  id: uuid("id").primaryKey(), // Cognito sub
  email: text("email").notNull().unique(),
  displayName: text("display_name").notNull(),
  bio: text("bio"),
  avatarSystemImage: text("avatar_system_image").notNull().default("person.circle.fill"),
  moodChips: jsonb("mood_chips").$type<string[]>().notNull().default([]),
  plan: text("plan").notNull().default("free"), // free | pro
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
    kind: text("kind").notNull().default("regular"), // regular | mode | framework
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
    status: text("status").notNull().default("active"), // active | maintained | retired
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
    parentFolderId: text("parent_folder_id"), // self-referencing, nullable
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
    ruleType: text("rule_type").notNull(), // weekly | monthly | oneOff
    params: jsonb("params").$type<Record<string, number[]>>().notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
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
    status: text("status").notNull().default("pending"), // pending | done | skipped
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
    action: text("action").notNull(), // create | update | graduate | snooze | balloon_pump | shrink | split
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
    entityId: uuid("entity_id").notNull(),
    deletedAt: timestamp("deleted_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
    deviceId: text("device_id").notNull(),
  },
  (t) => [index("tombstone_user_updated_idx").on(t.userId, t.updatedAt)],
);

// ── Friendships ─────────────────────────────
export const friendship = pgTable(
  "friendship",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    requesterId: uuid("requester_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    addresseeId: uuid("addressee_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    status: text("status").notNull().default("pending"), // pending | accepted | declined
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex("friendship_pair_idx").on(t.requesterId, t.addresseeId),
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
