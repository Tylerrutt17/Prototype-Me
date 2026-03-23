import type { FastifyInstance } from "fastify";
import * as dayEntryQueries from "../db/queries/dayEntries.js";
import { createDayEntry, updateDayEntry } from "../validation/dayEntries.js";

export async function dayEntryRoutes(app: FastifyInstance) {
  app.get("/", async (req) => {
    const { from, to } = req.query as Record<string, string>;
    return dayEntryQueries.findAll(req.userId, { from, to });
  });

  app.get("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const entry = await dayEntryQueries.findById(req.userId, id);
    if (!entry) return reply.code(404).send({ error: "not_found", message: "Day entry not found" });
    return entry;
  });

  app.post("/", async (req, reply) => {
    const body = createDayEntry.parse(req.body);
    const result = await dayEntryQueries.insert(req.userId, body);
    return reply.code(201).send(result);
  });

  app.patch("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = updateDayEntry.parse(req.body);
    const result = await dayEntryQueries.update(req.userId, id, body);
    if (!result) return reply.code(404).send({ error: "not_found", message: "Day entry not found" });
    return result;
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await dayEntryQueries.remove(req.userId, id);
    return reply.code(204).send();
  });
}
