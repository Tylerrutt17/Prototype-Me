import { eq, and, gte, lte } from "drizzle-orm";
import { db } from "../client.js";
import { dayEntry } from "../schema.js";

export function findAll(userId: string, filters?: { from?: string; to?: string }) {
  const conditions = [eq(dayEntry.userId, userId)];
  if (filters?.from) conditions.push(gte(dayEntry.date, filters.from));
  if (filters?.to) conditions.push(lte(dayEntry.date, filters.to));
  return db.select().from(dayEntry).where(and(...conditions)).orderBy(dayEntry.date);
}

export function findById(userId: string, id: string) {
  return db.select().from(dayEntry).where(and(eq(dayEntry.id, id), eq(dayEntry.userId, userId))).then((r) => r[0]);
}

export function insert(userId: string, data: Omit<typeof dayEntry.$inferInsert, "userId">) {
  return db.insert(dayEntry).values({ ...data, userId } as typeof dayEntry.$inferInsert).returning().then((r) => r[0]!);
}

export function update(userId: string, id: string, data: Partial<Omit<typeof dayEntry.$inferInsert, "userId">>) {
  return db
    .update(dayEntry)
    .set({ ...data, updatedAt: new Date() })
    .where(and(eq(dayEntry.id, id), eq(dayEntry.userId, userId)))
    .returning()
    .then((r) => r[0]);
}

export function remove(userId: string, id: string) {
  return db.delete(dayEntry).where(and(eq(dayEntry.id, id), eq(dayEntry.userId, userId)));
}
