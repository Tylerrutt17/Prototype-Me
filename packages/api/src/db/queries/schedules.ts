import { eq, and } from "drizzle-orm";
import { db } from "../client.js";
import { scheduleRule, scheduleInstance } from "../schema.js";

// ── Rules ───────────────────────────────────
export function findAllRules(userId: string, directiveId?: string) {
  const conditions = [eq(scheduleRule.userId, userId)];
  if (directiveId) conditions.push(eq(scheduleRule.directiveId, directiveId));
  return db.select().from(scheduleRule).where(and(...conditions));
}

export function insertRule(userId: string, data: Omit<typeof scheduleRule.$inferInsert, "userId">) {
  return db.insert(scheduleRule).values({ ...data, userId } as typeof scheduleRule.$inferInsert).returning().then((r) => r[0]!);
}

export function removeRule(userId: string, id: string) {
  return db.delete(scheduleRule).where(and(eq(scheduleRule.id, id), eq(scheduleRule.userId, userId)));
}

// ── Instances ───────────────────────────────
export function findInstancesByDate(userId: string, date: string) {
  return db.select().from(scheduleInstance).where(and(eq(scheduleInstance.userId, userId), eq(scheduleInstance.date, date)));
}

export function updateInstance(userId: string, id: string, status: string) {
  return db
    .update(scheduleInstance)
    .set({ status })
    .where(and(eq(scheduleInstance.id, id), eq(scheduleInstance.userId, userId)))
    .returning()
    .then((r) => r[0]);
}
