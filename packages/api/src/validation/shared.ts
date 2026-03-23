import { z } from "zod/v4";

// ── Shared primitives ───────────────────────
export const uuid = z.uuid();
export const isoDate = z.iso.date(); // yyyy-MM-dd
export const isoDatetime = z.iso.datetime(); // ISO 8601

// ── Enums ───────────────────────────────────
export const noteKind = z.enum(["regular", "mode", "framework", "situation"]);
export const directiveStatus = z.enum(["active", "maintained", "retired"]);
export const scheduleType = z.enum(["weekly", "monthly", "oneOff"]);
export const instanceStatus = z.enum(["pending", "done", "skipped"]);
export const directiveHistoryAction = z.enum(["create", "update", "graduate", "snooze", "balloon_pump", "shrink", "split"]);
export const subscriptionPlan = z.enum(["free", "pro"]);
export const friendRequestStatus = z.enum(["pending", "accepted", "declined"]);
export const chipAction = z.enum(["createDirective", "updateDirective", "createNote", "activateMode", "addSchedule"]);
export const chipStatus = z.enum(["suggested", "accepted", "dismissed"]);
export const syncOp = z.enum(["create", "update", "delete"]);
