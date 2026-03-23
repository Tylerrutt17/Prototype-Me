import { eq, and, sql } from "drizzle-orm";
import { db } from "../client.js";
import { aiUsage } from "../schema.js";

export function getToday(userId: string) {
  const today = new Date().toISOString().slice(0, 10);
  return db
    .select()
    .from(aiUsage)
    .where(and(eq(aiUsage.userId, userId), eq(aiUsage.date, today)))
    .then((r) => r[0]);
}

export function increment(userId: string) {
  const today = new Date().toISOString().slice(0, 10);
  return db
    .insert(aiUsage)
    .values({ userId, date: today, count: 1 })
    .onConflictDoUpdate({
      target: [aiUsage.userId, aiUsage.date],
      set: { count: sql`${aiUsage.count} + 1` },
    })
    .returning()
    .then((r) => r[0]!);
}
