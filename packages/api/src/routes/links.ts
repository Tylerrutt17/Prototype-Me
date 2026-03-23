import type { FastifyInstance } from "fastify";
import * as linkQueries from "../db/queries/links.js";
import { noteDirectiveLink } from "../validation/links.js";

export async function linkRoutes(app: FastifyInstance) {
  app.post("/note-directives", async (req, reply) => {
    const body = noteDirectiveLink.parse(req.body);
    await linkQueries.linkNoteDirective(body.noteId, body.directiveId, body.sortIndex);
    return reply.code(201).send();
  });

  app.delete("/note-directives", async (req, reply) => {
    const { noteId, directiveId } = req.query as { noteId: string; directiveId: string };
    await linkQueries.unlinkNoteDirective(noteId, directiveId);
    return reply.code(204).send();
  });
}
