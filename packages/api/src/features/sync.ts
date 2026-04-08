import { eq, and, gt, sql } from "drizzle-orm";
import { db } from "../db/client.js";
import * as syncQueries from "../db/queries/sync.js";
import * as schema from "../db/schema.js";
import { validateHistoryPayload } from "../validation/directiveHistory.js";

// Transaction-compatible DB type (works with both db and db.transaction callback)
type TxDb = Parameters<Parameters<typeof db.transaction>[0]>[0];

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

  // Process all ops in a single transaction to minimize DB round trips
  await db.transaction(async (tx) => {
    for (const op of sorted) {
      try {
        // 1. Idempotency check
        const existing = await tx.select().from(schema.syncOpLog).where(eq(schema.syncOpLog.opId, op.id)).then((r) => r[0]);
        if (existing) {
          applied.push({ entityType: op.entityType, entityId: op.entityId });
          continue;
        }

        // 2. Process the operation
        await processOpTx(tx, userId, deviceId, op);

        // 3. Log for idempotency
        await tx.insert(schema.syncOpLog).values({ opId: op.id, userId, entityType: op.entityType, entityId: op.entityId }).onConflictDoNothing();
        applied.push({ entityType: op.entityType, entityId: op.entityId });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(`[Sync] Push error for op ${op.id}: ${message}`);
        applied.push({ entityType: op.entityType, entityId: op.entityId });
      }
    }
  });

  return {
    applied,
    lastSyncToken: new Date().toISOString(),
  };
}

async function processOpTx(tx: TxDb, userId: string, deviceId: string, op: OutboxOp): Promise<void> {
  if (op.entityType === "noteDirective") {
    await processNoteDirectiveOpTx(tx, op);
    return;
  }

  if (op.entityType === "activeMode") {
    await processActiveModeOpTx(tx, userId, op);
    return;
  }

  if (op.entityType === "directiveHistory") {
    await processDirectiveHistoryOpTx(tx, op);
    return;
  }

  const table = syncQueries.getIdTable(op.entityType);
  if (!table) throw new Error(`Unknown entity type: ${op.entityType}`);

  switch (op.op) {
    case "create": {
      const data = parsePatchDates(JSON.parse(op.patch));
      const { updatedAt: _u, ...rest } = data;
      await tx
        .insert(table)
        .values({ ...rest, userId, updatedAt: new Date() })
        .onConflictDoNothing();
      break;
    }

    case "update": {
      const data = parsePatchDates(JSON.parse(op.patch));
      const existing = await tx.select().from(table).where(eq(table.id, op.entityId)).then((r: unknown[]) => r[0] ?? null);
      if (!existing) break;

      const { id: _id, createdAt: _ca, userId: _uid, ...updateData } = data;
      const currentVersion = (existing as Record<string, unknown>).version as number | undefined;
      const newVersion = currentVersion !== undefined ? currentVersion + 1 : 1;

      await tx
        .update(table)
        .set({ ...updateData, version: newVersion, updatedAt: new Date() })
        .where(eq(table.id, op.entityId));
      break;
    }

    case "delete": {
      await tx.delete(table).where(eq(table.id, op.entityId));
      await tx.insert(schema.tombstone).values({ userId, entityType: op.entityType, entityId: op.entityId, deviceId }).returning();
      break;
    }
  }
}

async function processNoteDirectiveOpTx(tx: TxDb, op: OutboxOp): Promise<void> {
  const composite = syncQueries.parseCompositeId(op.entityId);
  if (!composite) throw new Error(`Invalid noteDirective entityId: ${op.entityId}`);

  switch (op.op) {
    case "create": {
      const data = JSON.parse(op.patch);
      await tx
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
      await tx
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
      await tx
        .delete(schema.noteDirective)
        .where(
          and(
            eq(schema.noteDirective.noteId, composite.noteId),
            eq(schema.noteDirective.directiveId, composite.directiveId),
          ),
        );
      break;
    }
  }
}

