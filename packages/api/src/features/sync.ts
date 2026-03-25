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

export async function push(userId: string, deviceId: string, operations: OutboxOp[]): Promise<PushResponse> {
  const applied: AppliedEntity[] = [];

  for (const op of operations) {
    try {
      // 1. Idempotency check
      if (await syncQueries.isOpProcessed(op.id)) {
        applied.push({ entityType: op.entityType, entityId: op.entityId });
        continue;
      }

      // 2. Process the operation
      await processOp(userId, deviceId, op);

      // 3. Log for idempotency
      await syncQueries.logOp(op.id, userId, op.entityType, op.entityId);
      applied.push({ entityType: op.entityType, entityId: op.entityId });
    } catch (err) {
      // Log error but continue processing remaining ops
      console.error(`Sync push error for op ${op.id}:`, err);
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

  const table = syncQueries.getIdTable(op.entityType);
  if (!table) throw new Error(`Unknown entity type: ${op.entityType}`);

  switch (op.op) {
    case "create": {
      const data = JSON.parse(op.patch);
      // Strip fields that should be server-controlled
      const { updatedAt: _u, ...rest } = data;
      await db
        .insert(table)
        .values({ ...rest, userId, updatedAt: new Date() })
        .onConflictDoNothing();
      break;
    }

    case "update": {
      const data = JSON.parse(op.patch);
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

  // Sort by token (updatedAt) for consistent ordering
  events.sort((a, b) => a.token.localeCompare(b.token));

  // Pagination: take `limit` events, report if there are more
  const hasMore = events.length > limit;
  const page = events.slice(0, limit);
  const nextToken = page.length > 0 ? page[page.length - 1]!.token : null;

  return {
    events: page,
    nextToken: hasMore ? nextToken : null,
    hasMore,
  };
}
