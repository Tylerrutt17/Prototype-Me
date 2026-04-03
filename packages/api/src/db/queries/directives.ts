import { eq, and } from "drizzle-orm";
import { db } from "../client.js";
import { directive, directiveHistory } from "../schema.js";

export function findAll(userId: string, filters?: { status?: string }) {
  const conditions = [eq(directive.userId, userId)];
  if (filters?.status) conditions.push(eq(directive.status, filters.status as "active" | "archived"));
  return db.select().from(directive).where(and(...conditions));
}

export function findById(userId: string, id: string) {
  return db.select().from(directive).where(and(eq(directive.id, id), eq(directive.userId, userId))).then((r) => r[0]);
}

export function insert(userId: string, data: Omit<typeof directive.$inferInsert, "userId">) {
  return db.insert(directive).values({ ...data, userId } as typeof directive.$inferInsert).returning().then((r) => r[0]!);
}

export function update(userId: string, id: string, data: Partial<Omit<typeof directive.$inferInsert, "userId">>) {
  return db
    .update(directive)
    .set({ ...data, updatedAt: new Date() })
    .where(and(eq(directive.id, id), eq(directive.userId, userId)))
    .returning()
    .then((r) => r[0]);
}

export function remove(userId: string, id: string) {
  return db.delete(directive).where(and(eq(directive.id, id), eq(directive.userId, userId)));
}

export function findHistory(directiveId: string) {
  return db
    .select()
    .from(directiveHistory)
    .where(eq(directiveHistory.directiveId, directiveId))
    .orderBy(directiveHistory.createdAt);
}

export function insertHistory(directiveId: string, action: string, payload = "{}") {
  return db.insert(directiveHistory).values({ directiveId, action: action as "create" | "update" | "graduate" | "snooze" | "balloon_pump" | "shrink" | "split" | "checklist_complete", payload }).returning().then((r) => r[0]!);
}
