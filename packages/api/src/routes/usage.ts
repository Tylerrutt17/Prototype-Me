import type { FastifyInstance } from "fastify";
import * as ai from "../features/ai.js";

export async function usageRoutes(app: FastifyInstance) {
  app.get("/", async (req) => ai.getQuota(req.userId));
}
