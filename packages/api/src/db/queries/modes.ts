import { eq, and } from "drizzle-orm";
import { db } from "../client.js";
import { activeMode } from "../schema.js";

export function findAll(userId: string) {
  return db.select().from(activeMode).where(eq(activeMode.userId, userId));
}

export function insert(userId: string, noteId: string) {
  return db.insert(activeMode).values({ noteId, userId, activatedAt: new Date() }).returning().then((r) => r[0]!);
}

export function remove(userId: string, noteId: string) {
  return db.delete(activeMode).where(and(eq(activeMode.noteId, noteId), eq(activeMode.userId, userId)));
}
