import { eq } from "drizzle-orm";
import { db } from "../client.js";
import { device } from "../schema.js";

export function findAll(userId: string) {
  return db.select().from(device).where(eq(device.userId, userId));
}

export function insert(userId: string, data: Omit<typeof device.$inferInsert, "userId">) {
  return db.insert(device).values({ ...data, userId } as typeof device.$inferInsert).returning().then((r) => r[0]!);
}
