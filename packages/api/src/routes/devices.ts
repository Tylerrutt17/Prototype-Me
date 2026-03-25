import type { FastifyInstance } from "fastify";
import * as deviceQueries from "../db/queries/devices.js";
import { createDevice } from "../validation/devices.js";
import { ok, created } from "../lib/responses.js";

export async function deviceRoutes(app: FastifyInstance) {
  app.get("/", async (req, reply) => {
    return ok(reply, await deviceQueries.findAll(req.userId));
  });

  app.post("/", async (req, reply) => {
    const body = createDevice.parse(req.body);
    const result = await deviceQueries.insert(req.userId, body);
    return created(reply, result);
  });
}
