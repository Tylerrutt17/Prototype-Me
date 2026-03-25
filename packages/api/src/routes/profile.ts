import type { FastifyInstance } from "fastify";
import * as profileQueries from "../db/queries/profiles.js";
import { updateProfile } from "../validation/profile.js";
import { ok, notFound } from "../lib/responses.js";

export async function profileRoutes(app: FastifyInstance) {
  app.get("/profile", async (req, reply) => {
    const user = await profileQueries.findById(req.userId);
    if (!user) return notFound(reply, "Profile");
    return ok(reply, toPublicProfile(user));
  });

  app.patch("/profile", async (req, reply) => {
    const body = updateProfile.parse(req.body);
    const result = await profileQueries.update(req.userId, body);
    if (!result) return notFound(reply, "Profile");
    return ok(reply, toPublicProfile(result));
  });

  app.get("/users/:id/profile", async (req, reply) => {
    const { id } = req.params as { id: string };
    const user = await profileQueries.findById(id);
    if (!user) return notFound(reply, "User");
    return ok(reply, toPublicProfile(user));
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
