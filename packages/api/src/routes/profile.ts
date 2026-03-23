import type { FastifyInstance } from "fastify";
import * as profileQueries from "../db/queries/profiles.js";
import { updateProfile } from "../validation/profile.js";

export async function profileRoutes(app: FastifyInstance) {
  app.get("/profile", async (req, reply) => {
    const user = await profileQueries.findById(req.userId);
    if (!user) return reply.code(404).send({ error: "not_found", message: "Profile not found" });
    return toPublicProfile(user);
  });

  app.patch("/profile", async (req, reply) => {
    const body = updateProfile.parse(req.body);
    const result = await profileQueries.update(req.userId, body);
    if (!result) return reply.code(404).send({ error: "not_found", message: "Profile not found" });
    return toPublicProfile(result);
  });

  app.get("/users/:id/profile", async (req, reply) => {
    const { id } = req.params as { id: string };
    const user = await profileQueries.findById(id);
    if (!user) return reply.code(404).send({ error: "not_found", message: "User not found" });
    return toPublicProfile(user);
  });
}

function toPublicProfile(user: Record<string, unknown>) {
  return {
    id: user.id,
    displayName: user.displayName,
    bio: user.bio ?? null,
    avatarSystemImage: user.avatarSystemImage,
    moodChips: user.moodChips ?? [],
    joinedAt: user.createdAt,
    plan: user.plan,
  };
}
