import * as directiveQueries from "../db/queries/directives.js";

export async function listDirectives(userId: string, filters?: { status?: string }) {
  return directiveQueries.findAll(userId, filters);
}

export async function getDirective(userId: string, id: string) {
  const dir = await directiveQueries.findById(userId, id);
  if (!dir) throw { status: 404, error: "not_found", message: "Directive not found" };
  return dir;
}

export async function createDirective(userId: string, data: {
  id?: string; title: string; body?: string | null; status: string;
  balloonEnabled?: boolean; balloonDurationSec?: number; snoozedUntil?: string | null;
}) {
  const result = await directiveQueries.insert(userId, {
    ...data,
    status: data.status as "active" | "archived",
    balloonSnapshotSec: data.balloonDurationSec ?? 0,
    snoozedUntil: data.snoozedUntil ? new Date(data.snoozedUntil) : null,
  });
  await directiveQueries.insertHistory(result.id, "create");
  return result;
}

export async function updateDirective(userId: string, id: string, data: {
  title?: string; body?: string | null; status?: string; balloonEnabled?: boolean;
  balloonDurationSec?: number; balloonSnapshotSec?: number; snoozedUntil?: string | null; version: number;
}) {
  const existing = await directiveQueries.findById(userId, id);
  if (!existing) throw { status: 404, error: "not_found", message: "Directive not found" };
  if (existing.version !== data.version) throw { status: 409, error: "version_conflict", message: "Version mismatch" };

  const { version: _, snoozedUntil, ...rest } = data;
  const updates: Record<string, unknown> = { ...rest, version: existing.version + 1 };
  if (snoozedUntil !== undefined) {
    updates.snoozedUntil = snoozedUntil ? new Date(snoozedUntil) : null;
  }

  const result = await directiveQueries.update(userId, id, updates);
  await directiveQueries.insertHistory(id, "update", JSON.stringify(rest));
  return result;
}

export async function deleteDirective(userId: string, id: string) {
  const existing = await directiveQueries.findById(userId, id);
  if (!existing) throw { status: 404, error: "not_found", message: "Directive not found" };
  await directiveQueries.remove(userId, id);
}

export async function pumpDirective(userId: string, id: string) {
  const existing = await directiveQueries.findById(userId, id);
  if (!existing) throw { status: 404, error: "not_found", message: "Directive not found" };

  const result = await directiveQueries.update(userId, id, {
    balloonSnapshotSec: existing.balloonDurationSec,
    version: existing.version + 1,
  });
  await directiveQueries.insertHistory(id, "balloon_pump");
  return result;
}

export async function getHistory(userId: string, id: string) {
  // Verify ownership
  const existing = await directiveQueries.findById(userId, id);
  if (!existing) throw { status: 404, error: "not_found", message: "Directive not found" };
  return directiveQueries.findHistory(id);
}
