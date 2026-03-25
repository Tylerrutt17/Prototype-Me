import type { FastifyInstance } from "fastify";
import * as folderQueries from "../db/queries/folders.js";
import { createFolder, updateFolder } from "../validation/folders.js";
import { ok, created, noContent, notFound } from "../lib/responses.js";

export async function folderRoutes(app: FastifyInstance) {
  app.get("/", async (req, reply) => {
    return ok(reply, await folderQueries.findAll(req.userId));
  });

  app.get("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const folder = await folderQueries.findById(req.userId, id);
    if (!folder) return notFound(reply, "Folder");
    return ok(reply, folder);
  });

  app.post("/", async (req, reply) => {
    const body = createFolder.parse(req.body);
    const result = await folderQueries.insert(req.userId, body);
    return created(reply, result);
  });

  app.patch("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = updateFolder.parse(req.body);
    const result = await folderQueries.update(req.userId, id, body);
    if (!result) return notFound(reply, "Folder");
    return ok(reply, result);
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await folderQueries.remove(req.userId, id);
    return noContent(reply);
  });
}
