import type { FastifyInstance } from "fastify";
import * as friends from "../features/friends.js";
import { sendFriendRequest } from "../validation/friends.js";

export async function friendRoutes(app: FastifyInstance) {
  app.get("/", async (req) => friends.listFriends(req.userId));

  app.post("/request", async (req, reply) => {
    const body = sendFriendRequest.parse(req.body);
    const result = await friends.sendRequest(req.userId, body.userId);
    return reply.code(201).send(result);
  });

  app.post("/:id/accept", async (req) => {
    const { id } = req.params as { id: string };
    return friends.acceptRequest(req.userId, id);
  });

  app.post("/:id/decline", async (req, reply) => {
    const { id } = req.params as { id: string };
    await friends.declineRequest(req.userId, id);
    return reply.code(204).send();
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await friends.removeFriend(req.userId, id);
    return reply.code(204).send();
  });
}
