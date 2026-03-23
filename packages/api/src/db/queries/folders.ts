import { eq, and } from "drizzle-orm";
import { db } from "../client.js";
import { folder } from "../schema.js";

export function findAll(userId: string) {
  return db.select().from(folder).where(eq(folder.userId, userId));
}

export function findById(userId: string, id: string) {
  return db.select().from(folder).where(and(eq(folder.id, id), eq(folder.userId, userId))).then((r) => r[0]);
}

export function insert(userId: string, data: Omit<typeof folder.$inferInsert, "userId">) {
  return db.insert(folder).values({ ...data, userId } as typeof folder.$inferInsert).returning().then((r) => r[0]!);
}

export function update(userId: string, id: string, data: Partial<Omit<typeof folder.$inferInsert, "userId">>) {
  return db
    .update(folder)
    .set({ ...data, updatedAt: new Date() })
    .where(and(eq(folder.id, id), eq(folder.userId, userId)))
    .returning()
    .then((r) => r[0]);
}

export function remove(userId: string, id: string) {
  return db.delete(folder).where(and(eq(folder.id, id), eq(folder.userId, userId)));
}
