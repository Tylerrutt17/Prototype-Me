import type { FastifyInstance } from "fastify";
import * as sync from "../features/sync.js";
import { syncPushRequest, syncPullQuery } from "../validation/sync.js";
import { ok } from "../lib/responses.js";

export async function syncRoutes(app: FastifyInstance) {
  // Push: POST /v1/sync/push — matches iOS SyncEngine.PushRequest
  app.post("/push", async (req, reply) => {
    const body = syncPushRequest.parse(req.body);
    return ok(reply, await sync.push(req.userId, body.deviceId, body.ops));
  });

  // Pull: GET /v1/sync/pull?limit=200&cursor=... — matches iOS SyncEngine.pull()
  app.get("/pull", async (req, reply) => {
    const query = syncPullQuery.parse(req.query);
    const deviceId = (req.headers["x-device-id"] as string) ?? "unknown";
    return ok(reply, await sync.pull(req.userId, deviceId, query.cursor, query.limit));
  });
}
