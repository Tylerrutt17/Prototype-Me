import type { FastifyInstance } from "fastify";
import * as dayEntryQueries from "../db/queries/dayEntries.js";
import { createDayEntry, updateDayEntry } from "../validation/dayEntries.js";
import { ok, created, noContent, notFound } from "../lib/responses.js";

export async function dayEntryRoutes(app: FastifyInstance) {
  app.get("/", async (req, reply) => {
    const { from, to } = req.query as Record<string, string>;
    return ok(reply, await dayEntryQueries.findAll(req.userId, { from, to }));
  });

  app.get("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const entry = await dayEntryQueries.findById(req.userId, id);
    if (!entry) return notFound(reply, "Day entry");
    return ok(reply, entry);
  });

  app.post("/", async (req, reply) => {
    const body = createDayEntry.parse(req.body);
    const result = await dayEntryQueries.insert(req.userId, body);
    return created(reply, result);
  });

  app.patch("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = updateDayEntry.parse(req.body);
    const result = await dayEntryQueries.update(req.userId, id, body);
    if (!result) return notFound(reply, "Day entry");
    return ok(reply, result);
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await dayEntryQueries.remove(req.userId, id);
    return noContent(reply);
  });
}
