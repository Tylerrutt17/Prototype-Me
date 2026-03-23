import type { FastifyInstance } from "fastify";
import * as folderQueries from "../db/queries/folders.js";
import { createFolder, updateFolder } from "../validation/folders.js";

export async function folderRoutes(app: FastifyInstance) {
  app.get("/", async (req) => folderQueries.findAll(req.userId));

  app.get("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const folder = await folderQueries.findById(req.userId, id);
    if (!folder) return reply.code(404).send({ error: "not_found", message: "Folder not found" });
    return folder;
  });

  app.post("/", async (req, reply) => {
    const body = createFolder.parse(req.body);
    const result = await folderQueries.insert(req.userId, body);
    return reply.code(201).send(result);
  });

  app.patch("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = updateFolder.parse(req.body);
    const result = await folderQueries.update(req.userId, id, body);
    if (!result) return reply.code(404).send({ error: "not_found", message: "Folder not found" });
    return result;
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await folderQueries.remove(req.userId, id);
    return reply.code(204).send();
  });
}
