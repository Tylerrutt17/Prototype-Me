import { eq, and } from "drizzle-orm";
import { db } from "../client.js";
import { tag } from "../schema.js";

export function findAll(userId: string) {
  return db.select().from(tag).where(eq(tag.userId, userId));
}

export function insert(userId: string, data: Omit<typeof tag.$inferInsert, "userId">) {
  return db.insert(tag).values({ ...data, userId } as typeof tag.$inferInsert).returning().then((r) => r[0]!);
}

export function remove(userId: string, id: string) {
  return db.delete(tag).where(and(eq(tag.id, id), eq(tag.userId, userId)));
}