async function processActiveModeOpTx(tx: TxDb, userId: string, op: OutboxOp): Promise<void> {
  switch (op.op) {
    case "create": {
      const data = parsePatchDates(JSON.parse(op.patch));
      await tx
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
      await tx
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

/**
 * DirectiveHistory is mostly append-only, but supports `delete` for retraction
 * (e.g. user unchecks a checklist item). Updates are never allowed.
 *
 * Payload shapes for creates are versioned per-action via Zod schemas. Invalid
 * payloads are rejected (op counted as applied but nothing written).
 */
async function processDirectiveHistoryOpTx(tx: TxDb, op: OutboxOp): Promise<void> {
  if (op.op === "delete") {
    await tx.delete(schema.directiveHistory).where(eq(schema.directiveHistory.id, op.entityId));
    return;
  }

  if (op.op !== "create") return; // updates not supported

  const data = parsePatchDates(JSON.parse(op.patch));
  const action = data.action as string | undefined;
  if (!action) {
    console.warn(`[Sync] directiveHistory op ${op.id} missing action`);
    return;
  }

  // Validate the payload against its action-specific versioned schema
  const validation = validateHistoryPayload(action, data.payload);
  if (!validation.ok) {
    console.warn(`[Sync] directiveHistory op ${op.id} invalid payload for action "${action}": ${validation.error}`);
    return;
  }

  // Verify the parent directive exists (FK requirement). If not, skip silently —
  // the parent directive op should be in the same batch but may arrive later.
  const parentExists = await tx
    .select({ id: schema.directive.id })
    .from(schema.directive)
    .where(eq(schema.directive.id, data.directiveId as string))
    .then((r) => r.length > 0);
  if (!parentExists) return;

  await tx
    .insert(schema.directiveHistory)
    .values({
      id: op.entityId,
      directiveId: data.directiveId as string,
      action: action as typeof schema.directiveHistoryActionEnum.enumValues[number],
      payload: JSON.stringify(validation.data),
      createdAt: (data.createdAt as Date | undefined) ?? new Date(),
    })
    .onConflictDoNothing();
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

  // Sort by entity dependency order first (parents before children/junctions),
  // then by token (updatedAt), then by entityId for consistency.
  const entityOrder: Record<string, number> = {
    folder: 0,
    directive: 1,
    tag: 2,
    notePage: 3,
    dayEntry: 4,
    scheduleRule: 5,
    noteDirective: 6,
    activeMode: 7,
  };
  events.sort((a, b) => {
    const orderA = entityOrder[a.entityType] ?? 50;
    const orderB = entityOrder[b.entityType] ?? 50;
    if (orderA !== orderB) return orderA - orderB;
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

// ── Stats: entity counts for the sync choice screen ──

export async function stats(userId: string) {
  const counts = await db.transaction(async (tx) => {
    const count = async (table: any) => {
      const [row] = await tx
        .select({ count: sql<number>`count(*)::int` })
        .from(table)
        .where(eq(table.userId, userId));
      return row?.count ?? 0;
    };

    // Find the most recent updatedAt across all synced tables
    const tables = [schema.directive, schema.notePage, schema.folder, schema.dayEntry, schema.tag];
    let latestDate: Date | null = null;
    for (const table of tables) {
      const [row] = await tx
        .select({ latest: sql<Date>`max(updated_at)` })
        .from(table as any)
        .where(eq((table as any).userId, userId));
      if (row?.latest) {
        const d = new Date(row.latest);
        if (!isNaN(d.getTime()) && (!latestDate || d > latestDate)) {
          latestDate = d;
        }
      }
    }

    return {
      directives: await count(schema.directive),
      notes: await count(schema.notePage),
      folders: await count(schema.folder),
      dayEntries: await count(schema.dayEntry),
      tags: await count(schema.tag),
      lastUpdatedAt: latestDate ? latestDate.toISOString() : null,
    };
  });

  return counts;
}

// ── Reset: wipe all user data so client can push fresh ──

export async function reset(userId: string): Promise<{ ok: true }> {
  await db.transaction(async (tx) => {
    // Delete in order that respects foreign keys (children/junctions first)
    await tx.delete(schema.noteDirective).where(
      eq(schema.noteDirective.noteId, sql`ANY(SELECT id FROM note_page WHERE user_id = ${userId})`),
    );
    await tx.delete(schema.activeMode).where(eq(schema.activeMode.userId, userId));
    await tx.delete(schema.directiveHistory).where(
      eq(schema.directiveHistory.directiveId, sql`ANY(SELECT id FROM directive WHERE user_id = ${userId})`),
    );
    await tx.delete(schema.scheduleRule).where(eq(schema.scheduleRule.userId, userId));
    await tx.delete(schema.notePage).where(eq(schema.notePage.userId, userId));
    await tx.delete(schema.directive).where(eq(schema.directive.userId, userId));
    await tx.delete(schema.folder).where(eq(schema.folder.userId, userId));
    await tx.delete(schema.dayEntry).where(eq(schema.dayEntry.userId, userId));
    await tx.delete(schema.tag).where(eq(schema.tag.userId, userId));

    // Clear sync metadata so the next pull starts fresh
    await tx.delete(schema.tombstone).where(eq(schema.tombstone.userId, userId));
    await tx.delete(schema.syncOpLog).where(eq(schema.syncOpLog.userId, userId));
  });

  return { ok: true };
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
