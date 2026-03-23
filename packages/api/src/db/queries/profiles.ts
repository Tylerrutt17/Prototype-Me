import { eq } from "drizzle-orm";
import { db } from "../client.js";
import { users } from "../schema.js";

export function findById(id: string) {
  return db.select().from(users).where(eq(users.id, id)).then((r) => r[0]);
}

export function upsert(id: string, data: Partial<typeof users.$inferInsert>) {
  return db
    .insert(users)
    .values({ id, email: data.email ?? "", displayName: data.displayName ?? "", ...data })
    .onConflictDoUpdate({ target: users.id, set: data })
    .returning()
    .then((r) => r[0]!);
}

export function update(id: string, data: Partial<typeof users.$inferInsert>) {
  return db.update(users).set(data).where(eq(users.id, id)).returning().then((r) => r[0]);
}
