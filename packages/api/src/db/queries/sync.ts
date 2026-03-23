import { eq, and, gt } from "drizzle-orm";
import { db } from "../client.js";
import { tombstone } from "../schema.js";
import * as schema from "../schema.js";

// Map entity types to their tables for dynamic queries
const entityTables: Record<string, typeof schema.notePage | typeof schema.directive | typeof schema.folder | typeof schema.dayEntry | typeof schema.tag | typeof schema.scheduleRule | typeof schema.scheduleInstance> = {
  note_page: schema.notePage,
  directive: schema.directive,
  folder: schema.folder,
  day_entry: schema.dayEntry,
  tag: schema.tag,
  schedule_rule: schema.scheduleRule,
  schedule_instance: schema.scheduleInstance,
};

export function getEntityTable(entityType: string) {
  return entityTables[entityType];
}

export function findTombstonesSince(userId: string, since: Date) {
  return db
    .select()
    .from(tombstone)
    .where(and(eq(tombstone.userId, userId), gt(tombstone.updatedAt, since)));
}

export function insertTombstone(userId: string, entityType: string, entityId: string, deviceId: string) {
  return db.insert(tombstone).values({ userId, entityType, entityId, deviceId }).returning().then((r) => r[0]!);
}
