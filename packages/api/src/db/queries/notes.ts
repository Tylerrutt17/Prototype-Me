import { eq, and } from "drizzle-orm";
import { db } from "../client.js";
import { notePage } from "../schema.js";

export function findAll(userId: string, filters?: { kind?: string; folderId?: string }) {
  const conditions = [eq(notePage.userId, userId)];
  if (filters?.kind) conditions.push(eq(notePage.kind, filters.kind as "regular" | "mode" | "framework" | "situation" | "goal"));
  if (filters?.folderId) conditions.push(eq(notePage.folderId, filters.folderId));
  return db.select().from(notePage).where(and(...conditions)).orderBy(notePage.sortIndex);
}

export function findById(userId: string, id: string) {
  return db.select().from(notePage).where(and(eq(notePage.id, id), eq(notePage.userId, userId))).then((r) => r[0]);
}

export function insert(userId: string, data: Omit<typeof notePage.$inferInsert, "userId">) {
  return db.insert(notePage).values({ ...data, userId } as typeof notePage.$inferInsert).returning().then((r) => r[0]!);
}

export function update(userId: string, id: string, data: Partial<Omit<typeof notePage.$inferInsert, "userId">>) {
  return db
    .update(notePage)
    .set({ ...data, updatedAt: new Date() })
    .where(and(eq(notePage.id, id), eq(notePage.userId, userId)))
    .returning()
    .then((r) => r[0]);
}

export function remove(userId: string, id: string) {
  return db.delete(notePage).where(and(eq(notePage.id, id), eq(notePage.userId, userId)));
}
