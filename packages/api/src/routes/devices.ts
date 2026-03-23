import type { FastifyInstance } from "fastify";
import * as deviceQueries from "../db/queries/devices.js";
import { createDevice } from "../validation/devices.js";

export async function deviceRoutes(app: FastifyInstance) {
  app.get("/", async (req) => deviceQueries.findAll(req.userId));

  app.post("/", async (req, reply) => {
    const body = createDevice.parse(req.body);
    const result = await deviceQueries.insert(req.userId, body);
    return reply.code(201).send(result);
  });
}
