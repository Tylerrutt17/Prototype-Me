import * as friendQueries from "../db/queries/friends.js";

export async function listFriends(userId: string) {
  const rows = await friendQueries.findAll(userId);
  return rows.map((r) => ({
    id: r.id,
    displayName: r.displayName,
    avatarSystemImage: r.avatarSystemImage,
    status: r.status,
    since: r.status === "accepted" ? r.createdAt : null,
  }));
}

export async function sendRequest(requesterId: string, addresseeId: string) {
  if (requesterId === addresseeId) throw { status: 400, error: "bad_request", message: "Cannot friend yourself" };
  return friendQueries.insertRequest(requesterId, addresseeId);
}

export async function acceptRequest(userId: string, friendshipId: string) {
  const f = await friendQueries.findById(friendshipId);
  if (!f) throw { status: 404, error: "not_found", message: "Request not found" };
  if (f.addresseeId !== userId) throw { status: 403, error: "forbidden", message: "Only the recipient can accept" };
  if (f.status !== "pending") throw { status: 400, error: "bad_request", message: "Request is not pending" };
  return friendQueries.updateStatus(friendshipId, "accepted");
}

export async function declineRequest(userId: string, friendshipId: string) {
  const f = await friendQueries.findById(friendshipId);
  if (!f) throw { status: 404, error: "not_found", message: "Request not found" };
  if (f.addresseeId !== userId) throw { status: 403, error: "forbidden", message: "Only the recipient can decline" };
  await friendQueries.updateStatus(friendshipId, "declined");
}

export async function removeFriend(userId: string, friendshipId: string) {
  const f = await friendQueries.findById(friendshipId);
  if (!f) throw { status: 404, error: "not_found", message: "Friendship not found" };
  if (f.requesterId !== userId && f.addresseeId !== userId) throw { status: 403, error: "forbidden", message: "Not your friendship" };
  await friendQueries.remove(friendshipId);
}
