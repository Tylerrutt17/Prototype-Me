import type { FastifyInstance } from "fastify";
import * as sync from "../features/sync.js";
import { syncPushRequest, syncPullRequest } from "../validation/sync.js";

export async function syncRoutes(app: FastifyInstance) {
  app.post("/push", async (req) => {
    const body = syncPushRequest.parse(req.body);
    return sync.push(req.userId, body.deviceId, body.operations);
  });

  app.post("/pull", async (req) => {
    const body = syncPullRequest.parse(req.body);
    return sync.pull(req.userId, body.deviceId, body.cursor);
  });
}
