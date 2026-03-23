import type { FastifyInstance } from "fastify";
import * as notes from "../features/notes.js";
import { createNote, updateNote } from "../validation/notes.js";

export async function noteRoutes(app: FastifyInstance) {
  app.get("/", async (req) => {
    const { kind, folderId } = req.query as Record<string, string>;
    return notes.listNotes(req.userId, { kind, folderId });
  });

  app.get("/:id", async (req) => {
    const { id } = req.params as { id: string };
    return notes.getNote(req.userId, id);
  });

  app.post("/", async (req, reply) => {
    const body = createNote.parse(req.body);
    const result = await notes.createNote(req.userId, body);
    return reply.code(201).send(result);
  });

  app.patch("/:id", async (req) => {
    const { id } = req.params as { id: string };
    const body = updateNote.parse(req.body);
    return notes.updateNote(req.userId, id, body);
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await notes.deleteNote(req.userId, id);
    return reply.code(204).send();
  });
}
