import type { FastifyInstance } from "fastify";
import * as sync from "../features/sync.js";
import * as profileQueries from "../db/queries/profiles.js";
import { syncPushRequest, syncPullQuery } from "../validation/sync.js";
import { ok } from "../lib/responses.js";

export async function syncRoutes(app: FastifyInstance) {
  // Push: POST /v1/sync/push — matches iOS SyncEngine.PushRequest
  app.post("/push", async (req, reply) => {
    await requirePro(req.userId);
    const body = syncPushRequest.parse(req.body);
    return ok(reply, await sync.push(req.userId, body.deviceId, body.ops));
  });

  // Pull: GET /v1/sync/pull?limit=200&cursor=... — matches iOS SyncEngine.pull()
  app.get("/pull", async (req, reply) => {
    await requirePro(req.userId);
    const query = syncPullQuery.parse(req.query);
    const deviceId = (req.headers["x-device-id"] as string) ?? "unknown";
    return ok(reply, await sync.pull(req.userId, deviceId, query.cursor, query.limit));
  });

  // Stats: GET /v1/sync/stats — entity counts for the sync choice screen
  app.get("/stats", async (req, reply) => {
    await requirePro(req.userId);
    return ok(reply, await sync.stats(req.userId));
  });

  // Reset: DELETE /v1/sync/reset — wipe all user data so client can push fresh.
  // Called on free→pro upgrade so local state becomes authoritative.
  app.delete("/reset", async (req, reply) => {
    await requirePro(req.userId);
    return ok(reply, await sync.reset(req.userId));
  });
}

async function requirePro(userId: string) {
  const user = await profileQueries.findById(userId);
  if (!user || user.plan !== "pro") {
    throw { status: 403, error: "pro_required", message: "Cloud sync requires a Pro subscription" };
  }
}
