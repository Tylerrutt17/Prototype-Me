import { eq, and, gt, sql } from "drizzle-orm";
import type { PgTable } from "drizzle-orm/pg-core";
import { db } from "../client.js";
import * as schema from "../schema.js";

// ── Entity type mapping: iOS camelCase ↔ Postgres snake_case tables ──

const entityTableMap: Record<string, PgTable> = {
  notePage: schema.notePage,
  directive: schema.directive,
  folder: schema.folder,
  dayEntry: schema.dayEntry,
  tag: schema.tag,
  noteDirective: schema.noteDirective,
  scheduleRule: schema.scheduleRule,
};

// Tables that have an `id` UUID primary key (for standard CRUD)
const idTables: Record<string, typeof schema.notePage | typeof schema.directive | typeof schema.folder | typeof schema.dayEntry | typeof schema.tag | typeof schema.scheduleRule> = {
  notePage: schema.notePage,
  directive: schema.directive,
  folder: schema.folder,
  dayEntry: schema.dayEntry,
  tag: schema.tag,
  scheduleRule: schema.scheduleRule,
};

// Tables that have a `version` field for LWW
const versionedTables = new Set(["notePage", "directive", "folder", "dayEntry", "tag", "scheduleRule"]);

// Tables that have `updatedAt` for pull cursor queries
const updatableTables: Array<{ entityType: string; table: typeof schema.notePage | typeof schema.directive | typeof schema.folder | typeof schema.dayEntry | typeof schema.tag | typeof schema.scheduleRule }> = [
  { entityType: "notePage", table: schema.notePage },
  { entityType: "directive", table: schema.directive },
  { entityType: "folder", table: schema.folder },
  { entityType: "dayEntry", table: schema.dayEntry },
  { entityType: "tag", table: schema.tag },
  { entityType: "scheduleRule", table: schema.scheduleRule },
];

export function getEntityTable(entityType: string) {
  return entityTableMap[entityType];
}

export function getIdTable(entityType: string) {
  return idTables[entityType];
}

export function hasVersion(entityType: string) {
  return versionedTables.has(entityType);
}

export function getUpdatableTables() {
  return updatableTables;
}

// ── Tombstones ──

export function findTombstonesSince(userId: string, since: Date) {
  return db
    .select()
    .from(schema.tombstone)
    .where(and(eq(schema.tombstone.userId, userId), gt(schema.tombstone.updatedAt, since)));
}

export function insertTombstone(userId: string, entityType: string, entityId: string, deviceId: string) {
  return db.insert(schema.tombstone).values({ userId, entityType, entityId, deviceId }).returning().then((r) => r[0]!);
}

// ── Idempotency: sync op log ──

export async function isOpProcessed(opId: string): Promise<boolean> {
  const row = await db.select().from(schema.syncOpLog).where(eq(schema.syncOpLog.opId, opId)).then((r) => r[0]);
  return !!row;
}

export function logOp(opId: string, userId: string, entityType: string, entityId: string) {
  return db.insert(schema.syncOpLog).values({ opId, userId, entityType, entityId }).onConflictDoNothing();
}

// ── NoteDirective helpers (composite key) ──

export function parseCompositeId(entityId: string): { noteId: string; directiveId: string } | null {
  const parts = entityId.split("|");
  if (parts.length !== 2) return null;
  return { noteId: parts[0]!, directiveId: parts[1]! };
}

export async function deleteNoteDirective(noteId: string, directiveId: string) {
  return db
    .delete(schema.noteDirective)
    .where(and(eq(schema.noteDirective.noteId, noteId), eq(schema.noteDirective.directiveId, directiveId)));
}

// ── Generic find by ID ──

export async function findById(entityType: string, entityId: string) {
  const table = getIdTable(entityType);
  if (!table) return null;
  return db.select().from(table).where(eq(table.id, entityId)).then((r) => r[0] ?? null);
}
