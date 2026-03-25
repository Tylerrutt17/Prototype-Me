import type { FastifyInstance } from "fastify";
import * as ai from "../features/ai.js";
import { ok } from "../lib/responses.js";

export async function usageRoutes(app: FastifyInstance) {
  app.get("/", async (req, reply) => {
    return ok(reply, await ai.getQuota(req.userId));
  });
}
