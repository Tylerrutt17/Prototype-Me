import { eq, and, or, sql } from "drizzle-orm";
import { db } from "../client.js";
import { friendship, users } from "../schema.js";

export function findAll(userId: string) {
  return db
    .select({
      id: friendship.id,
      requesterId: friendship.requesterId,
      addresseeId: friendship.addresseeId,
      status: friendship.status,
      createdAt: friendship.createdAt,
      displayName: users.displayName,
      avatarSystemImage: users.avatarSystemImage,
    })
    .from(friendship)
    .innerJoin(
      users,
      sql`CASE WHEN ${friendship.requesterId} = ${userId} THEN ${friendship.addresseeId} ELSE ${friendship.requesterId} END = ${users.id}`,
    )
    .where(or(eq(friendship.requesterId, userId), eq(friendship.addresseeId, userId)));
}

export function findById(id: string) {
  return db.select().from(friendship).where(eq(friendship.id, id)).then((r) => r[0]);
}

export function insertRequest(requesterId: string, addresseeId: string) {
  return db.insert(friendship).values({ requesterId, addresseeId }).returning().then((r) => r[0]!);
}

export function updateStatus(id: string, status: string) {
  return db.update(friendship).set({ status: status as "pending" | "accepted" | "declined" }).where(eq(friendship.id, id)).returning().then((r) => r[0]);
}

export function remove(id: string) {
  return db.delete(friendship).where(eq(friendship.id, id));
}
