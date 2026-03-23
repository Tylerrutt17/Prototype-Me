import { z } from "zod/v4";
import { uuid, syncOp } from "./shared.js";

export const outboxOp = z.object({
  id: uuid,
  entityType: z.string(),
  entityId: uuid,
  op: syncOp,
  patch: z.string(),
  baseUpdatedAt: z.string().datetime().nullable().optional(),
  schemaVersion: z.int(),
  createdAt: z.string().datetime(),
});

export const syncPushRequest = z.object({
  deviceId: z.string().min(1),
  operations: z.array(outboxOp),
});

export const syncPullRequest = z.object({
  deviceId: z.string().min(1),
  cursor: z.string().nullable().optional(),
});

export type SyncPushInput = z.infer<typeof syncPushRequest>;
export type SyncPullInput = z.infer<typeof syncPullRequest>;
