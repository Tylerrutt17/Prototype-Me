import type { FastifyInstance } from "fastify";
import * as tagQueries from "../db/queries/tags.js";
import { createTag } from "../validation/tags.js";
import { ok, created, noContent } from "../lib/responses.js";

export async function tagRoutes(app: FastifyInstance) {
  app.get("/", async (req, reply) => {
    return ok(reply, await tagQueries.findAll(req.userId));
  });

  app.post("/", async (req, reply) => {
    const body = createTag.parse(req.body);
    const result = await tagQueries.insert(req.userId, body);
    return created(reply, result);
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await tagQueries.remove(req.userId, id);
    return noContent(reply);
  });
}
