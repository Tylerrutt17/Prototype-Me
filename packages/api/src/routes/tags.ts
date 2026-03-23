import type { FastifyInstance } from "fastify";
import * as tagQueries from "../db/queries/tags.js";
import { createTag } from "../validation/tags.js";

export async function tagRoutes(app: FastifyInstance) {
  app.get("/", async (req) => tagQueries.findAll(req.userId));

  app.post("/", async (req, reply) => {
    const body = createTag.parse(req.body);
    const result = await tagQueries.insert(req.userId, body);
    return reply.code(201).send(result);
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await tagQueries.remove(req.userId, id);
    return reply.code(204).send();
  });
}
