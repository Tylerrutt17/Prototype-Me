import { eq, and, gt } from "drizzle-orm";
import { db } from "../db/client.js";
import * as syncQueries from "../db/queries/sync.js";
import * as schema from "../db/schema.js";

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

interface PushResult {
  operationId: string;
  status: "ok" | "conflict" | "error";
  error?: string;
  serverVersion?: number;
}

export async function push(userId: string, deviceId: string, operations: OutboxOp[]) {
  const results: PushResult[] = [];

  for (const op of operations) {
    try {
      const result = await processOp(userId, deviceId, op);
      results.push(result);
    } catch (err) {
      results.push({
        operationId: op.id,
        status: "error",
        error: err instanceof Error ? err.message : "Unknown error",
      });
    }
  }

  return { results };
}

async function processOp(userId: string, deviceId: string, op: OutboxOp): Promise<PushResult> {
  const table = syncQueries.getEntityTable(op.entityType);
  if (!table) {
    return { operationId: op.id, status: "error", error: `Unknown entity type: ${op.entityType}` };
  }

  const data = JSON.parse(op.patch);

  switch (op.op) {
    case "create": {
      await db.insert(table).values({ ...data, userId });
      return { operationId: op.id, status: "ok" };
    }
    case "update": {
      // Check version for conflict detection
      const existing = await db.select().from(table).where(eq((table as typeof schema.notePage).id, op.entityId)).then((r) => r[0]);
      if (!existing) return { operationId: op.id, status: "error", error: "Entity not found" };

      const existingVersion = (existing as Record<string, unknown>).version as number | undefined;
      if (existingVersion !== undefined && op.baseUpdatedAt) {
        const existingUpdatedAt = (existing as Record<string, unknown>).updatedAt;
        if (existingUpdatedAt && new Date(existingUpdatedAt as string) > new Date(op.baseUpdatedAt)) {
          return { operationId: op.id, status: "conflict", serverVersion: existingVersion };
        }
      }

      await db
        .update(table)
        .set({ ...data, updatedAt: new Date() })
        .where(eq((table as typeof schema.notePage).id, op.entityId));
      return { operationId: op.id, status: "ok" };
    }
    case "delete": {
      await db.delete(table).where(eq((table as typeof schema.notePage).id, op.entityId));
      await syncQueries.insertTombstone(userId, op.entityType, op.entityId, deviceId);
      return { operationId: op.id, status: "ok" };
    }
  }
}

export async function pull(userId: string, _deviceId: string, cursor?: string | null) {
  const since = cursor ? new Date(cursor) : new Date(0);
  const now = new Date();
  const changes: Array<{ entityType: string; entityId: string; op: string; data: unknown; updatedAt: string }> = [];

  // Pull changes from each entity table
  const tables = [
    { name: "note_page", table: schema.notePage },
    { name: "directive", table: schema.directive },
    { name: "folder", table: schema.folder },
    { name: "day_entry", table: schema.dayEntry },
    { name: "tag", table: schema.tag },
  ] as const;

  for (const { name, table } of tables) {
    const userIdCol = (table as typeof schema.notePage).userId;
    const updatedAtCol = "updatedAt" in table ? (table as typeof schema.notePage).updatedAt : null;
    if (!updatedAtCol) continue;

    const rows = await db
      .select()
      .from(table)
      .where(and(eq(userIdCol, userId), gt(updatedAtCol, since)));

    for (const row of rows) {
      changes.push({
        entityType: name,
        entityId: (row as Record<string, unknown>).id as string,
        op: "update", // Could be create or update — client merges either way
        data: row,
        updatedAt: ((row as Record<string, unknown>).updatedAt as Date).toISOString(),
      });
    }
  }

  // Pull tombstones (deletes)
  const tombstones = await syncQueries.findTombstonesSince(userId, since);
  for (const t of tombstones) {
    changes.push({
      entityType: t.entityType,
      entityId: t.entityId,
      op: "delete",
      data: null,
      updatedAt: t.updatedAt.toISOString(),
    });
  }

  // Sort by updatedAt
  changes.sort((a, b) => a.updatedAt.localeCompare(b.updatedAt));

  return {
    changes,
    cursor: now.toISOString(),
    hasMore: false, // Simple implementation — no pagination yet
  };
}
