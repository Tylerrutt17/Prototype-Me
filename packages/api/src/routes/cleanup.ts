import type { FastifyInstance } from "fastify";
import * as cleanup from "../features/cleanup.js";
import { ok } from "../lib/responses.js";

export async function cleanupRoutes(app: FastifyInstance) {
  // POST /v1/cleanup/purge — run the cleanup job
  // In production, call this from a cron (e.g., Railway cron, or external scheduler)
  app.post("/purge", async (_req, reply) => {
    return ok(reply, await cleanup.purgeExpired());
  });
}
