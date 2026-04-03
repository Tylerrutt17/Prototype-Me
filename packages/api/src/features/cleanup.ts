import { lt, sql } from "drizzle-orm";
import { db } from "../db/client.js";
import { syncOpLog, tombstone } from "../db/schema.js";

const SYNC_OP_LOG_TTL_DAYS = 30;
const TOMBSTONE_TTL_DAYS = 90;

/**
 * Purge expired sync op logs and tombstones.
 * Safe to run frequently — idempotent, no side effects.
 */
export async function purgeExpired() {
  const opLogCutoff = new Date();
  opLogCutoff.setDate(opLogCutoff.getDate() - SYNC_OP_LOG_TTL_DAYS);

  const tombstoneCutoff = new Date();
  tombstoneCutoff.setDate(tombstoneCutoff.getDate() - TOMBSTONE_TTL_DAYS);

  const deletedOps = await db
    .delete(syncOpLog)
    .where(lt(syncOpLog.processedAt, opLogCutoff))
    .returning({ id: syncOpLog.opId });

  const deletedTombstones = await db
    .delete(tombstone)
    .where(lt(tombstone.updatedAt, tombstoneCutoff))
    .returning({ id: tombstone.id });

  return {
    syncOpLogsDeleted: deletedOps.length,
    tombstonesDeleted: deletedTombstones.length,
    syncOpLogTtlDays: SYNC_OP_LOG_TTL_DAYS,
    tombstoneTtlDays: TOMBSTONE_TTL_DAYS,
  };
}
