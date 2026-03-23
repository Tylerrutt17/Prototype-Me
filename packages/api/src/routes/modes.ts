import type { FastifyInstance } from "fastify";
import * as modeQueries from "../db/queries/modes.js";
import { activateMode } from "../validation/modes.js";

export async function modeRoutes(app: FastifyInstance) {
  app.get("/", async (req) => modeQueries.findAll(req.userId));

  app.post("/", async (req, reply) => {
    const body = activateMode.parse(req.body);
    const result = await modeQueries.insert(req.userId, body.noteId);
    return reply.code(201).send(result);
  });

  app.delete("/:noteId", async (req, reply) => {
    const { noteId } = req.params as { noteId: string };
    await modeQueries.remove(req.userId, noteId);
    return reply.code(204).send();
  });
}
