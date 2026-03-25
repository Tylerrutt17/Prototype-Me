import type { FastifyInstance } from "fastify";
import * as notes from "../features/notes.js";
import { createNote, updateNote } from "../validation/notes.js";
import { ok, created, noContent } from "../lib/responses.js";

export async function noteRoutes(app: FastifyInstance) {
  app.get("/", async (req, reply) => {
    const { kind, folderId } = req.query as Record<string, string>;
    return ok(reply, await notes.listNotes(req.userId, { kind, folderId }));
  });

  app.get("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    return ok(reply, await notes.getNote(req.userId, id));
  });

  app.post("/", async (req, reply) => {
    const body = createNote.parse(req.body);
    const result = await notes.createNote(req.userId, body);
    return created(reply, result);
  });

  app.patch("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = updateNote.parse(req.body);
    return ok(reply, await notes.updateNote(req.userId, id, body));
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await notes.deleteNote(req.userId, id);
    return noContent(reply);
  });
}
