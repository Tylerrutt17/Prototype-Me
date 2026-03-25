import { z } from "zod/v4";
import { syncOp } from "./shared.js";

export const outboxOp = z.object({
  id: z.string().min(1),
  entityType: z.string().min(1),
  entityId: z.string().min(1), // UUID string or composite "noteId|directiveId"
  op: syncOp,
  patch: z.string(),
  baseUpdatedAt: z.string().datetime().nullable().optional(),
  schemaVersion: z.int(),
  createdAt: z.string().datetime(),
});

// Push: matches iOS SyncEngine.PushRequest
export const syncPushRequest = z.object({
  deviceId: z.string().min(1),
  lastSyncToken: z.string().nullable().optional(),
  ops: z.array(outboxOp),
});

// Pull: query params from GET request
export const syncPullQuery = z.object({
  limit: z.coerce.number().int().min(1).max(500).optional().default(200),
  cursor: z.string().optional(),
});

export type SyncPushInput = z.infer<typeof syncPushRequest>;
export type SyncPullQuery = z.infer<typeof syncPullQuery>;
