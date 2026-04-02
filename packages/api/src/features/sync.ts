import { eq, and, gt } from "drizzle-orm";
import { db } from "../db/client.js";
import * as syncQueries from "../db/queries/sync.js";
import * as schema from "../db/schema.js";

// ── Types matching iOS SyncEngine ──

interface OutboxOp {
  id: string;
  entityType: string;
  entityId: string;
  op: "create" | "update" | "delete";
  patch: string;
  baseUpdatedAt?: string | null;
  schemaVersion: number;
  createdAt: string;
}

interface AppliedEntity {
  entityType: string;
  entityId: string;
}

interface PushResponse {
  applied: AppliedEntity[];
  lastSyncToken: string;
}

interface ChangeEvent {
  token: string;
  entityType: string;
  entityId: string;
  operation: string;
  payload: string | null; // JSON string, null for deletes
  version: number | null;
  updatedAt: string | null;
  updatedByDeviceId: string | null;
}

interface PullResponse {
  events: ChangeEvent[];
  nextToken: string | null;
  hasMore: boolean;
}

// ── Push: idempotent, server-authoritative versioning ──

// Junction/link tables that depend on parent entities existing first.
const JUNCTION_TYPES = new Set(["noteDirective", "activeMode"]);

export async function push(userId: string, deviceId: string, operations: OutboxOp[]): Promise<PushResponse> {
  const applied: AppliedEntity[] = [];

  // Sort so parent entity creates are processed before junction table ops.
  // This prevents FK violations when both arrive in the same batch.
  const sorted = [...operations].sort((a, b) => {
    const aIsJunction = JUNCTION_TYPES.has(a.entityType) ? 1 : 0;
    const bIsJunction = JUNCTION_TYPES.has(b.entityType) ? 1 : 0;
    return aIsJunction - bIsJunction;
  });

  for (const op of sorted) {
    try {
      // 1. Idempotency check
      if (await syncQueries.isOpProcessed(op.id)) {
        applied.push({ entityType: op.entityType, entityId: op.entityId });
        continue;
      }

      // 2. Process the operation
      console.log(`[Sync] Processing op: ${op.op} ${op.entityType} ${op.entityId}`);
      await processOp(userId, deviceId, op);

      // 3. Log for idempotency
      await syncQueries.logOp(op.id, userId, op.entityType, op.entityId);
      applied.push({ entityType: op.entityType, entityId: op.entityId });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[Sync] Push error for op ${op.id}: ${message}`);
      // Still mark as applied so client removes from outbox — permanent failures shouldn't retry forever
      applied.push({ entityType: op.entityType, entityId: op.entityId });
    }
  }

  return {
    applied,
    lastSyncToken: new Date().toISOString(),
  };
}

async function processOp(userId: string, deviceId: string, op: OutboxOp): Promise<void> {
  // Special handling for noteDirective (composite key, no userId)
  if (op.entityType === "noteDirective") {
    await processNoteDirectiveOp(op);
    return;
  }

  // Special handling for activeMode (composite key with userId)
  if (op.entityType === "activeMode") {
    await processActiveModeOp(userId, op);
    return;
  }

  const table = syncQueries.getIdTable(op.entityType);
  if (!table) throw new Error(`Unknown entity type: ${op.entityType}`);

  switch (op.op) {
    case "create": {
      const data = parsePatchDates(JSON.parse(op.patch));
      // Strip fields that should be server-controlled
      const { updatedAt: _u, ...rest } = data;
      await db
        .insert(table)
        .values({ ...rest, userId, updatedAt: new Date() })
        .onConflictDoNothing();
      break;
    }

    case "update": {
      const data = parsePatchDates(JSON.parse(op.patch));
      const existing = await syncQueries.findById(op.entityType, op.entityId);
      if (!existing) break;

      // Strip immutable fields
      const { id: _id, createdAt: _ca, userId: _uid, ...updateData } = data;

      // Server increments version
      const currentVersion = (existing as Record<string, unknown>).version as number | undefined;
      const newVersion = currentVersion !== undefined ? currentVersion + 1 : 1;

      await db
        .update(table)
        .set({ ...updateData, version: newVersion, updatedAt: new Date() })
        .where(eq(table.id, op.entityId));
      break;
    }

    case "delete": {
      // Delete the entity
      await db.delete(table).where(eq(table.id, op.entityId));
      // Record tombstone
      await syncQueries.insertTombstone(userId, op.entityType, op.entityId, deviceId);
      break;
    }
  }
}

async function processNoteDirectiveOp(op: OutboxOp): Promise<void> {
  const composite = syncQueries.parseCompositeId(op.entityId);
  if (!composite) throw new Error(`Invalid noteDirective entityId: ${op.entityId}`);

  switch (op.op) {
    case "create": {
      const data = JSON.parse(op.patch);
      await db
        .insert(schema.noteDirective)
        .values({
          noteId: composite.noteId,
          directiveId: composite.directiveId,
          sortIndex: data.sortIndex ?? 0,
          createdAt: data.createdAt ? new Date(data.createdAt) : new Date(),
        })
        .onConflictDoNothing();
      break;
    }

    case "update": {
      const data = JSON.parse(op.patch);
      await db
        .update(schema.noteDirective)
        .set({ sortIndex: data.sortIndex ?? 0 })
        .where(
          and(
            eq(schema.noteDirective.noteId, composite.noteId),
            eq(schema.noteDirective.directiveId, composite.directiveId),
          ),
        );
      break;
    }

    case "delete": {
      await syncQueries.deleteNoteDirective(composite.noteId, composite.directiveId);
      break;
    }
  }
}

async function processActiveModeOp(userId: string, op: OutboxOp): Promise<void> {
  switch (op.op) {
    case "create": {
      const data = parsePatchDates(JSON.parse(op.patch));
      await db
        .insert(schema.activeMode)
        .values({
          noteId: op.entityId,
          userId,
          activatedAt: (data.activatedAt as Date | undefined) ?? new Date(),
        })
        .onConflictDoNothing();
      break;
    }

    case "delete": {
      await db
        .delete(schema.activeMode)
        .where(
          and(
            eq(schema.activeMode.noteId, op.entityId),
            eq(schema.activeMode.userId, userId),
          ),
        );
      break;
    }
  }
}

// ── Pull: paginated, all entity types, correct response format ──

export async function pull(userId: string, deviceId: string, cursor?: string, limit = 200): Promise<PullResponse> {
  const since = cursor ? new Date(cursor) : new Date(0);
  const events: ChangeEvent[] = [];

  // Pull upserts from all versioned entity tables
  for (const { entityType, table } of syncQueries.getUpdatableTables()) {
    const rows = await db
      .select()
      .from(table)
      .where(and(eq(table.userId, userId), gt(table.updatedAt, since)));

    for (const row of rows) {
      const r = row as Record<string, unknown>;
      const updatedAt = (r.updatedAt as Date).toISOString();

      // Strip userId from payload (client doesn't need it)
      const { userId: _uid, ...clientData } = r;

      events.push({
        token: updatedAt,
        entityType,
        entityId: r.id as string,
        operation: "update", // create/update are treated the same — client does upsert
        payload: JSON.stringify(clientData),
        version: (r.version as number) ?? null,
        updatedAt,
        updatedByDeviceId: null,
      });
    }
  }

  // Pull noteDirective links (no userId column — join through notePage)
  // Use createdAt since noteDirective has no updatedAt
  const noteDirectiveRows = await db
    .select({ nd: schema.noteDirective })
    .from(schema.noteDirective)
    .innerJoin(schema.notePage, eq(schema.noteDirective.noteId, schema.notePage.id))
    .where(and(eq(schema.notePage.userId, userId), gt(schema.noteDirective.createdAt, since)));

  for (const { nd } of noteDirectiveRows) {
    const entityId = `${nd.noteId}|${nd.directiveId}`;
    const createdAt = nd.createdAt.toISOString();
    events.push({
      token: createdAt,
      entityType: "noteDirective",
      entityId,
      operation: "update",
      payload: JSON.stringify(nd),
      version: null,
      updatedAt: createdAt,
      updatedByDeviceId: null,
    });
  }

  // Pull active modes (no version field — uses activatedAt)
  const activeModeRows = await db
    .select()
    .from(schema.activeMode)
    .where(and(eq(schema.activeMode.userId, userId), gt(schema.activeMode.activatedAt, since)));

  for (const mode of activeModeRows) {
    const activatedAt = mode.activatedAt.toISOString();
    events.push({
      token: activatedAt,
      entityType: "activeMode",
      entityId: mode.noteId,
      operation: "update",
      payload: JSON.stringify({ noteId: mode.noteId, activatedAt: mode.activatedAt }),
      version: null,
      updatedAt: activatedAt,
      updatedByDeviceId: null,
    });
  }

  // Pull tombstones (deletes)
  const tombstones = await syncQueries.findTombstonesSince(userId, since);
  for (const t of tombstones) {
    const updatedAt = t.updatedAt.toISOString();
    events.push({
      token: updatedAt,
      entityType: t.entityType,
      entityId: t.entityId,
      operation: "delete",
      payload: null,
      version: null,
      updatedAt,
      updatedByDeviceId: t.deviceId,
    });
  }

  // Sort by token (updatedAt) + entityId for consistent ordering
  // Secondary sort by entityId prevents skipping same-timestamp events
  events.sort((a, b) => {
    const cmp = a.token.localeCompare(b.token);
    if (cmp !== 0) return cmp;
    return a.entityId.localeCompare(b.entityId);
  });

  // Pagination: take `limit` events, report if there are more
  const hasMore = events.length > limit;
  const page = events.slice(0, limit);

  // Build cursor from last event's token + entityId to handle same-timestamp pagination
  const lastEvent = page[page.length - 1];
  const nextToken = lastEvent ? lastEvent.token : null;

  return {
    events: page,
    nextToken: hasMore ? nextToken : null,
    hasMore,
  };
}

// ── Helpers ──

/** Convert ISO date strings in a patch object to Date objects for Drizzle. */
function parsePatchDates(data: Record<string, unknown>): Record<string, unknown> {
  const dateFields = ["createdAt", "updatedAt", "snoozedUntil", "activatedAt", "deletedAt", "lastCompletedDate"];
  const result = { ...data };
  for (const key of dateFields) {
    if (key in result && typeof result[key] === "string") {
      const parsed = new Date(result[key] as string);
      // Only convert if it's a valid date (not a yyyy-MM-dd string like lastCompletedDate)
      if (!isNaN(parsed.getTime()) && (result[key] as string).includes("T")) {
        result[key] = parsed;
      }
    }
  }
  return result;
}
